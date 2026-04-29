# =============================================================================
# EEE4120F Practical 4 — StarCore-1 Processor
# Makefile — automates compilation and simulation of all modules
#
# Usage:
#   make alu          — compile and simulate the ALU testbench
#   make gpr          — compile and simulate the GPR testbench
#   make imem         — compile and simulate InstructionMemory testbench
#   make dmem         — compile and simulate DataMemory testbench
#   make aluctrl      — compile and simulate ALU_Control testbench
#   make ctrl         — compile and simulate ControlUnit testbench
#   make integration  — compile and simulate the full processor
#   make all          — run all testbenches in order
#   make waves        — open the last integration waveform in GTKWave
#   make clean        — remove all compiled outputs and waveform files
#
# IMPORTANT: Makefile recipe lines must start with a TAB character, not spaces.
# =============================================================================

IVFLAGS = -Wall -I src/

# All design source files (included in every compilation)
SRC = src/Parameter.v \
      src/ALU.v \
      src/GPR.v \
      src/InstructionMemory.v \
      src/DataMemory.v \
      src/ALU_Control.v \
      src/ControlUnit.v \
      src/Datapath.v \
      src/StarCore1.v

.PHONY: all alu gpr imem dmem aluctrl ctrl integration waves clean

# ---------------------------------------------------------------------------
# all — run every testbench
# ---------------------------------------------------------------------------
all: alu gpr imem dmem aluctrl ctrl integration

# ---------------------------------------------------------------------------
# Task 1: ALU
# ---------------------------------------------------------------------------
alu: build/alu_sim
	@echo "--- Running ALU testbench ---"
	cd test && ../build/alu_sim

build/alu_sim: src/ALU.v tb/ALU_tb.v | build
	iverilog $(IVFLAGS) -o build/alu_sim src/ALU.v tb/ALU_tb.v

# ---------------------------------------------------------------------------
# Task 2: General Purpose Register File
# ---------------------------------------------------------------------------
gpr: build/gpr_sim
	@echo "--- Running GPR testbench ---"
	cd test && ../build/gpr_sim

build/gpr_sim: src/GPR.v tb/GPR_tb.v | build
	iverilog $(IVFLAGS) -o build/gpr_sim src/GPR.v tb/GPR_tb.v

# ---------------------------------------------------------------------------
# Task 3: Instruction Memory
# ---------------------------------------------------------------------------
imem: build/im_sim
	@echo "--- Running InstructionMemory testbench ---"
	cd test && ../build/im_sim

build/im_sim: src/InstructionMemory.v tb/InstructionMemory_tb.v | build
	iverilog $(IVFLAGS) -o build/im_sim \
		src/Parameter.v src/InstructionMemory.v tb/InstructionMemory_tb.v

# ---------------------------------------------------------------------------
# Task 4: Data Memory
# ---------------------------------------------------------------------------
dmem: build/dm_sim
	@echo "--- Running DataMemory testbench ---"
	cd test && ../build/dm_sim

build/dm_sim: src/DataMemory.v tb/DataMemory_tb.v | build
	iverilog $(IVFLAGS) -o build/dm_sim \
		src/Parameter.v src/DataMemory.v tb/DataMemory_tb.v

# ---------------------------------------------------------------------------
# Task 5: ALU Control Unit
# ---------------------------------------------------------------------------
aluctrl: build/ac_sim
	@echo "--- Running ALU_Control testbench ---"
	cd test && ../build/ac_sim

build/ac_sim: src/ALU_Control.v tb/ALU_Control_tb.v | build
	iverilog $(IVFLAGS) -o build/ac_sim \
		src/Parameter.v src/ALU_Control.v tb/ALU_Control_tb.v

# ---------------------------------------------------------------------------
# Task 6: Main Control Unit
# ---------------------------------------------------------------------------
ctrl: build/cu_sim
	@echo "--- Running ControlUnit testbench ---"
	cd test && ../build/cu_sim

build/cu_sim: src/ControlUnit.v tb/ControlUnit_tb.v | build
	iverilog $(IVFLAGS) -o build/cu_sim \
		src/Parameter.v src/ControlUnit.v tb/ControlUnit_tb.v

# ---------------------------------------------------------------------------
# Tasks 7 & 8: Full Processor Integration
# ---------------------------------------------------------------------------
integration: build/star_sim
	@echo "--- Running StarCore-1 integration testbench ---"
	cd test && ../build/star_sim

build/star_sim: $(SRC) tb/StarCore1_tb.v | build
	iverilog $(IVFLAGS) -o build/star_sim $(SRC) tb/StarCore1_tb.v

# ---------------------------------------------------------------------------
# Open the integration waveform in GTKWave
# ---------------------------------------------------------------------------
waves:
	gtkwave waves/star.vcd &

# ---------------------------------------------------------------------------
# Create build directory if it does not exist
# ---------------------------------------------------------------------------
build:
	mkdir -p build waves

# ---------------------------------------------------------------------------
# Remove all generated files
# ---------------------------------------------------------------------------
clean:
	rm -f build/*
	rm -f waves/*.vcd
	rm -f test/*.vcd
	@echo "Clean complete."
