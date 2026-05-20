// =============================================================================
// EEE4120F Practical 4 — StarCore-1 Processor
// File        : DataMemory_tb.v
// Description : Testbench for the Data Memory module (Task 4).
//               Verifies synchronous write, gated combinational read,
//               write followed by immediate read, and disabled-write safety.
//
// Run:
//   iverilog -Wall -I ../src -o ../build/dm_sim ../src/DataMemory.v DataMemory_tb.v
//   cd ../test && ../build/dm_sim
//   gtkwave ../waves/dm_tb.vcd &
// =============================================================================

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module DataMemory_tb;

    reg        clk;
    reg  [15:0] mem_access_addr;
    reg  [15:0] mem_write_data;
    reg        mem_write_en;
    reg        mem_read;
    wire [15:0] mem_read_data;

    DataMemory uut (
        .clk             (clk),
        .mem_access_addr (mem_access_addr),
        .mem_write_data  (mem_write_data),
        .mem_write_en    (mem_write_en),
        .mem_read        (mem_read),
        .mem_read_data   (mem_read_data)
    );

    initial clk = 1'b0;
    always  #5 clk = ~clk;

    initial begin
        $dumpfile("../waves/dm_tb.vcd");
        $dumpvars(0, DataMemory_tb);
    end

    integer fail_count;
    integer test_id;

    initial begin
        fail_count      = 0;
        test_id         = 1;
        mem_write_en    = 1'b0;
        mem_read        = 1'b0;
        mem_access_addr = 16'd0;
        mem_write_data  = 16'd0;

        $display("=== DataMemory Testbench ===");

        // ------------------------------------------------------------------
        // TEST GROUP 1: Read back initial values loaded from test.data
        // ------------------------------------------------------------------
        $display("--- Group 1: Verify $readmemb initialisation ---");

        // TODO: Read each of the 8 memory locations and verify against
        //       the known contents of your test.data file.
        //       Remember: only mem_access_addr[2:0] is used as the index.
        //       Address 16'd0 -> word 0, address 16'd2 -> word 2, etc.
        //       (Or use address 16'd0 -> word 0, address 16'd1 -> word 1,
        //        since only the lower 3 bits matter.)
        //
        //       mem_read = 1'b1;
        //       mem_access_addr = 16'd0; #5;
        //       if (mem_read_data !== 16'h0001)  // expected value from test.data line 0
        //           $display("FAIL [T%0d]: addr=0 got=0x%h exp=0x0001", test_id, mem_read_data);
        //       else
        //           $display("PASS [T%0d]", test_id);
        //       test_id = test_id + 1;
            mem_read = 1'b1;

        mem_access_addr = 16'd0; #5;
        if (mem_read_data !== 16'h0001)
            $display("FAIL [T%0d]: addr=0 got=0x%h exp=0x0001", test_id, mem_read_data);
        else
            $display("PASS [T%0d]", test_id);
        test_id = test_id + 1;

        mem_access_addr = 16'd1; #5;
        if (mem_read_data !== 16'h0002)
            $display("FAIL [T%0d]: addr=1 got=0x%h exp=0x0002", test_id, mem_read_data);
        else
            $display("PASS [T%0d]", test_id);
        test_id = test_id + 1;

        mem_access_addr = 16'd2; #5;
        if (mem_read_data !== 16'h0003)
            $display("FAIL [T%0d]: addr=2 got=0x%h exp=0x0003", test_id, mem_read_data);
        else
            $display("PASS [T%0d]", test_id);
        test_id = test_id + 1;

        mem_access_addr = 16'd3; #5;
        if (mem_read_data !== 16'h0004)
            $display("FAIL [T%0d]: addr=3 got=0x%h exp=0x0004", test_id, mem_read_data);
        else
            $display("PASS [T%0d]", test_id);
        test_id = test_id + 1;

        mem_access_addr = 16'd4; #5;
        if (mem_read_data !== 16'h0005)
            $display("FAIL [T%0d]: addr=4 got=0x%h exp=0x0005", test_id, mem_read_data);
        else
            $display("PASS [T%0d]", test_id);
        test_id = test_id + 1;

        mem_access_addr = 16'd5; #5;
        if (mem_read_data !== 16'h0006)
            $display("FAIL [T%0d]: addr=5 got=0x%h exp=0x0006", test_id, mem_read_data);
        else
            $display("PASS [T%0d]", test_id);
        test_id = test_id + 1;

        mem_access_addr = 16'd6; #5;
        if (mem_read_data !== 16'h0007)
            $display("FAIL [T%0d]: addr=6 got=0x%h exp=0x0007", test_id, mem_read_data);
        else
            $display("PASS [T%0d]", test_id);
        test_id = test_id + 1;

        mem_access_addr = 16'd7; #5;
        if (mem_read_data !== 16'h0008)
            $display("FAIL [T%0d]: addr=7 got=0x%h exp=0x0008", test_id, mem_read_data);
        else
            $display("PASS [T%0d]", test_id);
        test_id = test_id + 1;

        mem_read = 1'b0;


        // ------------------------------------------------------------------
        // TEST GROUP 2: Write new values to all 8 locations, then read back
        // ------------------------------------------------------------------
        $display("--- Group 2: Write then read all 8 locations ---");

        // TODO: Write a distinct value to each of the 8 addresses using
        //       mem_write_en and posedge clk, then read each back.
        //
        //       // Write to address 0
        //       mem_write_en    = 1'b1;
        //       mem_access_addr = 16'd0;
        //       mem_write_data  = 16'hABCD;
        //       @(posedge clk); #1;
        //       mem_write_en    = 1'b0;
        //
        //       // Read back from address 0
        //       mem_read = 1'b1;
        //       mem_access_addr = 16'd0; #5;
        //       if (mem_read_data !== 16'hABCD) ...
        //       test_id = test_id + 1;

        // Write and read back address 0
        mem_write_en    = 1'b1;
        mem_access_addr = 16'd0;
        mem_write_data  = 16'hA000;
        @(posedge clk); #1;
        mem_write_en    = 1'b0;

        mem_read = 1'b1;
        mem_access_addr = 16'd0; #5;
        if (mem_read_data !== 16'hA000)
            $display("FAIL [T%0d]: addr=0 got=0x%h exp=0xA000", test_id, mem_read_data);
        else
            $display("PASS [T%0d]", test_id);
        test_id = test_id + 1;
        mem_read = 1'b0;

        // Write and read back address 1
        mem_write_en    = 1'b1;
        mem_access_addr = 16'd1;
        mem_write_data  = 16'hB001;
        @(posedge clk); #1;
        mem_write_en    = 1'b0;

        mem_read = 1'b1;
        mem_access_addr = 16'd1; #5;
        if (mem_read_data !== 16'hB001)
            $display("FAIL [T%0d]: addr=1 got=0x%h exp=0xB001", test_id, mem_read_data);
        else
            $display("PASS [T%0d]", test_id);
        test_id = test_id + 1;
        mem_read = 1'b0;

        // Write and read back address 2
        mem_write_en    = 1'b1;
        mem_access_addr = 16'd2;
        mem_write_data  = 16'hC002;
        @(posedge clk); #1;
        mem_write_en    = 1'b0;

        mem_read = 1'b1;
        mem_access_addr = 16'd2; #5;
        if (mem_read_data !== 16'hC002)
            $display("FAIL [T%0d]: addr=2 got=0x%h exp=0xC002", test_id, mem_read_data);
        else
            $display("PASS [T%0d]", test_id);
        test_id = test_id + 1;
        mem_read = 1'b0;

        // Write and read back address 3
        mem_write_en    = 1'b1;
        mem_access_addr = 16'd3;
        mem_write_data  = 16'hD003;
        @(posedge clk); #1;
        mem_write_en    = 1'b0;

        mem_read = 1'b1;
        mem_access_addr = 16'd3; #5;
        if (mem_read_data !== 16'hD003)
            $display("FAIL [T%0d]: addr=3 got=0x%h exp=0xD003", test_id, mem_read_data);
        else
            $display("PASS [T%0d]", test_id);
        test_id = test_id + 1;
        mem_read = 1'b0;

        // Write and read back address 4
        mem_write_en    = 1'b1;
        mem_access_addr = 16'd4;
        mem_write_data  = 16'hE004;
        @(posedge clk); #1;
        mem_write_en    = 1'b0;

        mem_read = 1'b1;
        mem_access_addr = 16'd4; #5;
        if (mem_read_data !== 16'hE004)
            $display("FAIL [T%0d]: addr=4 got=0x%h exp=0xE004", test_id, mem_read_data);
        else
            $display("PASS [T%0d]", test_id);
        test_id = test_id + 1;
        mem_read = 1'b0;

        // Write and read back address 5
        mem_write_en    = 1'b1;
        mem_access_addr = 16'd5;
        mem_write_data  = 16'hF005;
        @(posedge clk); #1;
        mem_write_en    = 1'b0;

        mem_read = 1'b1;
        mem_access_addr = 16'd5; #5;
        if (mem_read_data !== 16'hF005)
            $display("FAIL [T%0d]: addr=5 got=0x%h exp=0xF005", test_id, mem_read_data);
        else
            $display("PASS [T%0d]", test_id);
        test_id = test_id + 1;
        mem_read = 1'b0;

        // Write and read back address 6
        mem_write_en    = 1'b1;
        mem_access_addr = 16'd6;
        mem_write_data  = 16'h1006;
        @(posedge clk); #1;
        mem_write_en    = 1'b0;

        mem_read = 1'b1;
        mem_access_addr = 16'd6; #5;
        if (mem_read_data !== 16'h1006)
            $display("FAIL [T%0d]: addr=6 got=0x%h exp=0x1006", test_id, mem_read_data);
        else
            $display("PASS [T%0d]", test_id);
        test_id = test_id + 1;
        mem_read = 1'b0;

        // Write and read back address 7
        mem_write_en    = 1'b1;
        mem_access_addr = 16'd7;
        mem_write_data  = 16'h2007;
        @(posedge clk); #1;
        mem_write_en    = 1'b0;

        mem_read = 1'b1;
        mem_access_addr = 16'd7; #5;
        if (mem_read_data !== 16'h2007)
            $display("FAIL [T%0d]: addr=7 got=0x%h exp=0x2007", test_id, mem_read_data);
        else
            $display("PASS [T%0d]", test_id);
        test_id = test_id + 1;
        mem_read = 1'b0;

        // ------------------------------------------------------------------
        // TEST GROUP 3: mem_read = 0 must produce 16'd0 output
        // ------------------------------------------------------------------
        $display("--- Group 3: mem_read disabled -> output must be 0 ---");

        // TODO: De-assert mem_read and verify the output is 16'd0 regardless
        //       of the address.
        //
        //       mem_read = 1'b0;
        //       mem_access_addr = 16'd0; #5;
        //       if (mem_read_data !== 16'd0)
        //           $display("FAIL [T%0d]: mem_read=0 but output=%h", test_id, mem_read_data);
        //       else
        //           $display("PASS [T%0d]: output = 0 when mem_read=0", test_id);
        //       test_id = test_id + 1;
        mem_read = 1'b0;

        mem_access_addr = 16'd0; #5;
        if (mem_read_data !== 16'd0)
            $display("FAIL [T%0d]: mem_read=0 addr=0 but output=0x%h", test_id, mem_read_data);
        else
            $display("PASS [T%0d]: output = 0 when mem_read=0", test_id);
        test_id = test_id + 1;

        mem_access_addr = 16'd1; #5;
        if (mem_read_data !== 16'd0)
            $display("FAIL [T%0d]: mem_read=0 addr=1 but output=0x%h", test_id, mem_read_data);
        else
            $display("PASS [T%0d]: output = 0 when mem_read=0", test_id);
        test_id = test_id + 1;

        mem_access_addr = 16'd2; #5;
        if (mem_read_data !== 16'd0)
            $display("FAIL [T%0d]: mem_read=0 addr=2 but output=0x%h", test_id, mem_read_data);
        else
            $display("PASS [T%0d]: output = 0 when mem_read=0", test_id);
        test_id = test_id + 1;

        mem_access_addr = 16'd3; #5;
        if (mem_read_data !== 16'd0)
            $display("FAIL [T%0d]: mem_read=0 addr=3 but output=0x%h", test_id, mem_read_data);
        else
            $display("PASS [T%0d]: output = 0 when mem_read=0", test_id);
        test_id = test_id + 1;

        mem_access_addr = 16'd4; #5;
        if (mem_read_data !== 16'd0)
            $display("FAIL [T%0d]: mem_read=0 addr=4 but output=0x%h", test_id, mem_read_data);
        else
            $display("PASS [T%0d]: output = 0 when mem_read=0", test_id);
        test_id = test_id + 1;

        mem_access_addr = 16'd5; #5;
        if (mem_read_data !== 16'd0)
            $display("FAIL [T%0d]: mem_read=0 addr=5 but output=0x%h", test_id, mem_read_data);
        else
            $display("PASS [T%0d]: output = 0 when mem_read=0", test_id);
        test_id = test_id + 1;

        mem_access_addr = 16'd6; #5;
        if (mem_read_data !== 16'd0)
            $display("FAIL [T%0d]: mem_read=0 addr=6 but output=0x%h", test_id, mem_read_data);
        else
            $display("PASS [T%0d]: output = 0 when mem_read=0", test_id);
        test_id = test_id + 1;

        mem_access_addr = 16'd7; #5;
        if (mem_read_data !== 16'd0)
            $display("FAIL [T%0d]: mem_read=0 addr=7 but output=0x%h", test_id, mem_read_data);
        else
            $display("PASS [T%0d]: output = 0 when mem_read=0", test_id);
        test_id = test_id + 1;

        // ------------------------------------------------------------------
        // TEST GROUP 4: Write then immediately read on the next cycle
        // ------------------------------------------------------------------
        $display("--- Group 4: Write followed by immediate read ---");

        // TODO: Write to address 3, then on the very next cycle read back
        //       from address 3 and confirm the new value is returned.

        // Write to address 3
            mem_write_en    = 1'b1;
            mem_access_addr = 16'd3;
            mem_write_data  = 16'hBEEF;
            @(posedge clk); #1;
            mem_write_en    = 1'b0;

            // Immediately read back on the very next cycle
            mem_read        = 1'b1;
            mem_access_addr = 16'd3; #5;
            if (mem_read_data !== 16'hBEEF)
                $display("FAIL [T%0d]: immediate read after write got=0x%h exp=0xBEEF", test_id, mem_read_data);
            else
                $display("PASS [T%0d]: immediate read after write correct", test_id);
            test_id = test_id + 1;
            mem_read = 1'b0;

        // ------------------------------------------------------------------
        // TEST GROUP 5: Disabled write must not alter memory
        // ------------------------------------------------------------------
        $display("--- Group 5: mem_write_en=0 must not overwrite memory ---");

        // Attempt to overwrite address 3 with write enable deasserted
        mem_write_en    = 1'b0;
        mem_access_addr = 16'd3;
        mem_write_data  = 16'hDEAD;    // this value must NOT be written
        @(posedge clk); #1;

        // Read back and confirm 0xBEEF from Group 4 is still there
        mem_read        = 1'b1;
        mem_access_addr = 16'd3; #5;
        if (mem_read_data !== 16'hBEEF)
            $display("FAIL [T%0d]: disabled write corrupted memory got=0x%h exp=0xBEEF", test_id, mem_read_data);
        else
            $display("PASS [T%0d]: disabled write did not alter memory", test_id);
        test_id = test_id + 1;
        mem_read = 1'b0;

        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d TESTS PASSED ===", test_id - 1);
        else
            $display("=== %0d / %0d TESTS FAILED ===", fail_count, test_id - 1);
        $finish;
    end

endmodule
