`ifndef MEMORY_CONTROLLER_V
`define MEMORY_CONTROLLER_V

`timescale 1ns / 1ps

module Butterfly_Memory_Reg (
    input clk,
    input we,                       // Write Enable
    input [7:0] addr_a,             // Address for Operand A
    input [7:0] addr_b,             // Address for Operand B
    
    // Inputs to write back (Q10.22 from ButterflyDatapath)
    input signed [31:0] din_a_real,
    input signed [31:0] din_a_imag,
    input signed [31:0] din_b_real,
    input signed [31:0] din_b_imag,
    
    // Outputs (Combinational reads for speed)
    output signed [31:0] dout_a_real,
    output signed [31:0] dout_a_imag,
    output signed [31:0] dout_b_real,
    output signed [31:0] dout_b_imag
);

    // 256 words of 64-bit complex data
    reg [63:0] rf [255:0];

    // --- Synchronous Write Port ---
    // Matches DataMemory behavior in StarCore
    always @(posedge clk) begin
        if (we) begin
            rf[addr_a] <= {din_a_real, din_a_imag};
            rf[addr_b] <= {din_b_real, din_b_imag};
        end
    end

    // --- Asynchronous Read Ports ---
    // Provides immediate data to the ButterflyDatapath
    assign {dout_a_real, dout_a_imag} = rf[addr_a];
    assign {dout_b_real, dout_b_imag} = rf[addr_b];

endmodule

`endif
