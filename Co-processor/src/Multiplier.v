// =========================================================================
// Butterfly FFT Co-processor — Building Block: Q1.15 Signed Multiplier
// =========================================================================
//
// GROUP NUMBER: 8
//
// MEMBERS:
//   - Thomas Kruger, KRGTHO002
//   - Tamryn Osler,  OSLTAM001
//   - Krishnaraj Eswari Niranjan, EWSKRI001

// File        : Multiplier.v
// Description : 16-bit signed Q1.15 multiplier.
//               Computes (a * b) where both operands are interpreted as
//               Q1.15 fixed-point.
//
//               Q1.15 * Q1.15 produces a Q2.30 32-bit full product:
//                   bit 31    = redundant sign-extension bit
//                   bit 30    = sign / integer bit of the Q2.30 product
//                   bits 29:0 = 30 fractional bits
//
//               To narrow back to Q1.15 we drop the redundant top bit and
//               the lower 15 fractional bits, taking bits [30:15].
//               (No rounding — simple truncation toward negative infinity.)
//
//               This is a purely combinational module
// =============================================================================

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module Multiplier (
    input  signed [15:0] a,             // Operand A — Q1.15 signed
    input  signed [15:0] b,             // Operand B — Q1.15 signed
    output signed [15:0] result         // a * b reinterpreted as Q1.15 signed
);

    // -------------------------------------------------------------------------
    // Full 32-bit signed product (Q2.30). Both operands are declared `signed`
    // so Verilog uses signed multiplication semantics.
    // -------------------------------------------------------------------------
    wire signed [31:0] full_product;

    assign full_product = a * b;

    // -------------------------------------------------------------------------
    // Narrow Q2.30 -> Q1.15 by taking bits [30:15].
    //   bit 31 is dropped (it duplicates bit 30 for all results in [-1, +1)).
    //   bits 14:0 are dropped (truncated low fractional bits).
    // -------------------------------------------------------------------------
    assign result = full_product[30:15];

endmodule
