# SoC integration: StarCore1 ⇆ FFT_Coprocessor

## Context

`StarCore1.v` (single-cycle CPU under [Verilog-Files/src/](../EEE4120F_Butterfly_FFT_Co-processor/Verilog-Files/src/)) and `FFT_Coprocessor.v` (256-point radix-2 DIT FFT under [Co-processor/src/](../EEE4120F_Butterfly_FFT_Co-processor/Co-processor/src/)) currently work in isolation. The README promises they will communicate via a "shared memory-mapped area," but no such area exists yet in RTL.

This plan adds the integration with three principles in mind:

1. **The FFT's `rf[]` is the shared memory.** Whoever runs a simulation supplies the 256 time-series samples in natural order, either via `$readmemb` into `rf[]` or via a testbench hierarchical preload — the same pattern the existing [FFT_Coprocessor_tb.v:79-87](../EEE4120F_Butterfly_FFT_Co-processor/Co-processor/tb/FFT_Coprocessor_tb.v#L79-L87) uses today, just without the `bitrev8()` call on the load side. No separate input memory module.
2. **Bit reversal happens in hardware**, as a 256-cycle in-place pre-stage. For each `i ∈ 0..255`, if `bitrev8(i) > i`, the SoC swaps `rf[i] ↔ rf[bitrev8(i)]` in one clock per pair using ButterflyMemory's existing dual-port write.
3. **A new custom opcode `4'b1010` (FFT_RUN)** — currently the documented no-op slot in `ControlUnit.v` — fires the whole sequence atomically: SWAP → FFT compute → done. The CPU's PC freezes for ≈ 1282 cycles, then resumes on the next instruction.

DataMemory stays inside Datapath, so StarCore1 still acts as a self-contained CPU for its existing tests (a one-line update to `StarCore1_tb` to tie new inputs to safe defaults is all that's needed for the legacy TB to keep passing). The CPU also gets a small MMIO surface — a read-only window into `rf[]` (any 16-bit lane of any sample) plus a STATUS register reporting `fft_done` — so a future program can inspect FFT results without leaving the CPU's normal load semantics.

## Background: lanes

Each `rf[i]` is one complex sample, 64 bits wide:

```
rf[i] = | bits [63:48] | bits [47:32] | bits [31:16] | bits [15:0]  |
        |  R_hi        |  R_lo        |  I_hi        |  I_lo        |
        |  real upper  |  real lower  |  imag upper  |  imag lower  |
        (signed Q10.22 real)           (signed Q10.22 imag)
```

The CPU's data bus is 16 bits, so reading a full complex sample takes 4 LDs (one per lane). Lanes appear only on the MMIO read-window side. The SoC's internal bit-reversal swap moves whole 64-bit words.

## In-place bit-reversal using ButterflyMemory's existing dual-port write

ButterflyMemory's existing write always-block ([ButterflyMemory.v:30-35](../EEE4120F_Butterfly_FFT_Co-processor/Co-processor/src/ButterflyMemory.v#L30-L35)) commits `rf[addr_a]` and `rf[addr_b]` in a single clock when `we=1`. Verilog non-blocking semantics evaluate the RHS at the start of the timestep and assign at the end, so on the same edge we can read the old `rf[addr_b]` and write it into `rf[addr_a]` (and vice versa). One-cycle in-place swap, no temporary register.

A small mux added inside ButterflyMemory lets the SoC drive the swap:

```verilog
// Inside ButterflyMemory.v:
wire [7:0]  eff_addr_a = ext_active ? ext_addr_a : addr_a;
wire [7:0]  eff_addr_b = ext_active ? ext_addr_b : addr_b;
wire        eff_we     = ext_active ? ext_we     : we;
wire [63:0] eff_din_a  = ext_active ? rf[eff_addr_b]                   // swap source
                                    : {din_a_real, din_a_imag};
wire [63:0] eff_din_b  = ext_active ? rf[eff_addr_a]                   // swap source
                                    : {din_b_real, din_b_imag};

always @(posedge clk) begin
    if (eff_we) begin
        rf[eff_addr_a] <= eff_din_a;
        rf[eff_addr_b] <= eff_din_b;
    end
end
```

When `ext_active=0`, behaviour is identical to today. When `ext_active=1`, the SoC drives the address pair and `we`, and the data path is hard-wired to "swap whatever's at those two addresses." There is no `ext_din` write port — the swap source is always `rf[]` itself.

The SoC iterates `swap_idx` from 0 to 255, sets `ext_addr_a = swap_idx`, `ext_addr_b = bitrev8(swap_idx)`, and asserts `ext_we` only when `bitrev8(swap_idx) > swap_idx`. Each pair gets swapped exactly once; fixed points are no-ops.

## Architecture

```
        ┌──────────────── SoC.v ──────────────────────────────────┐
        │                                                          │
        │   ┌─── StarCore1 ────┐                                   │
        │   │ ┌─ Datapath ─┐   │   mem_access_addr[15:0]           │
clk ────┤──►│ │   ...      │   ├──► address decode ─┬─► DataMemory │
        │   │ │  DataMem*  │◄──┤  (read mux back)   └─► MMIO read  │
        │   │ └────────────┘   │                                   │
        │   │  ControlUnit ───►│ fft_run                           │
        │   └──────────────────┘                                   │
        │            ▲                                             │
        │            │ stall = fft_run & ~fft_done                 │
        │   fft_done │                                             │
        │            │   ┌── 4-state FSM ──────────┐               │
        │            │   │  IDLE → SWAP (256 cyc)  │               │
        │            │   │       → RUN  (~1024 cyc)│               │
        │            │   │       → DONE            │               │
        │            │   └─┬───────────────────────┘               │
        │            │     │ ext_active / ext_addr_a /              │
        │            │     │ ext_addr_b / ext_we                    │
        │            │     ▼                                        │
        │            │   ┌── FFT_Coprocessor ──┐                   │
        │            └───┤ done                │                   │
        │   fft_rst ────►│ rst                 │   ext_raddr ──┐   │
        │  (FSM-driven)  │   ButterflyMemory   │◄── for read   │   │
        │                │   (preloaded rf[])  │── ext_rdout──►│   │
        │                └─────────────────────┘               │   │
        │                                                MMIO read │
        └──────────────────────────────────────────────────────────┘

  *DataMemory stays inside Datapath so existing uut.DU.dm.memory[N]
   hierarchical refs in StarCore1_tb continue to resolve.
```

### MMIO address map

Decoded on `mem_access_addr[15:14]`:

| `addr[15:14]` | Region              | Sub-decode                                                                | Notes              |
|---------------|---------------------|---------------------------------------------------------------------------|--------------------|
| `00`          | DataMemory          | `addr[2:0]` (existing)                                                    | unchanged          |
| `10`          | rf[] read window    | `addr[10:3]` = sample idx (0..255), `addr[2:1]` = lane                    | `0x8000–0x83FE`, read-only |
| `11`          | STATUS              | returns `{15'd0, fft_done}`                                               | `0xC000`, read-only |

Lane encoding: `00=R_hi, 01=R_lo, 10=I_hi, 11=I_lo` (matches `rf[i]` slice ordering above).

All "reserved" bits within each MMIO region are don't-cares in hardware decode; document them as reserved-zero by convention. Writes to MMIO are ignored.

### How the MMIO routing works (in plain terms)

The CPU's LD/ST puts a 16-bit address (`alu_result`) on the bus and the SoC's address decode looks at the top bit:

- **`addr[15]=0` → DataMemory.** Behaviour is unchanged from the standalone CPU. DataMemory reads/writes its 8-word array and the result flows back to the Datapath writeback mux exactly as it does today.
- **`addr[15]=1` → FFT MMIO.** The SoC's decode picks `rf[]` read window vs STATUS (using `addr[14]`), fetches the value, and feeds it back to Datapath as `mmio_read_data`.

The only Datapath change for the read path is one extra mux layer on the writeback. Instead of `mem_to_reg ? mem_read_data : alu_result`, it becomes:

```
reg_write_data = mem_to_reg
               ? (mmio_read_sel ? mmio_read_data : mem_read_data)
               : alu_result
```

where `mmio_read_sel = mem_access_addr[15]` is driven from the SoC.

For writes, MMIO is read-only in this design — and DataMemory's `mem_write_en` is gated by `~mem_access_addr[15]` so an ST targeting MMIO never aliases into a DMem word. (DMem only decodes `addr[2:0]`; without the gate, an ST to `0x8000` would also overwrite DMem word 0.)

### Opcode and FSM

ControlUnit asserts `fft_run` combinationally when `opcode == 4'b1010`. All other control signals stay at their safe defaults, so the opcode performs no GPR or DMem writes by itself.

```verilog
parameter IDLE = 2'd0, SWAP = 2'd1, RUN = 2'd2, DONE = 2'd3;
reg [1:0] state;
reg [7:0] swap_idx;

initial begin state = IDLE; swap_idx = 0; end

always @(posedge clk) begin
    case (state)
        IDLE: if (fft_run) begin state <= SWAP; swap_idx <= 8'd0; end
        SWAP: begin
            swap_idx <= swap_idx + 1'b1;
            if (swap_idx == 8'd255) state <= RUN;
        end
        RUN:  if (fft_done) state <= DONE;
        DONE: if (!fft_run) state <= IDLE;
    endcase
end

assign ext_active = (state == SWAP);
assign ext_addr_a = swap_idx;
assign ext_addr_b = bitrev8(swap_idx);
assign ext_we     = ext_active & (bitrev8(swap_idx) > swap_idx);

assign fft_rst = (state != RUN);                 // FFT held in reset except during compute
assign stall   = fft_run & ~fft_done;            // PC freezes for the whole opcode
```

Datapath gates PC update with that `stall`: `if (~stall) pc_current <= pc_next;`.

Walk-through of one FFT_RUN:

1. CPU on a non-FFT instruction → `fft_run=0`, FSM in IDLE, `fft_rst=1`, FFT idle.
2. CPU advances into FFT_RUN → `fft_run=1`. PC stalls. FSM transitions IDLE→SWAP on the next edge.
3. **SWAP phase (256 cycles):** for each `swap_idx`, if `bitrev8(swap_idx) > swap_idx` the SoC swaps `rf[swap_idx] ↔ rf[bitrev8(swap_idx)]`; otherwise no-op. After cycle 256 the FSM transitions SWAP→RUN, `fft_rst` falls.
4. **RUN phase (≈1024 cycles):** the FFT computes exactly as today. When `Controller.done` pulses, `done_latch <= 1`. FSM transitions RUN→DONE on that edge.
5. Next edge: `fft_done=1`, `stall=0`, PC advances. FSM transitions DONE→IDLE, `fft_rst` rises (clears `done_latch` ready for the next run).

Total CPU stall ≈ 1282 cycles per FFT_RUN.

### Correctness / hazard notes

- `ext_we` is asserted only during SWAP, when `fft_rst=1` (FFT held in reset). The Controller-driven write path and the new external swap path are therefore mutually exclusive — no `rf[]` contention.
- The in-place swap relies on Verilog non-blocking semantics: both `rf[eff_addr_a] <= eff_din_a` and `rf[eff_addr_b] <= eff_din_b` evaluate their RHS at the start of the timestep. Each pair completes in one clock with no temporary register.
- The MMIO `rf[]` read window reads `rf[ext_raddr]` combinationally. The CPU is stalled during SWAP and RUN, so no LD targets the read window mid-FFT — no read/write race.
- The SoC has no top-level reset. `pc_current=0`, `done_latch=0`, and FSM `state=IDLE` come from `initial` blocks in their respective modules — sufficient for simulation and for typical FPGA power-on init. Note this in `SoC.v`.

## RTL changes

### NEW [Verilog-Files/src/SoC.v](../EEE4120F_Butterfly_FFT_Co-processor/Verilog-Files/src/SoC.v)

Top-level wrapper, single `clk` input (matches StarCore1's existing convention). Contents:
- Instantiate `StarCore1` (with new ports below).
- Instantiate `FFT_Coprocessor` (with new external ports below).
- The 4-state FSM, `bitrev8` function (same form as [FFT_Coprocessor_tb.v:58-64](../EEE4120F_Butterfly_FFT_Co-processor/Co-processor/tb/FFT_Coprocessor_tb.v#L58-L64), now in synthesizable RTL), and all the assigns shown above.
- MMIO address decode and read mux for the `rf[]` window and STATUS register; drive `mmio_read_data` and `mmio_read_sel` into the CPU.

### EDIT [Verilog-Files/src/StarCore1.v](../EEE4120F_Butterfly_FFT_Co-processor/Verilog-Files/src/StarCore1.v)

Add pass-through ports so SoC can observe / drive the CPU's memory bus and the new signals. DataMemory **stays inside Datapath** — no internal CPU logic changes:
- New outputs: `mem_access_addr[15:0]`, `mem_read`, `fft_run`.
- New inputs: `stall`, `mmio_read_data[15:0]`, `mmio_read_sel`.

These are straight pass-throughs into Datapath / ControlUnit. Existing `StarCore1_tb` instantiations need a small update to tie the new inputs to safe defaults (`.stall(1'b0)`, `.mmio_read_data(16'd0)`, `.mmio_read_sel(1'b0)`) and leave the new outputs dangling. Standalone CPU behaviour is identical to today under that tie-off.

### EDIT [Verilog-Files/src/Datapath.v](../EEE4120F_Butterfly_FFT_Co-processor/Verilog-Files/src/Datapath.v)

- Add ports: `output [15:0] mem_access_addr`, `output mem_read`, `input [15:0] mmio_read_data`, `input mmio_read_sel`, `input stall`.
- Keep the `DataMemory dm (...)` instance unchanged structurally — but gate its `mem_write_en` and `mem_read` inputs by `~mem_access_addr[15]` so MMIO-targeted accesses don't alias into DMem (DMem only decodes `addr[2:0]`, so without this gating any non-DMem LD/ST would also touch DMem).
- Drive new outputs from existing internal signals (`mem_access_addr = alu_result`, `mem_read` from existing internal wire).
- Replace the writeback assignment at [Datapath.v:285](../EEE4120F_Butterfly_FFT_Co-processor/Verilog-Files/src/Datapath.v#L285):
  ```verilog
  assign reg_write_data = mem_to_reg
                        ? (mmio_read_sel ? mmio_read_data : mem_read_data)
                        : alu_result;
  ```
  where `mmio_read_sel = mem_access_addr[15]` is driven from SoC.
- Gate the PC register: `always @(posedge clk) if (~stall) pc_current <= pc_next;` (replaces the always block at [Datapath.v:113-115](../EEE4120F_Butterfly_FFT_Co-processor/Verilog-Files/src/Datapath.v#L113-L115)).

### EDIT [Verilog-Files/src/ControlUnit.v](../EEE4120F_Butterfly_FFT_Co-processor/Verilog-Files/src/ControlUnit.v)

- Add `output reg fft_run`.
- Default `fft_run = 1'b0` in the safe-defaults block ([ControlUnit.v:131-140](../EEE4120F_Butterfly_FFT_Co-processor/Verilog-Files/src/ControlUnit.v#L131-L140)).
- In the `4'b1010` case ([ControlUnit.v:167-170](../EEE4120F_Butterfly_FFT_Co-processor/Verilog-Files/src/ControlUnit.v#L167-L170)), set `fft_run = 1'b1;` and update the truth-table comment to reflect the repurposing from "Reserved — no-op" to "FFT_RUN".

### EDIT [Co-processor/src/ButterflyMemory.v](../EEE4120F_Butterfly_FFT_Co-processor/Co-processor/src/ButterflyMemory.v)

- Add ports: `input ext_active`, `input [7:0] ext_addr_a`, `input [7:0] ext_addr_b`, `input ext_we` (for the swap path), and `input [7:0] ext_raddr`, `output [63:0] ext_rdout` (for the MMIO read window).
- Insert the `eff_*` mux shown earlier so that when `ext_active=1` the SoC drives addresses / we and the data path implements a hard-wired swap; when `ext_active=0`, behaviour is identical to today.
- Add `assign ext_rdout = rf[ext_raddr];` — a third combinational read port (safe; `rf[]` already supports two).

### EDIT [Co-processor/src/FFT_Coprocessor.v](../EEE4120F_Butterfly_FFT_Co-processor/Co-processor/src/FFT_Coprocessor.v)

- Add `ext_active`, `ext_addr_a[7:0]`, `ext_addr_b[7:0]`, `ext_we`, `ext_raddr[7:0]`, `ext_rdout[63:0]` as straight pass-throughs to the `mem` instance.
- Existing `FFT_Coprocessor_tb` instantiations need a small update to tie the new inputs to 0 (`.ext_active(1'b0), .ext_addr_a(8'd0), .ext_addr_b(8'd0), .ext_we(1'b0), .ext_raddr(8'd0)`) and leave `ext_rdout` dangling.

## Verification

Limited to elaboration / regression at this stage. A full SoC testbench and CPU program are deferred.

1. **Elaboration check.** Extend the Makefile to compile all CPU sources + FFT sources + `SoC.v` with `iverilog -Wall -I Verilog-Files/src -I Co-processor/src`. Expect zero errors. Acknowledge any pre-existing width-mismatch warnings on the unsigned-twiddle / signed-`w_*` boundary.
2. **Regression: existing StarCore1_tb** (after the small tie-off update on new inputs). DataMemory's location inside Datapath is preserved and the `uut.DU.dm.memory[N]` hierarchical references at lines 182, 236 still resolve. All existing assertions should pass unchanged.
3. **Regression: existing FFT_Coprocessor_tb** (after tying the new `ext_*` inputs to 0). The hierarchical `uut.mem.rf[i]` loading still works and the FFT result matches the original golden output.

## Out of scope

- SoC testbench and the CPU program that triggers FFT_RUN + reads results via the MMIO `rf[]` window.
- Sample-input data generation (extending [Golden-Measures/signal-generator.py](../EEE4120F_Butterfly_FFT_Co-processor/Golden-Measures/signal-generator.py) to emit natural-order `rf[]` preload files).
- Golden-measure comparison against [Golden_Measure/](../EEE4120F_Butterfly_FFT_Co-processor/Golden_Measure/) outputs.
- CPU-writable MMIO into `rf[]` (read-only from the CPU side for now).
- Polling-style status loop (the stall on FFT_RUN replaces the need; STATUS exists for future use).
- FFT_RUN returning a value into a register.
- Top-level system reset signal.
