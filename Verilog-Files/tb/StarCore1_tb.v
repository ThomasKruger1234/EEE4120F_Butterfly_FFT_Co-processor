// =============================================================================
// EEE4120F Practical 4 — StarCore-1 Processor
// File        : StarCore1_tb.v
// Description : Integration testbench for the full StarCore-1 processor (Task 8).
//               Runs the program stored in test.prog and verifies processor
//               behaviour over multiple clock cycles using hierarchical signal
//               references.
//
//               This testbench does NOT drive the processor's datapath signals
//               directly — it only drives the clock and observes internal state
//               via hierarchical references.
//
// *** IMPORTANT — Expected compile behaviour with the skeleton ***
// When you first compile this testbench against the skeleton source files,
// iverilog will report "Unable to bind wire/reg/memory" errors for every
// hierarchical reference below (uut.DU.pc_current, uut.DU.instr, etc.).
// This is EXPECTED. Those signals do not yet exist because the Datapath
// module body is empty. The errors will disappear once you implement the
// internal signal declarations and sub-module instantiations in Datapath.v
// and StarCore1.v as required by Tasks 7 and 8.
//
// Hierarchical signal reference examples (valid after implementation):
//   uut.DU.pc_current              — Program Counter (reg in Datapath)
//   uut.DU.instr                   — Currently fetched instruction word (wire)
//   uut.DU.alu_result              — ALU output (wire)
//   uut.DU.zero_flag               — ALU zero flag (wire)
//   uut.DU.reg_file.reg_array[N]   — Register RN value (inside GPR instance)
//   uut.DU.dm.memory[N]            — Data memory word N (inside DataMemory instance)
//   uut.CU.reg_write               — ControlUnit reg_write output
//   uut.CU.alu_op                  — ControlUnit alu_op output
//
// The instance names used here (DU for Datapath, CU for ControlUnit, reg_file
// for GPR, dm for DataMemory) MUST match the names you use when instantiating
// those modules in StarCore1.v and Datapath.v respectively.
//
// Run:
//   iverilog -Wall -I ../src -o ../build/star_sim \
//       ../src/Parameter.v ../src/ALU.v ../src/GPR.v \
//       ../src/InstructionMemory.v ../src/DataMemory.v \
//       ../src/ALU_Control.v ../src/ControlUnit.v \
//       ../src/Datapath.v ../src/StarCore1.v StarCore1_tb.v
//   cd ../test && ../build/star_sim
//   gtkwave ../waves/star.vcd &
// =============================================================================

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module StarCore1_tb;

    // -------------------------------------------------------------------------
    // Clock
    // -------------------------------------------------------------------------
    reg clk;
    initial clk = 1'b0;
    always  #5 clk = ~clk;     // 10 ns period — 100 MHz

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    StarCore1 uut (.clk(clk));

    // -------------------------------------------------------------------------
    // Waveform dump — captures ALL signals in the design hierarchy
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("../waves/star.vcd");
        $dumpvars(0, StarCore1_tb);
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
    // Check tasks — compare 16-bit values observed via hierarchical reference
    // -------------------------------------------------------------------------
    task check16;
        input [15:0] got;
        input [15:0] expected;
        input [63:0] id;
        begin
            if (got !== expected) begin
                $display("FAIL [T%0d]: got = 0x%h (%0d), expected = 0x%h (%0d)",
                         id, got, got, expected, expected);
                fail_count = fail_count + 1;
            end else
                $display("PASS [T%0d]: value = 0x%h (%0d)", id, got, got);
        end
    endtask

    // -------------------------------------------------------------------------
    // Cycle-by-cycle execution trace
    // This always block fires on every rising clock edge and prints the current
    // processor state. It is your primary debugging tool.
    //
    // TODO: Uncomment this block once Datapath.v is fully implemented.
    //       Until then, it will cause "Unable to bind" errors because the
    //       internal signals (pc_current, instr, etc.) do not yet exist.
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        $display("%0t ns | PC=0x%h | instr=%b | R0=%3d R1=%3d R2=%3d R3=%3d | alu=%0d z=%b",
            $time,
            uut.DU.pc_current,
            uut.DU.instr,
            uut.DU.reg_file.reg_array[0],
            uut.DU.reg_file.reg_array[1],
            uut.DU.reg_file.reg_array[2],
            uut.DU.reg_file.reg_array[3],
            uut.DU.alu_result,
            uut.DU.zero_flag
         );
    end
    //
    // PLACEHOLDER — prints time only until you uncomment the full trace above.
    // always @(posedge clk) begin
    //     $display("%0t ns | clock tick (uncomment trace block when Datapath is implemented)",
    //              $time);
    // end

    // =========================================================================
    // MAIN STIMULUS BLOCK
    // =========================================================================
    initial begin
        $display("=== StarCore-1 Integration Testbench ===");
        $display("=== Program loaded from ./test/test.prog ===");
        $display("=== Data memory loaded from ./test/test.data ===");
        $display("");

        // -----------------------------------------------------------------------
        // Wait for the simulation to run long enough for your program to
        // complete at least one full pass. Adjust SIM_TIME in Parameter.v
        // if your program needs more cycles.
        // -----------------------------------------------------------------------
        `SIM_TIME;

        // -----------------------------------------------------------------------
        // POST-SIMULATION VERIFICATION
        //
        // The test program (test.prog) exercises every opcode in the StarCore ISA
        // plus the reserved 1010. Expected final state at end of simulation:
        //
        //   R1 = 0x0001  (LD from Mem[0])
        //   R2 = 0x0002  (LD from Mem[1])
        //   R3 = 0x0004  (SHL overwrites ADD=3)
        //   R4 = 0xFFFE  (INV overwrites SUB=1)
        //   R5 = 0x0000  (AND)
        //   R6 = 0x0001  (SHR overwrites OR=3)
        //   R7 = 0x0001  (SLT)
        //
        //   Mem[2] = 0x0003  (ST at W3)
        //   Mem[3] = 0x0004  (unchanged from test.data - proves branch canary skipped)
        // -----------------------------------------------------------------------

        $display("");
        $display("--- Post-Simulation Verification ---");

        // -----------------------------------------------------------------------
        // STEP 1: Verify load instructions (LD).
        // W0 loads Mem[0]=1 into R1; W1 loads Mem[1]=2 into R2.
        // -----------------------------------------------------------------------
        $display("Checking R1 after LD R1,0(R0) (expect Mem[0] = 0x0001):");
        check16(uut.DU.reg_file.reg_array[1], 16'h0001, test_id);
        test_id = test_id + 1;

        $display("Checking R2 after LD R2,1(R0) (expect Mem[1] = 0x0002):");
        check16(uut.DU.reg_file.reg_array[2], 16'h0002, test_id);
        test_id = test_id + 1;

        // -----------------------------------------------------------------------
        // STEP 2: Verify store instruction (ST).
        // W3: ST R3, 2(R0) writes R3 (which holds ADD result = 3) to Mem[2].
        // -----------------------------------------------------------------------
        $display("Checking Mem[2] after ST R3,2(R0) (expect 0x0003):");
        check16(uut.DU.dm.memory[2], 16'h0003, test_id);
        test_id = test_id + 1;

        // -----------------------------------------------------------------------
        // STEP 3: Verify R-type arithmetic (ADD, SUB).
        // ADD writes 3 to R3 at W2, but SHL at W8 later overwrites R3 with 4.
        // SUB writes 1 to R4 at W4, but INV at W10 later overwrites R4.
        // So we verify these via the ST (for ADD) and via waveform trace (for SUB).
        // The ST check above already confirmed ADD produced 3. For SUB, we rely
        // on the waveform/trace showing alu=1 at PC=0x08.
        // -----------------------------------------------------------------------
        $display("R-type verification (ADD implicitly verified by ST check above)");

        // -----------------------------------------------------------------------
        // STEP 4: Verify logical operations (AND, OR, SLT).
        // AND result is preserved in R5 (not overwritten later).
        // OR result is overwritten by SHR; rely on waveform trace at PC=0x0C.
        // SLT result is preserved in R7.
        // -----------------------------------------------------------------------
        $display("Checking R5 after AND R5,R1,R2 (expect 1 & 2 = 0x0000):");
        check16(uut.DU.reg_file.reg_array[5], 16'h0000, test_id);
        test_id = test_id + 1;

        $display("Checking R7 after SLT R7,R1,R2 (expect 1<2 = 0x0001):");
        check16(uut.DU.reg_file.reg_array[7], 16'h0001, test_id);
        test_id = test_id + 1;

        // -----------------------------------------------------------------------
        // STEP 5: Verify shift operations (SHL, SHR) and INV.
        // These overwrite earlier arithmetic results — their values are the
        // definitive final values for R3, R6, R4.
        // -----------------------------------------------------------------------
        $display("Checking R3 after SHL R3,R2,R1 (expect 2<<1 = 0x0004):");
        check16(uut.DU.reg_file.reg_array[3], 16'h0004, test_id);
        test_id = test_id + 1;

        $display("Checking R6 after SHR R6,R2,R1 (expect 2>>1 = 0x0001):");
        check16(uut.DU.reg_file.reg_array[6], 16'h0001, test_id);
        test_id = test_id + 1;

        $display("Checking R4 after INV R4,R1 (expect ~0x0001 = 0xFFFE):");
        check16(uut.DU.reg_file.reg_array[4], 16'hFFFE, test_id);
        test_id = test_id + 1;

        // -----------------------------------------------------------------------
        // STEP 6: Verify branches (BEQ not-taken, BNE taken).
        // W11: BEQ R1,R2,+1 -> 1==2 is false, NOT taken, falls through to W12.
        // W12: BNE R1,R2,+1 -> 1!=2 is true, TAKEN, skips W13.
        // W13 is a canary: ST R7,3(R0). If either branch malfunctioned, this
        // store would run and corrupt Mem[3] (writing 1 over the original 4).
        // Mem[3] unchanged = both BEQ-not-taken AND BNE-taken worked correctly.
        // -----------------------------------------------------------------------
        $display("Checking Mem[3] unchanged (expect 0x0004 from test.data):");
        $display("  -- if BEQ incorrectly branched OR BNE failed to branch, Mem[3] would be 0x0001");
        check16(uut.DU.dm.memory[3], 16'h0004, test_id);
        test_id = test_id + 1;

        // -----------------------------------------------------------------------
        // STEP 7: Verify JMP and reserved opcode (1010).
        // W14: JMP 15 -> target = 0x001E = W15, which holds the reserved opcode.
        // The reserved opcode must execute as a no-op (no register or memory
        // side effects). If JMP failed, PC would continue to 0x1E anyway via
        // sequential flow, so JMP correctness is inferred indirectly: the
        // waveform trace should show PC jump from 0x1C directly to 0x1E, and
        // all register values above remain at their expected final state.
        //
        // The reserved opcode itself is verified by the fact that every
        // register check above still passes after it has been executed.
        // -----------------------------------------------------------------------
        $display("JMP + reserved opcode verification:");
        $display("  -- verified indirectly: all register checks above pass after RSVD executes");
        $display("  -- inspect waveform to confirm PC jumps from 0x001C directly to 0x001E");


        // -----------------------------------------------------------------------
        // Print register and memory state (safe to uncomment after Task 7)
        // -----------------------------------------------------------------------
        $display("");
        $display("--- Final Register File State ---");
        $display("R0=0x%h  R1=0x%h  R2=0x%h  R3=0x%h",
            uut.DU.reg_file.reg_array[0], uut.DU.reg_file.reg_array[1],
            uut.DU.reg_file.reg_array[2], uut.DU.reg_file.reg_array[3]);
        $display("R4=0x%h  R5=0x%h  R6=0x%h  R7=0x%h",
            uut.DU.reg_file.reg_array[4], uut.DU.reg_file.reg_array[5],
            uut.DU.reg_file.reg_array[6], uut.DU.reg_file.reg_array[7]);
        
        $display("");
        $display("--- Final Data Memory State ---");
        $display("Mem[0]=0x%h  Mem[1]=0x%h  Mem[2]=0x%h  Mem[3]=0x%h",
            uut.DU.dm.memory[0], uut.DU.dm.memory[1],
            uut.DU.dm.memory[2], uut.DU.dm.memory[3]);
        $display("Mem[4]=0x%h  Mem[5]=0x%h  Mem[6]=0x%h  Mem[7]=0x%h",
            uut.DU.dm.memory[4], uut.DU.dm.memory[5],
            uut.DU.dm.memory[6], uut.DU.dm.memory[7]);

        // -----------------------------------------------------------------------
        // Summary
        // -----------------------------------------------------------------------
        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d INTEGRATION TESTS PASSED ===", test_id - 1);
        else
            $display("=== %0d / %0d INTEGRATION TESTS FAILED ===", fail_count, test_id - 1);

        $finish;
    end

endmodule
