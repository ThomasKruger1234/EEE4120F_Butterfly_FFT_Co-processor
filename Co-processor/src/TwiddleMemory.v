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

// File        : TwiddleMemory.v
// Description : Twiddle factor memory for FFT butterfly co-processor.
//             256 twiddle factors, each 32 bits real + 32 bits imaginary. 
//             Contents loaded at simulation start from
//             the binary file ./twiddle.data using $readmemh.
//
// ===========================================================================

`ifndef TWIDDLE_MEMORY_V
`define TWIDDLE_MEMORY_V

`timescale 1ns / 1ps
//`include "../src/Parameter.v"

module TwiddleMemory (
    input  [7:0] k,           // Address (0-255)
    output [31:0] twiddle_real,    // Fetched 32-bit real twiddle factor
    output [31:0] twiddle_imag     // Fetched 32-bit imaginary twiddle factor
);

    // -------------------------------------------------------------------------
    // Declare the twiddle factor memory array.
    //       It should hold 128 entries, each 64 bits wide.
    //       Each entry will store one twiddle factor: the upper 32 bits for the
    //       real part and the lower 32 bits for the imaginary part.
    // -------------------------------------------------------------------------
    reg[63:0] memory [127:0];

    // -------------------------------------------------------------------------
    // Derive the word address from the twiddle-step counter K.
    //
    //           PC=0x0000 -> rom_addr=0
    //           PC=0x0001 -> rom_addr=1
    //           PC=0x0002 -> rom_addr=2   ... and so on.
    //      Then wrap-around because twiddle factor is symmetrical
    //           PC=0x0080 -> rom_addr=0
    //           PC=0x0081 -> rom_addr=1
    //           PC=0x0082 -> rom_addr=2   ... and so on.
    // -------------------------------------------------------------------------
    wire [6:0] twiddle_addr = k[6:0];

    // -------------------------------------------------------------------------
    // Load the twiddle factor memory contents from file at simulation start.
    //       The file ./src/twiddle.data must contain one 32-bit binary value
    //       per line (e.g. 00000000010100000010000001010000).
    //       The first 128 lines will be loaded into the memory array, with the
    //       upper 32 bits of each entry representing the real part and the lower
    //       32 bits representing the imaginary part of the twiddle factor.
    // -------------------------------------------------------------------------
        initial begin
            $readmemh("src/twiddle.data", memory, 0, 127);
        end
    // -------------------------------------------------------------------------
    // Drive the twiddle output with a continuous assignment.
    // The output must update combinationally whenever twiddle_addr changes.
    // -------------------------------------------------------------------------
    assign twiddle_real = memory[twiddle_addr][63:32];
    assign twiddle_imag = memory[twiddle_addr][31:0];

endmodule

`endif
