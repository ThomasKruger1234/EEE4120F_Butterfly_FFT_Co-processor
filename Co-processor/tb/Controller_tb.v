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

// File        : Controller_tb.v
// Description : Testbench for Controller.v
//               Verifies:
//                 1. Reset initialises iteration=0, stage=0, done=0.
//                 2. iteration increments by 1 after each dummy action.
//                 3. iteration wraps to 0 and stage increments at iter==127.
//                 4. done pulses exactly once when stage==7, iter==127.
//               DUMMY_CYCLES is overridden to 10 so the sim finishes fast.
//
// ===========================================================================

`timescale 1ns / 1ps

module Controller_tb;

    // -------------------------------------------------------------------------
    // Speed-up: override DUMMY_CYCLES to 10 cycles instead of 100 000.
    // The DUT is instantiated with a defparam so we don't touch the source.
    // -------------------------------------------------------------------------
    localparam FAST_DUMMY = 32'd10;

    // -------------------------------------------------------------------------
    // Clock: 10 ns period (100 MHz)
    // -------------------------------------------------------------------------
    localparam CLK_PERIOD = 10;

    reg clk, rst;
    wire [6:0] iteration;
    wire [2:0] stage;
    wire       done;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    Controller uut (
        .clk       (clk),
        .rst       (rst),
        .iteration (iteration),
        .stage     (stage),
        .done      (done)
    );

    // Override the dummy cycle count for simulation speed
    defparam uut.DUMMY_CYCLES = FAST_DUMMY;

    // -------------------------------------------------------------------------
    // Clock generation
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------
    integer errors = 0;

    task check;
        input [6:0] exp_iter;
        input [2:0] exp_stage;
        input       exp_done;
        input [63:0] label;  // up to 8 ASCII chars packed — printed as %s
        begin
            if (iteration !== exp_iter || stage !== exp_stage || done !== exp_done) begin
                $display("FAIL [%0t] %s  got iter=%0d stage=%0d done=%0b  expected iter=%0d stage=%0d done=%0b",
                         $time, label,
                         iteration, stage, done,
                         exp_iter,  exp_stage, exp_done);
                errors = errors + 1;
            end else begin
                $display("PASS [%0t] %s  iter=%0d stage=%0d done=%0b",
                         $time, label, iteration, stage, done);
            end
        end
    endtask

    // Advance exactly one full iteration step.
    // S_ACTION holds for FAST_DUMMY cycles (timer counts 0 to FAST_DUMMY-1),
    // then transitions to S_UPDATE on the next posedge where outputs are latched.
    task step;
        begin
            repeat (FAST_DUMMY + 1) @(posedge clk);
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    integer s, it;

    initial begin
        $dumpfile("waves/Controller_tb.vcd");
        $dumpvars(0, Controller_tb);

        // ----------------------------------------------------------------
        // TEST 1: Reset behaviour
        // ----------------------------------------------------------------
        rst = 1;
        @(posedge clk); #1;
        check(7'd0, 3'd0, 1'b0, "RST    ");

        rst = 0;
        @(posedge clk); #1;

        // ----------------------------------------------------------------
        // TEST 2: First few iterations increment correctly (stage stays 0)
        // ----------------------------------------------------------------
        step; #1; check(7'd1, 3'd0, 1'b0, "ITER 1 ");
        step; #1; check(7'd2, 3'd0, 1'b0, "ITER 2 ");
        step; #1; check(7'd3, 3'd0, 1'b0, "ITER 3 ");

        // ----------------------------------------------------------------
        // TEST 3: Run to iter==127 → stage increments, iter wraps to 0.
        //         Currently at iter=3; 125 more steps reaches the 128th
        //         update of stage 0, which wraps iter to 0 and bumps stage.
        // ----------------------------------------------------------------
        repeat (125) step;
        #1; check(7'd0, 3'd1, 1'b0, "WRAP S1");

        // ----------------------------------------------------------------
        // TEST 4: Run through all remaining stages automatically,
        //         watching for the done pulse at stage=7 / iter=127.
        //         Each step() lands on the freshly-latched S_UPDATE output,
        //         so 128 steps advances one full stage (0→127→wrap).
        // ----------------------------------------------------------------

        // Finish stages 1 through 6 (128 steps each)
        repeat (6) begin
            repeat (128) step;
        end
        // Now at stage=7, iter=0
        #1; check(7'd0, 3'd7, 1'b0, "STG7 ST");

        // 127 more steps reaches iter=126. The final step() runs 11 posedges:
        // 10 for S_ACTION then 1 more which is S_UPDATE — after which the FSM
        // immediately moves to S_ACTION with done=1 visible. Sample right after.
        repeat (127) step;
        step; #1;
        check(7'd127, 3'd7, 1'b1, "DONE   ");

        // ----------------------------------------------------------------
        // TEST 5: done de-asserts on the next clock (only a 1-cycle pulse)
        // ----------------------------------------------------------------
        @(posedge clk); #1;
        if (done !== 1'b0) begin
            $display("FAIL [%0t] DONE_CLR  done should de-assert after one cycle, got done=%0b", $time, done);
            errors = errors + 1;
        end else begin
            $display("PASS [%0t] DONE_CLR  done correctly de-asserted", $time);
        end

        // ----------------------------------------------------------------
        // TEST 6: Mid-run reset clears state immediately
        // ----------------------------------------------------------------
        rst = 1;
        @(posedge clk); #1;
        check(7'd0, 3'd0, 1'b0, "RST2   ");
        rst = 0;

        // ----------------------------------------------------------------
        // Summary
        // ----------------------------------------------------------------
        $display("--------------------------------------------------");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);
        $display("--------------------------------------------------");

        $finish;
    end

    // -------------------------------------------------------------------------
    // Timeout guard — should never fire with FAST_DUMMY=10
    // -------------------------------------------------------------------------
    initial begin
        #5_000_000;
        $display("TIMEOUT: simulation exceeded limit");
        $finish;
    end

endmodule
