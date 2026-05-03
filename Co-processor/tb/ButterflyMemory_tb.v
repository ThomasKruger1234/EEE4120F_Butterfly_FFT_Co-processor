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
// File        : ButterflyMemory_tb.v
// Description : Tests memory controller.
//
// Run:
//   cd Co-processor
//   iverilog -Wall -I src/ -o build/memorycontroller_sim src/ButterflyMemory.v _tb.v
//   cd ../test && ../build/memorycontroller_sim
//   gtkwave ../waves/memorycontroller_tb.vcd &
// ===========================================================================


`timescale 1ns / 1ps

`include "../src/TwiddleMemory.v"
`include "../src/ButterflyDatapath.v"

module ButterflyMemory_tb();

    // Clock and Control
    reg clk;
    reg we;
    reg [7:0] addr_a, addr_b;
    reg [7:0] k; // Twiddle address

    // Data Wires
    wire signed [31:0] mem_out_a_r, mem_out_a_i;
    wire signed [31:0] mem_out_b_r, mem_out_b_i;
    wire signed [31:0] twiddle_r, twiddle_i;
    wire signed [31:0] result_a_r, result_a_i;
    wire signed [31:0] result_b_r, result_b_i;

    // --- 1. Instantiate the Register-Based Memory ---
    Butterfly_Memory_Reg RAM (
        .clk(clk),
        .we(we),
        .addr_a(addr_a),
        .addr_b(addr_b),
        .din_a_real(result_a_r), .din_a_imag(result_a_i),
        .din_b_real(result_b_r), .din_b_imag(result_b_i),
        .dout_a_real(mem_out_a_r), .dout_a_imag(mem_out_a_i),
        .dout_b_real(mem_out_b_r), .dout_b_imag(mem_out_b_i)
    );

    // --- 2. Instantiate Twiddle Memory ---
    TwiddleMemory ROM (
        .k(k),
        .twiddle_real(twiddle_r),
        .twiddle_imag(twiddle_i)
    );

    // --- 3. Instantiate Butterfly Datapath ---
    ButterflyDatapath DU (
        .a_real(mem_out_a_r), .a_imag(mem_out_a_i),
        .b_real(mem_out_b_r), .b_imag(mem_out_b_i),
        .w_real(twiddle_r),   .w_imag(twiddle_i),
        .A_real(result_a_r),  .A_imag(result_a_i),
        .B_real(result_b_r),  .B_imag(result_b_i)
    );

    // Clock Generation
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz clock

	integer i;

    initial begin
        // Initialize Memory (Optional: load your test data here)
        // $readmemh("fft_input.data", RAM.rf); 
		for (i = 0; i < 256; i = i + 1)
			RAM.rf[i] = 64'd0;

		// Set specific test values
		RAM.rf[0] = {32'h00400000, 32'h00000000}; // A = 1.0 + 0j (Q10.22)
		RAM.rf[1] = {32'h00400000, 32'h00000000}; // B = 1.0 + 0j (Q10.22)
        
        // Initial setup
        we = 0;
        addr_a = 8'd0;
        addr_b = 8'd1;
        k = 8'd0;

        $display("Starting FFT Butterfly Test...");
        #10;

        // --- Cycle 1: Read and Compute ---
        // Since reads are combinational (Register-based), 
        // DU outputs are ready almost immediately.
        $display("Inputs: A=(%d, %d), B=(%d, %d)", mem_out_a_r, mem_out_a_i, mem_out_b_r, mem_out_b_i);
        
        // --- Cycle 2: Write Back ---
		//@(posedge clk); #1;
		#10
		we = 1; 
        //@(posedge clk); #1;
		#10
		we = 0;
        $display("Results Written to Addr 0 and 1");

        #20;
        $display("Test Complete.");
        $finish;
    end

    // Waveform Export
    initial begin
        $dumpfile("waves/ButterflyMemory_test.vcd");
        $dumpvars(0, ButterflyMemory_tb);
    end

endmodule
