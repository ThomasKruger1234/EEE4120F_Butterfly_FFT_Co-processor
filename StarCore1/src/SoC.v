// =========================================================================
// EEE4120F YODA Project: StarCore1 + FFT_Coprocessor SoC
// =========================================================================
//
// File        : SoC.v
// Description : Top-level wrapper that integrates the StarCore1 single-cycle
//               CPU with the FFT_Coprocessor through a shared memory-mapped
//               area (rf[]) and a new custom opcode (4'b1010 = FFT_RUN).
//
//               When the CPU executes FFT_RUN, this wrapper:
//                 1. Stalls the CPU's PC.
//                 2. Spends 256 cycles doing an in-place bit-reversal swap of
//                    rf[]: for each i in 0..255, if bitrev8(i) > i, swap
//                    rf[i] <-> rf[bitrev8(i)] via ButterflyMemory's external
//                    swap port.
//                 3. Releases fft_rst so the FFT controller runs for ~1024
//                    cycles.
//                 4. When done_latch asserts, unstalls the CPU.
//
//               MMIO map (decoded on mem_access_addr[15:14]):
//                 00       -> DataMemory (inside Datapath, unchanged)
//                 10       -> rf[] read window (0x8000-0x83FE).
//                             addr[10:3]=sample, addr[2:1]=lane
//                             (00=R_hi,01=R_lo,10=I_hi,11=I_lo)
//                 11       -> STATUS register (0xC000), returns {15'd0, done}
//
//               The SoC has no top-level reset; PC=0, done_latch=0, and the
//               FSM state come from `initial` blocks in the respective
//               modules.
// =========================================================================

`timescale 1ns / 1ps

// Module sources are listed on the iverilog command line (see Makefile target
// `soc`). No `include directives here to keep dependencies declarative.

module SoC (
    input wire clk
);

    // -------------------------------------------------------------------------
    // Inter-module wires
    // -------------------------------------------------------------------------
    wire [15:0] cpu_mem_addr;
    wire        cpu_mem_read;
    wire        cpu_fft_run;
    wire        stall;
    wire [15:0] mmio_read_data;
    wire        mmio_read_sel;

    wire        fft_done;
    wire        fft_rst;

    wire        ext_active;
    wire [7:0]  ext_addr_a;
    wire [7:0]  ext_addr_b;
    wire        ext_we;
    wire [7:0]  ext_raddr;
    wire [63:0] ext_rdout;

    // -------------------------------------------------------------------------
    // 4-state FSM: IDLE -> SWAP (256 cyc) -> RUN (~1024 cyc) -> DONE
    //   Triggered by cpu_fft_run going high (CPU on FFT_RUN opcode).
    // -------------------------------------------------------------------------
    localparam [1:0] S_IDLE = 2'd0,
                     S_SWAP = 2'd1,
                     S_RUN  = 2'd2,
                     S_DONE = 2'd3;

    reg [1:0] state;
    reg [7:0] swap_idx;

    initial begin
        state    = S_IDLE;
        swap_idx = 8'd0;
    end

    always @(posedge clk) begin
        case (state)
            S_IDLE: if (cpu_fft_run) begin
                state    <= S_SWAP;
                swap_idx <= 8'd0;
            end
            S_SWAP: begin
                swap_idx <= swap_idx + 8'd1;
                if (swap_idx == 8'd255) state <= S_RUN;
            end
            S_RUN:  if (fft_done) state <= S_DONE;
            S_DONE: if (!cpu_fft_run) state <= S_IDLE;
            default: state <= S_IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    // 8-bit bit-reversal (combinational function)
    // -------------------------------------------------------------------------
    function [7:0] bitrev8;
        input [7:0] x;
        begin
            bitrev8 = {x[0], x[1], x[2], x[3],
                       x[4], x[5], x[6], x[7]};
        end
    endfunction

    // -------------------------------------------------------------------------
    // FSM-driven signals
    // -------------------------------------------------------------------------
    wire [7:0] swap_bitrev = bitrev8(swap_idx);

    assign ext_active = (state == S_SWAP);
    assign ext_addr_a = swap_idx;
    assign ext_addr_b = swap_bitrev;
    // Only swap each pair once: assert ext_we only when bitrev(i) > i.
    // Fixed points (bitrev(i) == i) are no-ops.
    assign ext_we     = ext_active & (swap_bitrev > swap_idx);

    // Hold FFT in reset whenever we're NOT in the compute phase.
    assign fft_rst = (state != S_RUN);

    // Stall the CPU's PC for the entire opcode (SWAP + RUN + handshake).
    assign stall = cpu_fft_run & ~fft_done;

    // -------------------------------------------------------------------------
    // MMIO address decode
    //   addr[15:14] = 10 -> rf[] read window
    //   addr[15:14] = 11 -> STATUS
    //   addr[15]    = 0  -> DataMemory (handled inside Datapath)
    // -------------------------------------------------------------------------
    assign mmio_read_sel = cpu_mem_addr[15];

    // rf[] read window: addr[10:3] = sample index, addr[2:1] = lane.
    wire        rf_window_sel = (cpu_mem_addr[15:14] == 2'b10);
    wire        status_sel    = (cpu_mem_addr[15:14] == 2'b11);

    assign ext_raddr = cpu_mem_addr[10:3];

    wire [1:0]  lane = cpu_mem_addr[2:1];
    reg  [15:0] rf_window_data;
    always @(*) begin
        case (lane)
            2'b00:   rf_window_data = ext_rdout[63:48]; // R_hi
            2'b01:   rf_window_data = ext_rdout[47:32]; // R_lo
            2'b10:   rf_window_data = ext_rdout[31:16]; // I_hi
            default: rf_window_data = ext_rdout[15:0];  // I_lo
        endcase
    end

    assign mmio_read_data = status_sel    ? {15'd0, fft_done}
                          : rf_window_sel ? rf_window_data
                          :                 16'd0;

    // -------------------------------------------------------------------------
    // StarCore1 CPU
    // -------------------------------------------------------------------------
    StarCore1 cpu (
        .clk             (clk),
        .mem_access_addr (cpu_mem_addr),
        .mem_read_out    (cpu_mem_read),
        .fft_run         (cpu_fft_run),
        .stall           (stall),
        .mmio_read_data  (mmio_read_data),
        .mmio_read_sel   (mmio_read_sel)
    );

    // -------------------------------------------------------------------------
    // FFT Coprocessor
    //   Sample data must be preloaded into fft.mem.rf[] in NATURAL order
    //   (e.g. via $readmemb or hierarchical writes from the testbench)
    //   before fft_run pulses. The SoC's SWAP phase applies the bit-reversal
    //   required by the DIT algorithm.
    // -------------------------------------------------------------------------
    FFT_Coprocessor fft (
        .clk        (clk),
        .rst        (fft_rst),
        .done       (fft_done),
        .ext_active (ext_active),
        .ext_addr_a (ext_addr_a),
        .ext_addr_b (ext_addr_b),
        .ext_we     (ext_we),
        .ext_raddr  (ext_raddr),
        .ext_rdout  (ext_rdout)
    );

endmodule
