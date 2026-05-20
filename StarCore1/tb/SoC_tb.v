// =========================================================================
// EEE4120F YODA Project: SoC-level integration testbench
// =========================================================================
//
// File        : SoC_tb.v
// Description : Exercises the full SoC path:
//                 1. Load samples in NATURAL order into fft.mem.rf[] from
//                    Golden-Measures/input_sequential.mem.
//                 2. Override InstructionMemory.PROG_FILE so the CPU runs
//                    fft_test.prog (FFT_RUN at PC=0, jump-to-self at PC=2).
//                 3. Let the CPU fetch FFT_RUN. The SoC FSM transitions
//                    IDLE -> SWAP (256 cyc, in-place bit-reversal via the
//                    ButterflyMemory ext_* port) -> RUN (FFT compute) -> DONE.
//                 4. On fft_done rising edge, dump rf[] in natural order
//                    (DIT FFT output ordering) and finish.
//
//               Contrast with Co-processor/tb/FFT_Coprocessor_tb.v which
//               instantiates FFT_Coprocessor standalone and bit-reverses at
//               load time. Here the bit-reversal happens in hardware.
// =========================================================================

`timescale 1ns / 1ps

module SoC_tb;

    // ----- Parameters -------------------------------------------------------
    localparam integer N           = 256;
    localparam integer CLK_PERIOD  = 10;
    localparam real    Q_SCALE     = 4194304.0;   // 2^22

    // ----- DUT --------------------------------------------------------------
    reg clk = 1'b0;

    SoC dut (
        .clk (clk)
    );

    // Override the InstructionMemory program path so the CPU runs the FFT
    // trigger program instead of the StarCore1 unit-test program.
    // Hierarchy: SoC.cpu (StarCore1) -> DU (Datapath) -> im (InstructionMemory)
    defparam dut.cpu.DU.im.PROG_FILE = "../test/fft_test.prog";

    // Override the TwiddleMemory data path. Default points to a path that
    // only resolves when sim CWD == repo root (Co-processor/Makefile case);
    // here we run from Verilog-Files/test/ so go up two levels.
    defparam dut.fft.tw.TWIDDLE_FILE = "../../Co-processor/src/twiddle.data";

    // ----- Clock ------------------------------------------------------------
    always #(CLK_PERIOD/2) clk = ~clk;

    // ----- Sample loader (natural order — SoC FSM does the bit-reversal) ----
    integer file_pointer;
    integer scan_status;
    integer n;
    reg signed [31:0] file_real;
    reg signed [31:0] file_imag;

    task load_file_data;
        begin
            for (n = 0; n < N; n = n + 1) begin
                dut.fft.mem.rf[n] = 64'd0;
            end

            file_pointer = $fopen("../../Golden-Measures/input_sequential.mem", "r");
            if (file_pointer == 0) begin
                $display("ERROR: Could not open ../../Golden-Measures/input_sequential.mem");
                $finish;
            end

            for (n = 0; n < N; n = n + 1) begin
                scan_status = $fscanf(file_pointer, "%h\n", file_real);
                scan_status = $fscanf(file_pointer, "%h\n", file_imag);
                // NATURAL order — no bitrev. SoC's S_SWAP phase will permute.
                dut.fft.mem.rf[n] = {file_real, file_imag};
            end

            $fclose(file_pointer);
            $display("[%0t] Loaded %0d samples into rf[] in natural order.",
                     $time, N);
        end
    endtask

    // ----- Output dump (natural order — DIT FFT output ordering) ------------
    integer            k;
    reg signed [31:0]  re_q, im_q;
    real               re_r, im_r, mag_r;

    task dump_outputs;
        begin
            $display("---- FFT output (256 bins, natural order) ----");
            $display(" k  | re(hex)    re(dec)        | im(hex)    im(dec)        | |X[k]|");
            $display("----+-----------+---------------+-----------+---------------+---------------");
            for (k = 0; k < N; k = k + 1) begin
                re_q  = dut.fft.mem.rf[k][63:32];
                im_q  = dut.fft.mem.rf[k][31:0];
                re_r  = $itor(re_q) / Q_SCALE;
                im_r  = $itor(im_q) / Q_SCALE;
                mag_r = $sqrt(re_r*re_r + im_r*im_r);
                $display("%3d | 0x%08h %13.4f | 0x%08h %13.4f | %13.4f",
                         k, re_q, re_r, im_q, im_r, mag_r);
            end
            $display("--------------------------------------------------------------");
            $display("Stimulus : multi-tone sum from signal-generator.py");
            $display("           (default frequencies = [1, 10, 127] @ fs=256)");
        end
    endtask

    // ----- Main stimulus ----------------------------------------------------
    initial begin
        $dumpfile("../waves/soc_tb.vcd");
        $dumpvars(0, SoC_tb);

        // Load rf[] at time 0 so the SoC has valid data when the CPU's
        // first fetch (FFT_RUN at PC=0) kicks off the S_SWAP FSM on the
        // first posedge clk.
        load_file_data;

        $display("[%0t] SoC released; waiting for fft_done...", $time);
        @(posedge dut.fft_done);
        $display("[%0t] fft_done asserted.", $time);

        dump_outputs;
        $finish;
    end

    // ----- Safety timeout ---------------------------------------------------
    initial begin
        #(CLK_PERIOD * 5000);
        $display("ERROR: timeout — fft_done never asserted.");
        $finish;
    end

endmodule
