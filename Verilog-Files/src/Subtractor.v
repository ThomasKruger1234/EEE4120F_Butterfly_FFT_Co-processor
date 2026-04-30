// =========================================================================
// Butterfly FFT Co-processor — Building Block: Q1.15 Signed Subtractor
// =========================================================================
//
// GROUP NUMBER: 8
//
// MEMBERS:
//   - Thomas Kruger, KRGTHO002
//   - Tamryn Osler,  OSLTAM001
//   - Krishnaraj Eswari Niranjan, EWSKRI001


// File        : Subtractor.v
// Description : 16-bit signed subtractor for Q1.15 fixed-point operands.
//               Computes (a - b) using a single signed subtraction.
//               Both operands and the result share the Q1.15 format.
//
//               No overflow detection or saturation is performed. The
//               surrounding system is responsible for keeping inputs within
//               a safe range so the difference stays inside Q1.15. The
//               expected approach for the FFT is per-stage scaling by 1/2
//               (a `>>1` shift between butterfly stages) so magnitudes
//               never exceed the Q1.15 range.
//
//               This is a purely combinational module — no clock, no state.
// =============================================================================

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module Subtractor (
    input  signed [15:0] a,             // Operand A — Q1.15 signed
    input  signed [15:0] b,             // Operand B — Q1.15 signed
    output signed [15:0] result         // a - b — Q1.15 signed
);

    assign result = a - b;

endmodule
