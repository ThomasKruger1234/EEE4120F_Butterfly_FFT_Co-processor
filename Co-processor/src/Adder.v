// =========================================================================
// Butterfly FFT Co-processor — Building Block: Q10.22 Signed Adder
// =========================================================================
//
// GROUP NUMBER: 8
//
// MEMBERS:
//   - Thomas Kruger, KRGTHO002
//   - Tamryn Osler,  OSLTAM001
//   - Krishnaraj Eswari Niranjan, EWSKRI001


// File        : Adder.v
// Description : 32-bit signed adder for Q10.22 fixed-point operands.
//               Computes (a + b) using a single signed addition.
//               Both operands and the result share the Q10.22 format
//               (10 integer bits including sign, 22 fractional bits;
//                range ~[-512, +512)).
//
//               No overflow detection or saturation is performed. The
//               surrounding system is responsible for keeping inputs within
//               a safe range so the sum stays inside Q10.22. The expected
//               approach for the FFT is per-stage scaling by 1/2 (a `>>1`
//               shift between butterfly stages) so magnitudes never exceed
//               the Q10.22 range.
//
//               This is a purely combinational module
// =============================================================================

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module Adder (
    input  signed [31:0] a,             // Operand A — Q10.22 signed
    input  signed [31:0] b,             // Operand B — Q10.22 signed
    output signed [31:0] result         // a + b — Q10.22 signed
);

    assign result = a + b;

endmodule
