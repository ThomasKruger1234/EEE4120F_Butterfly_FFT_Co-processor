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
// File        : TwiddleMemory_tb.v
// Description : Twiddle factor memory testbench for FFT butterfly co-processor.
//               Walks the twiddle-step counter K through all valid addresses and
//               verifies the correct twiddle factor is output combinationally.
//
// Run:
//   cd ../tb
//   iverilog -Wall -I ../src -o ../build/twiddle_sim ../src/TwiddleMemory.v TwiddleMemory_tb.v
//   cd ../test && ../build/twiddle_sim
//   gtkwave waves/twiddle_tb.vcd &
// ===========================================================================

`timescale 1ns / 1ps

module TwiddleMemory_tb;
    // dut inputs and outputs
    reg[7:0] k;
    wire[31:0] twiddle_real;
    wire[31:0] twiddle_imag;

    // instantiate the dut
    TwiddleMemory dut (
        .k(k),
        .twiddle_real(twiddle_real),
        .twiddle_imag(twiddle_imag)
    );

    initial begin
        $dumpfile("waves/twiddle_tb.vcd");
        $dumpvars(0, TwiddleMemory_tb);
    end

    integer failures = 0;   // failure counter
    integer checks = 0;     // check counter
    integer i;

    // reusable check function: set k, wait for outputs to settle, 
    // then compare against expected values
    task check;
        input [7:0]  addr;
        input [31:0] er;
        input [31:0] ei;
        begin
            k = addr; #1;
            if (twiddle_real !== er || twiddle_imag !== ei) begin
                $display("FAIL k=%0d: got (%h,%h), expected (%h,%h)",
                         addr, twiddle_real, twiddle_imag, er, ei);
                failures = failures + 1;
            end else begin
                $display("PASS k=%0d: (%h,%h)", addr, twiddle_real, twiddle_imag);
            end
        end
    endtask
 
    initial begin
        #5;  // let $readmemh complete
 
        // Landmark values: W_N^k = cos(-2*pi*k/256) + j*sin(-2*pi*k/256), Q10.22
        check(8'd0,   32'h00400000, 32'h00000000);  // 1 + 0j
        check(8'd32,  32'h002d413d, 32'hffd2bec3);  // (sqrt(2)/2, -sqrt(2)/2)
        check(8'd64,  32'h00000000, 32'hffc00000);  // 0 - 1j
        check(8'd96,  32'hffd2bec3, 32'hffd2bec3);  // (-sqrt(2)/2, -sqrt(2)/2)
 
        // Wrap-around: k[7] must be ignored (k=128+i should equal k=i)
        check(8'd128, 32'h00400000, 32'h00000000);  // same as k=0
        check(8'd160, 32'h002d413d, 32'hffd2bec3);  // same as k=32
 
        if (failures == 0) $display("\nALL TESTS PASSED");
        else             $display("\n%0d FAILURES", failures);
 
        $finish;
    end

endmodule
