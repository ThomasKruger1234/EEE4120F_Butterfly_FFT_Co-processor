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
// File        : FFT_Coprocessor_tb.v
// Description : End-to-end testbench for FFT_Coprocessor.v
//               Stimulus is a single real cosine tone at bin K0 = 8.
//               While rst is held, samples are written in bit-reversed
//               order directly into uut.mem.rf[]. Reset is then released
//               and the testbench waits for `done`, after which all 256
//               output bins are printed in natural order.
//               Verification is display + VCD only (no automated check).
//
// ===========================================================================

`timescale 1ns / 1ps

module FFT_Coprocessor_tb;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam integer N          = 256;          // FFT length
    localparam integer K0         = 8;            // Cosine frequency bin
    localparam integer CLK_PERIOD = 10;
    localparam real    PI         = 3.14159265358979;
    localparam real    Q_SCALE    = 4194304.0;    // 2^22, Q10.22 scale

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    reg  clk;
    reg  rst;
    wire done;

    FFT_Coprocessor uut (
        .clk  (clk),
        .rst  (rst),
        .done (done)
    );

    // -------------------------------------------------------------------------
    // Clock
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // -------------------------------------------------------------------------
    // 8-bit reversal (N = 256)
    // -------------------------------------------------------------------------
    function [7:0] bitrev8;
        input [7:0] in;
        begin
            bitrev8 = {in[0], in[1], in[2], in[3],
                       in[4], in[5], in[6], in[7]};
        end
    endfunction

    // -------------------------------------------------------------------------
    // Sample loader: x[n] = cos(2*PI*K0*n/N), imag = 0, in Q10.22
    //   Written to uut.mem.rf[bitrev8(n)] so the DIT FFT sees natural-order
    //   input when it processes stage 0.
    // -------------------------------------------------------------------------
    integer            n;
    real               sample;
    reg signed [31:0]  q_real;
    reg signed [31:0]  q_imag;

    task load_cosine_tone;
        begin
            for (n = 0; n < N; n = n + 1)
                uut.mem.rf[n] = 64'd0;

            for (n = 0; n < N; n = n + 1) begin
                sample = $cos(2.0 * PI * K0 * n / N);
                q_real = $rtoi(sample * Q_SCALE);
                q_imag = 32'sd0;
                uut.mem.rf[bitrev8(n[7:0])] = {q_real, q_imag};
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Output dump
    // -------------------------------------------------------------------------
    integer            k;
    reg signed [31:0]  re_q, im_q;
    real               re_r, im_r, mag_r;

    task dump_outputs;
        begin
            $display("---- FFT output (256 bins, natural order) ----");
            $display(" k  | re(hex)    re(dec)        | im(hex)    im(dec)        | |X[k]|");
            $display("----+-----------+---------------+-----------+---------------+---------------");
            for (k = 0; k < N; k = k + 1) begin
                re_q  = uut.mem.rf[k][63:32];
                im_q  = uut.mem.rf[k][31:0];
                re_r  = $itor(re_q) / Q_SCALE;
                im_r  = $itor(im_q) / Q_SCALE;
                mag_r = $sqrt(re_r*re_r + im_r*im_r);
                $display("%3d | 0x%08h %13.4f | 0x%08h %13.4f | %13.4f",
                         k, re_q, re_r, im_q, im_r, mag_r);
            end
            $display("--------------------------------------------------------------");
            $display("Stimulus : x[n] = cos(2*pi*%0d*n/%0d)", K0, N);
            $display("Expected : peaks at k=%0d and k=%0d, |X[k]| ~= %0d (= N/2)",
                     K0, N - K0, N/2);
        end
    endtask

    // -------------------------------------------------------------------------
    // Main stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("waves/FFT_Coprocessor_tb.vcd");
        $dumpvars(0, FFT_Coprocessor_tb);

        rst = 1'b1;
        @(posedge clk);
        load_cosine_tone;
        @(posedge clk);

        @(negedge clk);
        rst = 1'b0;
        $display("[%0t] reset released; FFT running...", $time);

        @(posedge done);
        $display("[%0t] done asserted after FFT completion", $time);

        @(posedge clk);
        dump_outputs;

        $finish;
    end

    // -------------------------------------------------------------------------
    // Safety timeout — kills the sim if `done` never asserts
    // -------------------------------------------------------------------------
    initial begin
        #(CLK_PERIOD * 2000);
        $display("[%0t] TIMEOUT waiting for done", $time);
        $finish;
    end

endmodule
