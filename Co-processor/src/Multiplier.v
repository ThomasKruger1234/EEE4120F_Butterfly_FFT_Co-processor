// =========================================================================
// Butterfly FFT Co-processor — Building Block: Q10.22 Signed Multiplier
// =========================================================================
//
// GROUP NUMBER: 8
//
// MEMBERS:
//   - Thomas Kruger, KRGTHO002
//   - Tamryn Osler,  OSLTAM001
//   - Krishnaraj Eswari Niranjan, EWSKRI001

// File        : Multiplier.v
// Description : 32-bit signed Q10.22 multiplier.
//               Computes (a * b) where both operands are interpreted as
//               Q10.22 fixed-point (10 integer bits including sign,
//               22 fractional bits; range ~[-512, +512)).
//
//               Q10.22 * Q10.22 produces a Q20.44 64-bit full product:
//                   bits 63:54 = 10 high-order integer bits (sign-extension
//                                of the result when no overflow occurs)
//                   bit  53    = sign / top integer bit of the Q10.22 result
//                   bits 52:44 = remaining 9 integer bits
//                   bits 43:22 = 22 fractional bits we keep
//                   bits 21:0  = 22 low fractional bits we truncate
//
//               To narrow back to Q10.22 we take bits [53:22].
//               (No rounding — simple truncation toward negative infinity.
//                No saturation — the surrounding system must keep results
//                within the Q10.22 range.)
//
//               This is a purely combinational module
// =============================================================================

`ifndef MULTIPLIER_V
`define MULTIPLIER_V

`timescale 1ns / 1ps
//`include "../src/Parameter.v"

module Multiplier (
    input  signed [31:0] a,             // Operand A — Q10.22 signed
    input  signed [31:0] b,             // Operand B — Q10.22 signed
    output signed [31:0] result         // a * b reinterpreted as Q10.22 signed
);

    // -------------------------------------------------------------------------
    // Full 64-bit signed product (Q20.44). Both operands are declared `signed`
    // so Verilog uses signed multiplication semantics.
    // -------------------------------------------------------------------------
    wire signed [63:0] full_product;

    assign full_product = a * b;

    // -------------------------------------------------------------------------
    // Narrow Q20.44 -> Q10.22 by taking bits [53:22].
    //   bits 63:54 are dropped (they duplicate bit 53 whenever the result
    //              actually fits in Q10.22; if they differ from bit 53 the
    //              result has overflowed and the truncation is incorrect).
    //   bits 21:0  are dropped (truncated low fractional bits).
    // -------------------------------------------------------------------------
    assign result = full_product[53:22];

endmodule

`endif
