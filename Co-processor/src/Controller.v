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
    input  wire clk,          // System clock
    input  wire rst,          // Synchronous active-high reset
    output reg  [6:0] iteration,  // Current iteration (0–127)
    output reg  [2:0] stage,      // Current stage     (0–7)
    output reg  done              // Pulses high when stage=7, iteration=127
);

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam MAX_ITER  = 7'd127;
    localparam MAX_STAGE = 3'd7;

    // -------------------------------------------------------------------------
    // Dummy-action timer.
    //   With `timescale 1ns/1ps, 1 ms = 1_000_000 ns.
    //   The counter counts clock cycles; set DUMMY_CYCLES to match your
    //   actual clock frequency, or leave as-is for simulation.
    //
    //   Example: 100 MHz clock → 100_000 cycles per ms
    //   For pure simulation the exact value doesn't matter.
    // -------------------------------------------------------------------------
    parameter  DUMMY_CYCLES = 32'd100_000;  // 1 ms @ 100 MHz (overridable for simulation)

    reg [31:0] timer;
    reg        timer_done;

    // -------------------------------------------------------------------------
    // State machine
    // -------------------------------------------------------------------------
    localparam S_ACTION = 1'b0;   // Performing the dummy 1ms action
    localparam S_UPDATE = 1'b1;   // Updating iteration / stage counters

    reg state;

    // -------------------------------------------------------------------------
    // Sequential logic
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            iteration  <= 7'd0;
            stage      <= 3'd0;
            timer      <= 32'd0;
            timer_done <= 1'b0;
            done       <= 1'b0;
            state      <= S_ACTION;
        end else begin
            done <= 1'b0;  // Default: de-assert each cycle

            case (state)

                // ---------------------------------------------------------
                // S_ACTION : wait for 1 ms (dummy work per iteration step)
                // ---------------------------------------------------------
                S_ACTION: begin
                    if (timer < DUMMY_CYCLES - 1) begin
                        timer <= timer + 1;
                    end else begin
                        timer      <= 32'd0;
                        timer_done <= 1'b1;
                        state      <= S_UPDATE;
                    end
                end

                // ---------------------------------------------------------
                // S_UPDATE : advance iteration, then stage if needed
                // ---------------------------------------------------------
                S_UPDATE: begin
                    timer_done <= 1'b0;

                    if (stage == MAX_STAGE && iteration == MAX_ITER) begin
                        // All stages and iterations complete
                        done  <= 1'b1;
                        state <= S_ACTION;  // Halt here (or reset externally)
                    end else if (iteration == MAX_ITER) begin
                        // End of an iteration sweep → advance stage
                        iteration <= 7'd0;
                        stage     <= stage + 1;
                        state     <= S_ACTION;
                    end else begin
                        // Normal iteration increment
                        iteration <= iteration + 1;
                        state     <= S_ACTION;
                    end
                end

                default: state <= S_ACTION;

            endcase
        end
    end

endmodule

`endif
