`ifndef MEMORY_CONTROLLER_V
`define MEMORY_CONTROLLER_V

`timescale 1ns / 1ps

module Butterfly_Memory_Reg (
    input clk,
    input we,                       // Write Enable (from Controller)
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
    output signed [31:0] dout_b_imag,

    // -------------------------------------------------------------------------
    // SoC integration: external in-place swap port + MMIO read port
    //   When ext_active=1, addr_a/addr_b/we come from the SoC and the data
    //   path is hard-wired to swap rf[ext_addr_a] <-> rf[ext_addr_b] (one
    //   clock per pair, using Verilog non-blocking semantics). When
    //   ext_active=0, behaviour is identical to the original module.
    //
    //   ext_raddr/ext_rdout are a third combinational read port used by the
    //   SoC's MMIO read window to expose any rf[] entry to the CPU.
    // -------------------------------------------------------------------------
    input         ext_active,
    input  [7:0]  ext_addr_a,
    input  [7:0]  ext_addr_b,
    input         ext_we,
    input  [7:0]  ext_raddr,
    output [63:0] ext_rdout
);

    // 256 words of 64-bit complex data
    reg [63:0] rf [255:0];

    // --- Write-port mux (Controller vs SoC swap) -----------------------------
    wire [7:0]  eff_addr_a = ext_active ? ext_addr_a : addr_a;
    wire [7:0]  eff_addr_b = ext_active ? ext_addr_b : addr_b;
    wire        eff_we     = ext_active ? ext_we     : we;
    // In swap mode, din_a takes the OLD value at addr_b and vice versa.
    // Non-blocking assignment means both RHS reads sample rf[] before the
    // edge's writes commit, so the swap completes in one clock per pair.
    wire [63:0] eff_din_a  = ext_active ? rf[eff_addr_b]
                                        : {din_a_real, din_a_imag};
    wire [63:0] eff_din_b  = ext_active ? rf[eff_addr_a]
                                        : {din_b_real, din_b_imag};

    always @(posedge clk) begin
        if (eff_we) begin
            rf[eff_addr_a] <= eff_din_a;
            rf[eff_addr_b] <= eff_din_b;
        end
    end

    // --- Asynchronous Read Ports ---
    // Provides immediate data to the ButterflyDatapath
    assign {dout_a_real, dout_a_imag} = rf[addr_a];
    assign {dout_b_real, dout_b_imag} = rf[addr_b];

    // --- SoC MMIO read port (third combinational read) -----------------------
    assign ext_rdout = rf[ext_raddr];

endmodule

`endif
