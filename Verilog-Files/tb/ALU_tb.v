// =============================================================================
// EEE4120F Practical 4 — StarCore-1 Processor
// File        : ALU_tb.v
// Description : Testbench for the ALU module (Task 1).
//               Applies all 8 operations with multiple input pairs and checks
//               both the result output and the zero flag.
//               Produces automated PASS/FAIL output and a waveform dump.
//
// Run:
//   iverilog -Wall -I ../src -o ../build/alu_sim ../src/ALU.v ALU_tb.v
//   cd ../test && ../build/alu_sim
//   gtkwave ../waves/alu_tb.vcd &
// =============================================================================

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module ALU_tb;

    // -------------------------------------------------------------------------
    // DUT port connections
    // Inputs to the DUT are declared as reg (so the testbench can drive them).
    // Outputs from the DUT are declared as wire (driven by the DUT).
    // -------------------------------------------------------------------------
    reg  [15:0] a;
    reg  [15:0] b;
    reg  [ 2:0] alu_control;
    wire [15:0] result;
    wire        zero;

    // -------------------------------------------------------------------------
    // DUT instantiation — named port connections
    // -------------------------------------------------------------------------
    ALU uut (
        .a           (a),
        .b           (b),
        .alu_control (alu_control),
        .result      (result),
        .zero        (zero)
    );

    // -------------------------------------------------------------------------
    // Waveform dump — always include this block
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("../waves/alu_tb.vcd");
        $dumpvars(0, ALU_tb);
    end

    // -------------------------------------------------------------------------
    // Failure counter
    // -------------------------------------------------------------------------
    integer fail_count;
    integer test_id;

    initial begin
        fail_count = 0;
        test_id    = 1;
    end

    // -------------------------------------------------------------------------
    // Reusable check task
    // Compares 'got' against 'expected' and prints PASS or FAIL.
    // Increments fail_count on mismatch.
    // -------------------------------------------------------------------------
    task check_result;
        input [15:0] got;
        input [15:0] expected;
        input [63:0] id;        // test number for display
        begin
            if (got !== expected) begin
                $display("FAIL [T%0d]: result = %0d (0x%h), expected = %0d (0x%h)",
                         id, got, got, expected, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [T%0d]: result = %0d (0x%h)", id, got, got);
            end
        end
    endtask

    task check_zero;
        input got;
        input expected;
        input [63:0] id;
        begin
            if (got !== expected) begin
                $display("FAIL [T%0d] zero flag: got = %b, expected = %b", id, got, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [T%0d] zero flag = %b", id, got);
            end
        end
    endtask

    // =========================================================================
    // STIMULUS AND CHECKING
    // =========================================================================
    initial begin
        $display("=== ALU Testbench ===");
        $display("--- ADD (alu_control = 3'b000) ---");

        // TODO: Test ADD — apply at least three different input pairs.
        //       Format: a = X; b = Y; alu_control = 3'b000; #10;
        //               check_result(result, X+Y, test_id); test_id = test_id + 1;
        //
        //       Suggested pairs: (10,5), (0xFFFF, 1) [overflow], (0, 0)

        // Input 1: a = 10, b = 5
        a = 16'd10; b = 16'd5; alu_control = 3'b000; #10;
        check_result(result, 16'd15, test_id); test_id = test_id + 1;
        // Input 2: a = 0xFFFF, b = 1 [overflow]
        a = 16'hFFFF; b = 16'd1; alu_control = 3'b000; #10;
        check_result(result, 16'd0, test_id); test_id = test_id + 1;
        // Input 3: a = 0, b = 0
        a = 16'd0; b = 16'd0; alu_control = 3'b000; #10;
        check_result(result, 16'd0, test_id); test_id = test_id + 1;

        $display("--- SUB (alu_control = 3'b001) ---");

        // TODO: Test SUB with at least three pairs.
        //       Include a case where result = 0 to test the zero flag.
        //       Suggested pairs: (10, 5), (7, 7) [result=0], (5, 10) [underflow wrap]

        // Input 1: a = 10, b = 5
        a = 16'd10; b = 16'd5; alu_control = 3'b001; #10;
        check_result(result, 16'd5, test_id); test_id = test_id + 1;
        // Input 2: a = 7, b = 7 [result=0]
        a = 16'd7; b = 16'd7; alu_control = 3'b001; #10;
        check_result(result, 16'd0, test_id); test_id = test_id + 1;
        // Input 3: a = 5, b = 10 [underflow wrap]
        a = 16'd5; b = 16'd10; alu_control = 3'b001; #10;
        check_result(result, 16'd65531, test_id); test_id = test_id + 1;

        $display("--- INV / NOT (alu_control = 3'b010) ---");

        // TODO: Test INV (bitwise NOT, b is ignored) with at least two values.
        //       Suggested values for a: 16'h0000, 16'hFFFF, 16'hA5A5
        // Input 1: a = 16'h0000
        a = 16'h0000;  alu_control = 3'b010; #10;
        check_result(result, 16'hFFFF, test_id); test_id = test_id + 1;
        // Input 2: a = 16'hFFFF
        a = 16'hFFFF;  alu_control = 3'b010; #10;
        check_result(result, 16'h0000, test_id); test_id = test_id + 1;
        // Input 3: a = 16'hA5A5
        a = 16'hA5A5;  alu_control = 3'b010; #10;
        check_result(result, 16'h5A5A, test_id); test_id = test_id + 1;


        $display("--- SHL (alu_control = 3'b011) ---");

        // TODO: Test left shift. Remember only b[3:0] is used as the shift amount.
        //       Suggested pairs (a, b): (16'h0001, 4), (16'h0003, 2), (16'hFFFF, 8)

        // Input 1: a = 16'h0001, b = 16'd4
        a = 16'h0001; b = 16'd4; alu_control = 3'b011; #10;
        check_result(result, 16'h0010, test_id); test_id = test_id + 1;
        // Input 2: a = 16'h0003, b = 16'd2
        a = 16'h0003; b = 16'd2; alu_control = 3'b011; #10;
        check_result(result, 16'h000C, test_id); test_id = test_id + 1;
        // Input 3: a = 16'hFFFF, b = 16'd8
        a = 16'hFFFF; b = 16'd8; alu_control = 3'b011; #10;
        check_result(result, 16'hFF00, test_id); test_id = test_id + 1;

        $display("--- SHR (alu_control = 3'b100) ---");

        // TODO: Test right shift (logical — MSB fills with 0).
        //       Suggested pairs: (16'h0080, 4), (16'hFFFF, 8), (16'h0001, 1)

        // Input 1: a = 16'h0080, b = 16'd4
        a = 16'h0080; b = 16'd4; alu_control = 3'b100; #10;
        check_result(result, 16'h0008, test_id); test_id = test_id + 1;
        // Input 2: a = 16'hFFFF, b = 16'd8
        a = 16'hFFFF; b = 16'd8; alu_control = 3'b100; #10;
        check_result(result, 16'h00FF, test_id); test_id = test_id + 1;
        // Input 3: a = 16'h0001, b = 16'd1
        a = 16'h0001; b = 16'd1; alu_control = 3'b100; #10;
        check_result(result, 16'h0000, test_id); test_id = test_id + 1;

        $display("--- AND (alu_control = 3'b101) ---");

        // TODO: Test bitwise AND.
        //       Suggested pairs: (16'hFFFF, 16'h0F0F), (16'hAAAA, 16'h5555), (0, anything)

        // Input 1: a = 16'hFFFF, b = 16'h0F0F
        a = 16'hFFFF; b = 16'h0F0F; alu_control = 3'b101; #10;
        check_result(result, 16'h0F0F, test_id); test_id = test_id + 1;
        // Input 2: a = 16'hAAAA, b = 16'h5555
        a = 16'hAAAA; b = 16'h5555; alu_control = 3'b101; #10;
        check_result(result, 16'h0000, test_id); test_id = test_id + 1;
        // Input 3: a = 0, b = 16'hBEEF
        a = 16'h0000; b = 16'hBEEF; alu_control = 3'b101; #10;
        check_result(result, 16'h0000, test_id); test_id = test_id + 1;


        $display("--- OR (alu_control = 3'b110) ---");

        // TODO: Test bitwise OR.
        //       Suggested pairs: (16'h0F0F, 16'hF0F0), (16'hAAAA, 16'h5555), (0, 16'hBEEF)

        // Input 1: a = 16'h0F0F, b = 16'hF0F0
        a = 16'h0F0F; b = 16'hF0F0; alu_control = 3'b110; #10;
        check_result(result, 16'hFFFF, test_id); test_id = test_id + 1;
        // Input 2: a = 16'hAAAA, b = 16'h5555
        a = 16'hAAAA; b = 16'h5555; alu_control = 3'b110; #10;
        check_result(result, 16'hFFFF, test_id); test_id = test_id + 1;
        // Input 3: a = 0, b = 16'hBEEF
        a = 16'h0000; b = 16'hBEEF; alu_control = 3'b110; #10;
        check_result(result, 16'hBEEF, test_id); test_id = test_id + 1;


        $display("--- SLT (alu_control = 3'b111) ---");

        // TODO: Test set-less-than. Result must be 1 when a < b (unsigned), 0 otherwise.
        //       Test cases must include: a < b, a == b, a > b.
        //       Suggested pairs: (5, 10) -> 1,  (10, 10) -> 0,  (15, 3) -> 0

        // Input 1: a = 5, b = 10 (a < b)
        a = 16'd5; b = 16'd10; alu_control = 3'b111; #10;
        check_result(result, 16'd1, test_id); test_id = test_id + 1;
        // Input 2: a = 10, b = 10 (a == b)
        a = 16'd10; b = 16'd10; alu_control = 3'b111; #10;
        check_result(result, 16'd0, test_id); test_id = test_id + 1;
        // Input 3: a = 15, b = 3 (a > b)
        a = 16'd15; b = 16'd3; alu_control = 3'b111; #10;
        check_result(result, 16'd0, test_id); test_id = test_id + 1;


        $display("--- Zero flag edge cases ---");

        // TODO: Verify the zero flag is asserted for SUB where a == b.
        //       Verify the zero flag is de-asserted for all non-zero results.
        //       Verify the zero flag for INV of 16'hFFFF (result should be 0).

        // SUB where a == b (zero flag should be 1)
        a = 16'd42; b = 16'd42; alu_control = 3'b001; #10;
        check_zero(zero, 1'b1, test_id); test_id = test_id + 1;
        // Non-zero result (zero flag should be 0)
        a = 16'd100; b = 16'd50; alu_control = 3'b001; #10;
        check_zero(zero, 1'b0, test_id); test_id = test_id + 1;
        // INV of 16'hFFFF (result is 0, zero flag should be 1)
        a = 16'hFFFF; alu_control = 3'b010; #10;
        check_zero(zero, 1'b1, test_id); test_id = test_id + 1;

        // -----------------------------------------------------------------------
        // Summary
        // -----------------------------------------------------------------------
        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d TESTS PASSED ===", test_id - 1);
        else
            $display("=== %0d / %0d TESTS FAILED ===", fail_count, test_id - 1);

        $finish;
    end

endmodule
