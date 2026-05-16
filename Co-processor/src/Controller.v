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
	output wire [7:0] addr_b,
	output wire [7:0] twiddle_addr 	// Twiddle ROM index k for current butterfly
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
    // Butterfly pair address generator
    //   For stage s, butterfly i ∈ {0..127}:
    //     g = iteration[6:s] (group index), j = iteration[s-1:0] (in-group pos)
    //     addr_a = {g, 1'b0, j}, addr_b = {g, 1'b1, j}
    //   i.e. insert a 0 (addr_a) or 1 (addr_b) at bit position s of iteration.
    // -------------------------------------------------------------------------
    reg [7:0] addr_a_r, addr_b_r;
    always @(*) begin
        case (stage)
            3'd0: begin addr_a_r = {iteration[6:0], 1'b0};                 addr_b_r = {iteration[6:0], 1'b1};                 end
            3'd1: begin addr_a_r = {iteration[6:1], 1'b0, iteration[0:0]}; addr_b_r = {iteration[6:1], 1'b1, iteration[0:0]}; end
            3'd2: begin addr_a_r = {iteration[6:2], 1'b0, iteration[1:0]}; addr_b_r = {iteration[6:2], 1'b1, iteration[1:0]}; end
            3'd3: begin addr_a_r = {iteration[6:3], 1'b0, iteration[2:0]}; addr_b_r = {iteration[6:3], 1'b1, iteration[2:0]}; end
            3'd4: begin addr_a_r = {iteration[6:4], 1'b0, iteration[3:0]}; addr_b_r = {iteration[6:4], 1'b1, iteration[3:0]}; end
            3'd5: begin addr_a_r = {iteration[6:5], 1'b0, iteration[4:0]}; addr_b_r = {iteration[6:5], 1'b1, iteration[4:0]}; end
            3'd6: begin addr_a_r = {iteration[6:6], 1'b0, iteration[5:0]}; addr_b_r = {iteration[6:6], 1'b1, iteration[5:0]}; end
            3'd7: begin addr_a_r = {1'b0, iteration[6:0]};                 addr_b_r = {1'b1, iteration[6:0]};                 end
            default: begin addr_a_r = 8'd0; addr_b_r = 8'd0; end
        endcase
    end
    assign addr_a = addr_a_r;
    assign addr_b = addr_b_r;

    // -------------------------------------------------------------------------
    // Twiddle index generator
    //   k = (iteration mod 2^stage) << (7 - stage)
    // Places the low `stage` bits of iteration into the top `stage` positions
    // of a 7-bit field. Stage 0 always uses W^0.
    // -------------------------------------------------------------------------
    reg [6:0] k;
    always @(*) begin
        case (stage)
            3'd0: k = 7'd0;
            3'd1: k = {iteration[0],   6'd0};
            3'd2: k = {iteration[1:0], 5'd0};
            3'd3: k = {iteration[2:0], 4'd0};
            3'd4: k = {iteration[3:0], 3'd0};
            3'd5: k = {iteration[4:0], 2'd0};
            3'd6: k = {iteration[5:0], 1'd0};
            3'd7: k =  iteration[6:0];
            default: k = 7'd0;
        endcase
    end
    assign twiddle_addr = {1'b0, k};

endmodule

`endif
