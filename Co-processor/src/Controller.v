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

// File        : IterStageCtrl.v
// Description : Iteration and stage controller for FFT butterfly co-processor.
//               Counts iteration from 0 to 127, then increments stage (0 to 7).
//               A 1ms dummy action delay separates each iteration step.
//               Asserts 'done' when stage == 7 and iteration == 127.
//
// ===========================================================================

`ifndef CONTROLLER_V
`define CONTROLLER_V

`timescale 1ns / 1ps

module Controller (
    input  wire clk,          		// System clock
    input  wire rst,          		// Synchronous active-high reset
	input  wire we,					// Write-enable pulse from memory controller
    output reg  [6:0] iteration,  	// Current iteration (0–127)
    output reg  [2:0] stage,      	// Current stage     (0–7)
    output reg  done,              	// Pulses high when stage=7, iteration=127
	output wire [7:0] addr_a,
	output wire [7:0] addr_b
);

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam MAX_ITER  = 7'd127;
    localparam MAX_STAGE = 3'd7;

    // -------------------------------------------------------------------------
    // Sequential logic
    // -------------------------------------------------------------------------
	always @(posedge clk) begin
		if (rst) begin
			iteration <= 7'd0;
			stage     <= 3'd0;
			done      <= 1'b0;
		end else begin
			done <= 1'b0;

			if (we) begin
				if (stage == MAX_STAGE && iteration == MAX_ITER) begin
					done <= 1'b1;
				end else if (iteration == MAX_ITER) begin
					iteration <= 7'd0;
					stage     <= stage + 1;
				end else begin
					iteration <= iteration + 1;
				end
			end
		end
	end

    // -------------------------------------------------------------------------
    // Combinational logic
	// Assignment with bit reversal
    // -------------------------------------------------------------------------
	
	// Values to reverse
	wire [7:0] addr_a_rev = {1'b0, iteration} + 8'd0 + {6'b0, iteration[1:0]};
	wire [7:0] addr_b_rev = {1'b0, iteration} + 8'd1 + {6'b0, iteration[1:0]};
	
	genvar i;
	generate
		for (i = 0; i < 8; i = i + 1) begin
			assign addr_a[i] = addr_a_rev[7-i];
			assign addr_b[i] = addr_b_rev[7-i];
		end
	endgenerate

endmodule

`endif
