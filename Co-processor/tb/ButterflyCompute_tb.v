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
// File        : ButterflyCompute_tb.v
// Description : Standalone testbench for the ButterflyCompute datapath.
//               Drives known (A, B, W) complex triples and checks the two
//               complex butterfly outputs:
//
//                   A' = A + (W * B)
//                   B' = A - (W * B)
//
//               All values are 32-bit signed Q10.22 (10 integer bits
//               including sign, 22 fractional bits; 1.0 = 0x00400000).
//
//               The Datapath is purely combinational, so each test case
//               just sets the inputs, waits #1 for them to settle, and
//               compares the outputs to hand-computed expected values.
//
// Run:
//   cd Co-processor
//   iverilog -Wall -I src/ -o build/butterflycompute_sim \
//            src/ButterflyCompute.v tb/ButterflyCompute_tb.v
//   ./build/butterflycompute_sim
//   gtkwave waves/butterflycompute_tb.vcd
// ===========================================================================

`timescale 1ns / 1ps

module ButterflyCompute_tb;

    // -------------------------------------------------------------------------
    // Q10.22 numeric landmarks. 1.0 == (1 << 22) == 0x00400000.
    // Using localparam (not `define) so each value is a properly typed
    // 32-bit signed constant.
    // -------------------------------------------------------------------------
    localparam signed [31:0] Q_ZERO     = 32'h00000000;  //  0.0
    localparam signed [31:0] Q_ONE      = 32'h00400000;  // +1.0
    localparam signed [31:0] Q_NEG_ONE  = 32'hFFC00000;  // -1.0
    localparam signed [31:0] Q_HALF     = 32'h00200000;  // +0.5
    localparam signed [31:0] Q_NEG_HALF = 32'hFFE00000;  // -0.5
    localparam signed [31:0] Q_TWO      = 32'h00800000;  // +2.0

    // sqrt(2)/2 ~ 0.7071068, taken from TwiddleMemory[32] (N = 256).
    localparam signed [31:0] Q_R2_2     = 32'h002D413D;  // +0.7071068
    localparam signed [31:0] Q_NEG_R2_2 = 32'hFFD2BEC3;  // -0.7071068

    // -------------------------------------------------------------------------
    // DUT inputs and outputs
    // -------------------------------------------------------------------------
    reg  signed [31:0] a_real, a_imag;
    reg  signed [31:0] b_real, b_imag;
    reg  signed [31:0] w_real, w_imag;
    wire signed [31:0] A_real, A_imag;
    wire signed [31:0] B_real, B_imag;

    // Test progress / failure tally
    integer checks   = 0;
    integer failures = 0;

    // -------------------------------------------------------------------------
    // DUT instance
    // -------------------------------------------------------------------------
    ButterflyCompute dut (
        .a_real (a_real), .a_imag (a_imag),
        .b_real (b_real), .b_imag (b_imag),
        .w_real (w_real), .w_imag (w_imag),
        .A_real (A_real), .A_imag (A_imag),
        .B_real (B_real), .B_imag (B_imag)
    );

    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("waves/butterflycompute_tb.vcd");
        $dumpvars(0, ButterflyCompute_tb);
    end

    // -------------------------------------------------------------------------
    // Bit-exact check. Use when every operand is a clean Q10.22 value
    // (multiples of 0.5, +/-1, etc.) so the truncating multiplier should
    // produce no LSB error.
    // -------------------------------------------------------------------------
    task check_exact;
        input [31:0] er_A_real;
        input [31:0] er_A_imag;
        input [31:0] er_B_real;
        input [31:0] er_B_imag;
        begin
            #1;                                  // let combinational logic settle
            checks = checks + 1;
            if (A_real !== er_A_real || A_imag !== er_A_imag ||
                B_real !== er_B_real || B_imag !== er_B_imag) begin
                $display("FAIL  A'=(%h,%h) exp (%h,%h)   B'=(%h,%h) exp (%h,%h)",
                         A_real, A_imag, er_A_real, er_A_imag,
                         B_real, B_imag, er_B_real, er_B_imag);
                failures = failures + 1;
            end else begin
                $display("PASS  A'=(%h,%h)  B'=(%h,%h)",
                         A_real, A_imag, B_real, B_imag);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Tolerance check. Use when the twiddle is irrational and the
    // multiplier's truncation can shift the result by a few LSBs.
    //
    // The Datapath uses 4 truncating multiplies feeding into 2 layers of
    // add/sub, so worst-case accumulated truncation per output is around
    // 4 LSBs. tol = 8 leaves comfortable headroom.
    // -------------------------------------------------------------------------
    task check_tol;
        input [31:0] er_A_real;
        input [31:0] er_A_imag;
        input [31:0] er_B_real;
        input [31:0] er_B_imag;
        input integer tol;
        integer ok;
        begin
            #1;
            checks = checks + 1;
            ok = (abs_diff(A_real, er_A_real) <= tol) &&
                 (abs_diff(A_imag, er_A_imag) <= tol) &&
                 (abs_diff(B_real, er_B_real) <= tol) &&
                 (abs_diff(B_imag, er_B_imag) <= tol);
            if (!ok) begin
                $display("FAIL (tol=%0d)  A'=(%h,%h) exp (%h,%h)   B'=(%h,%h) exp (%h,%h)",
                         tol,
                         A_real, A_imag, er_A_real, er_A_imag,
                         B_real, B_imag, er_B_real, er_B_imag);
                failures = failures + 1;
            end else begin
                $display("PASS (tol=%0d)  A'=(%h,%h)  B'=(%h,%h)",
                         tol, A_real, A_imag, B_real, B_imag);
            end
        end
    endtask

    // |x - y| as a plain integer. Operand range here is well within +/-2^30
    // so the subtraction cannot overflow a 32-bit signed integer.
    function integer abs_diff;
        input signed [31:0] x;
        input signed [31:0] y;
        integer d;
        begin
            d = x - y;
            abs_diff = (d < 0) ? -d : d;
        end
    endfunction

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $display("=== ButterflyCompute datapath testbench ===");

        // ---------------------------------------------------------------------
        // Case 1 — identity twiddle, A == B == 1+0j
        //   W*B = 1+0j
        //   A' = 2+0j, B' = 0+0j
        //   Pure add/sub sanity check.
        // ---------------------------------------------------------------------
        $write("[1] identity W=1, A=B=1+0j           : ");
        a_real = Q_ONE;  a_imag = Q_ZERO;
        b_real = Q_ONE;  b_imag = Q_ZERO;
        w_real = Q_ONE;  w_imag = Q_ZERO;
        check_exact(Q_TWO, Q_ZERO,    // A' = 2+0j
                    Q_ZERO, Q_ZERO);  // B' = 0+0j

        // ---------------------------------------------------------------------
        // Case 2 — identity twiddle on a purely-imaginary B
        //   W*B = 0+1j
        //   A' = 0+1j, B' = 0-1j
        //   Imag side of the final add/sub.
        // ---------------------------------------------------------------------
        $write("[2] identity W=1, B=0+1j             : ");
        a_real = Q_ZERO; a_imag = Q_ZERO;
        b_real = Q_ZERO; b_imag = Q_ONE;
        w_real = Q_ONE;  w_imag = Q_ZERO;
        check_exact(Q_ZERO, Q_ONE,
                    Q_ZERO, Q_NEG_ONE);

        // ---------------------------------------------------------------------
        // Case 3 — pure-imaginary twiddle, real B
        //   W = 0+1j, B = 1+0j  ->  W*B = j*1 = 0+1j
        //   A' = 0+1j, B' = 0-1j
        //   Catches cross-term wiring: w_imag * b_real must land in the
        //   imag side via wb_imag = pp3 + pp4.
        // ---------------------------------------------------------------------
        $write("[3] twiddle=j, B=1+0j                : ");
        a_real = Q_ZERO; a_imag = Q_ZERO;
        b_real = Q_ONE;  b_imag = Q_ZERO;
        w_real = Q_ZERO; w_imag = Q_ONE;
        check_exact(Q_ZERO, Q_ONE,
                    Q_ZERO, Q_NEG_ONE);

        // ---------------------------------------------------------------------
        // Case 4 — j * j = -1
        //   W = 0+1j, B = 0+1j  ->  W*B = -1+0j
        //   A' = -1+0j, B' = +1+0j
        //   Catches the sign of wb_real = pp1 - pp2 (here 0 - 1 = -1).
        // ---------------------------------------------------------------------
        $write("[4] twiddle=j, B=0+1j  (j*j = -1)    : ");
        a_real = Q_ZERO; a_imag = Q_ZERO;
        b_real = Q_ZERO; b_imag = Q_ONE;
        w_real = Q_ZERO; w_imag = Q_ONE;
        check_exact(Q_NEG_ONE, Q_ZERO,
                    Q_ONE,     Q_ZERO);

        // ---------------------------------------------------------------------
        // Case 5 — negative real twiddle
        //   W = -1+0j, B = 1+0j  ->  W*B = -1+0j
        //   A' = -1+0j, B' = +1+0j
        //   Confirms signed multiply works with a negative operand.
        // ---------------------------------------------------------------------
        $write("[5] twiddle=-1, B=1+0j               : ");
        a_real = Q_ZERO;    a_imag = Q_ZERO;
        b_real = Q_ONE;     b_imag = Q_ZERO;
        w_real = Q_NEG_ONE; w_imag = Q_ZERO;
        check_exact(Q_NEG_ONE, Q_ZERO,
                    Q_ONE,     Q_ZERO);

        // ---------------------------------------------------------------------
        // Case 6 — half-scale twiddle
        //   W = 0.5+0j, B = 1+0j  ->  W*B = 0.5+0j
        //   A' = +0.5+0j, B' = -0.5+0j
        //   Confirms multiplier alignment with a non-1, non-zero fraction.
        // ---------------------------------------------------------------------
        $write("[6] twiddle=0.5, B=1+0j              : ");
        a_real = Q_ZERO; a_imag = Q_ZERO;
        b_real = Q_ONE;  b_imag = Q_ZERO;
        w_real = Q_HALF; w_imag = Q_ZERO;
        check_exact(Q_HALF,     Q_ZERO,
                    Q_NEG_HALF, Q_ZERO);

        // ---------------------------------------------------------------------
        // Case 7 — realistic FFT butterfly with truncation error
        //   A = 0+0j, B = sqrt(2)/2 + 0j, W = sqrt(2)/2 + 0j
        //   W*B = (sqrt(2)/2)^2 = 0.5 mathematically, but the truncating
        //         Q10.22 multiplier returns ~ 0x001FFFF9 (~7 LSBs low).
        //   A' ~ +0.5+0j, B' ~ -0.5+0j  (within +/-8 LSB tolerance)
        //   This is the only case that exercises real truncation in the
        //   multiplier; all others use clean (1, 0, +/-0.5) operands.
        // ---------------------------------------------------------------------
        $write("[7] twiddle=B=sqrt(2)/2 (truncates)  : ");
        a_real = Q_ZERO; a_imag = Q_ZERO;
        b_real = Q_R2_2; b_imag = Q_ZERO;
        w_real = Q_R2_2; w_imag = Q_ZERO;
        check_tol(Q_HALF,     Q_ZERO,    // A' ~ +0.5+0j
                  Q_NEG_HALF, Q_ZERO,    // B' ~ -0.5+0j
                  8);                    // +/-8 LSB tolerance

        // ---------------------------------------------------------------------
        // Summary
        // ---------------------------------------------------------------------
        $display("");
        if (failures == 0)
            $display("ALL %0d TESTS PASSED", checks);
        else
            $display("%0d / %0d TESTS FAILED", failures, checks);

        $finish;
    end

endmodule
