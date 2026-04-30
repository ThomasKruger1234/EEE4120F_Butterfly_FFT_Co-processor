// =========================================================================
// Butterfly FFT Co-processor — Datapath
// =========================================================================
//
// GROUP NUMBER: 8
//
// MEMBERS:
//   - Thomas Kruger, KRGTHO002
//   - Tamryn Osler,  OSLTAM001\
//   - Krishnaraj Eswari Niranjan, EWSKRI001


// File        : ButterflyDatapath.v
// Description : Butterfly compute datapath.
//               Takes two complex inputs A, B and a complex twiddle factor W
//               and produces the two complex butterfly outputs:
//
//                   A' = A + (W * B)
//                   B' = A - (W * B)
//
//               All operands and results are 16-bit signed Q1.15 fixed-point.
//               Each complex value is split into separate real and imaginary
//               16-bit ports.
//
//               The datapath is purely combinational. It
//               instantiates four Multipliers, three Adders, and three
//               Subtractors and wires them together. There is no clock,
//               no FSM, and no register inside this module.
//
//               Internal dataflow (three layers):
//
//                 Layer 1 — partial products of W * B:
//                     wb_pp1 = w_real * b_real
//                     wb_pp2 = w_imag * b_imag
//                     wb_pp3 = w_real * b_imag
//                     wb_pp4 = w_imag * b_real
//
//                 Layer 2 — combine partial products into W * B:
//                     wb_real = wb_pp1 - wb_pp2
//                     wb_imag = wb_pp3 + wb_pp4
//
//                 Layer 3 — form A +/- (W * B):
//                     A_real = a_real + wb_real
//                     A_imag = a_imag + wb_imag
//                     B_real = a_real - wb_real
//                     B_imag = a_imag - wb_imag
// =============================================================================

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module ButterflyDatapath (
    // -------------------------------------------------------------------------
    // Operand A (complex) — Q1.15 signed
    // -------------------------------------------------------------------------
    input  signed [15:0] a_real,
    input  signed [15:0] a_imag,

    // -------------------------------------------------------------------------
    // Operand B (complex) — Q1.15 signed
    // -------------------------------------------------------------------------
    input  signed [15:0] b_real,
    input  signed [15:0] b_imag,

    // -------------------------------------------------------------------------
    // Twiddle factor W (complex) — Q1.15 signed.
    // -------------------------------------------------------------------------
    input  signed [15:0] w_real,
    input  signed [15:0] w_imag,

    // -------------------------------------------------------------------------
    // Butterfly outputs (complex) — Q1.15 signed.
    //   A_real, A_imag = A + (W * B)
    //   B_real, B_imag = A - (W * B)
    // -------------------------------------------------------------------------
    output signed [15:0] A_real,
    output signed [15:0] A_imag,
    output signed [15:0] B_real,
    output signed [15:0] B_imag
);

    // =========================================================================
    // INTERNAL WIRES
    // =========================================================================

    // --- Layer 1: partial products of W * B ----------------------------------
    wire signed [15:0] wb_pp1;          // w_real * b_real
    wire signed [15:0] wb_pp2;          // w_imag * b_imag
    wire signed [15:0] wb_pp3;          // w_real * b_imag
    wire signed [15:0] wb_pp4;          // w_imag * b_real

    // --- Layer 2: complex product W * B --------------------------------------
    wire signed [15:0] wb_real;         // wb_pp1 - wb_pp2
    wire signed [15:0] wb_imag;         // wb_pp3 + wb_pp4


    // =========================================================================
    // LAYER 1 — FOUR Q1.15 MULTIPLIERS
    // Compute the four real partial products that make up W * B.
    // =========================================================================

    Multiplier mul_wr_br (
        .a      (w_real),
        .b      (b_real),
        .result (wb_pp1)
    );

    Multiplier mul_wi_bi (
        .a      (w_imag),
        .b      (b_imag),
        .result (wb_pp2)
    );

    Multiplier mul_wr_bi (
        .a      (w_real),
        .b      (b_imag),
        .result (wb_pp3)
    );

    Multiplier mul_wi_br (
        .a      (w_imag),
        .b      (b_real),
        .result (wb_pp4)
    );


    // =========================================================================
    // LAYER 2 — FORM W * B
    //   wb_real = (w_real * b_real) - (w_imag * b_imag)
    //   wb_imag = (w_real * b_imag) + (w_imag * b_real)
    // =========================================================================

    Subtractor sub_wb_real (
        .a      (wb_pp1),
        .b      (wb_pp2),
        .result (wb_real)
    );

    Adder add_wb_imag (
        .a      (wb_pp3),
        .b      (wb_pp4),
        .result (wb_imag)
    );


    // =========================================================================
    // LAYER 3 — FORM A +/- (W * B)
    // The two complex butterfly outputs.
    // =========================================================================

    Adder add_A_real (
        .a      (a_real),
        .b      (wb_real),
        .result (A_real)
    );

    Adder add_A_imag (
        .a      (a_imag),
        .b      (wb_imag),
        .result (A_imag)
    );

    Subtractor sub_B_real (
        .a      (a_real),
        .b      (wb_real),
        .result (B_real)
    );

    Subtractor sub_B_imag (
        .a      (a_imag),
        .b      (wb_imag),
        .result (B_imag)
    );

endmodule
