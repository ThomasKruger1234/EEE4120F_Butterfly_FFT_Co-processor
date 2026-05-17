// =========================================================================
// EEE4120F YODA Project: Fast Fourier Butterfly Co-processor in Verilog
// =========================================================================
//
// GROUP 8
//
// MEMBERS:
//   - Thomas Kruger, KRGTHO002
//   - Tamryn Osler, OSLTAM001
//   - Krishnaraj Eswari Niranjan, ESWKRI001
//
// File        : FFT_Coprocessor.v
// Description : Top-level wrapper that wires together the Controller,
//               ButterflyMemory, TwiddleMemory and ButterflyCompute into a
//               256-point radix-2 DIT FFT co-processor.
//
//               Samples must be pre-loaded into mem.rf[] in bit-reversed
//               positions before rst is released. Results are read out of
//               mem.rf[] in natural order once `done` asserts.
//
//               advance free-runs at 1 from end-of-reset until done
//               latches high (1024 cycles = 8 stages * 128 butterflies),
//               at which point the core idles forever.
//
// ===========================================================================

`ifndef FFT_COPROCESSOR_V
`define FFT_COPROCESSOR_V

`timescale 1ns / 1ps

`include "Controller.v"
`include "ButterflyMemory.v"
`include "ButterflyCompute.v"
`include "TwiddleMemory.v"

module FFT_Coprocessor (
    input  wire clk,
    input  wire rst,
    output wire done,

    // -------------------------------------------------------------------------
    // SoC integration: pass-through to ButterflyMemory's external port
    //   ext_active/ext_addr_a/ext_addr_b/ext_we are used by SoC.v's bit-reverse
    //   swap FSM. ext_raddr/ext_rdout expose any rf[] entry to the SoC's MMIO
    //   read window. Tied off in legacy testbenches.
    // -------------------------------------------------------------------------
    input  wire        ext_active,
    input  wire [7:0]  ext_addr_a,
    input  wire [7:0]  ext_addr_b,
    input  wire        ext_we,
    input  wire [7:0]  ext_raddr,
    output wire [63:0] ext_rdout
);

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------
    wire        advance;
    wire        ctrl_done;
    wire [6:0]  iteration;
    wire [2:0]  stage;
    wire [7:0]  addr_a, addr_b;
    wire [7:0]  twiddle_addr;

    wire signed [31:0] dout_a_real, dout_a_imag;
    wire signed [31:0] dout_b_real, dout_b_imag;
    wire signed [31:0] A_real, A_imag;
    wire signed [31:0] B_real, B_imag;
    wire        [31:0] tw_real, tw_imag;

    // -------------------------------------------------------------------------
    // Done latch + we gating
    //   Controller.done is a 1-cycle pulse semantics signal — latch it so
    //   the external `done` output stays high, and use the latch to stop
    //   advance so the core idles after the last butterfly.
    // -------------------------------------------------------------------------
    reg done_latch;
    always @(posedge clk) begin
        if (rst)            done_latch <= 1'b0;
        else if (ctrl_done) done_latch <= 1'b1;
    end

    assign done        = done_latch;
    assign advance = ~done_latch & ~rst;

    // -------------------------------------------------------------------------
    // Controller — emits addresses and the twiddle index per cycle
    // -------------------------------------------------------------------------
    Controller ctrl (
        .clk          (clk),
        .rst          (rst),
        .advance      (advance),
        .iteration    (iteration),
        .stage        (stage),
        .done         (ctrl_done),
        .addr_a       (addr_a),
        .addr_b       (addr_b),
        .twiddle_addr (twiddle_addr)
    );

    // -------------------------------------------------------------------------
    // Twiddle ROM (combinational read)
    // -------------------------------------------------------------------------
    TwiddleMemory tw (
        .k            (twiddle_addr),
        .twiddle_real (tw_real),
        .twiddle_imag (tw_imag)
    );

    // -------------------------------------------------------------------------
    // Butterfly memory (sync write, combinational read)
    // -------------------------------------------------------------------------
    Butterfly_Memory_Reg mem (
        .clk         (clk),
        .we          (advance),
        .addr_a      (addr_a),
        .addr_b      (addr_b),
        .din_a_real  (A_real),
        .din_a_imag  (A_imag),
        .din_b_real  (B_real),
        .din_b_imag  (B_imag),
        .dout_a_real (dout_a_real),
        .dout_a_imag (dout_a_imag),
        .dout_b_real (dout_b_real),
        .dout_b_imag (dout_b_imag),
        // SoC integration pass-through
        .ext_active  (ext_active),
        .ext_addr_a  (ext_addr_a),
        .ext_addr_b  (ext_addr_b),
        .ext_we      (ext_we),
        .ext_raddr   (ext_raddr),
        .ext_rdout   (ext_rdout)
    );

    // -------------------------------------------------------------------------
    // Butterfly datapath (pure combinational)
    //   (A, B) = (a + W*b, a - W*b)
    // -------------------------------------------------------------------------
    ButterflyCompute bfly (
        .a_real (dout_a_real),
        .a_imag (dout_a_imag),
        .b_real (dout_b_real),
        .b_imag (dout_b_imag),
        .w_real (tw_real),
        .w_imag (tw_imag),
        .A_real (A_real),
        .A_imag (A_imag),
        .B_real (B_real),
        .B_imag (B_imag)
    );

endmodule

`endif
