# FFT_Coprocessor.v top-level integration

## Context

All four leaf modules now have the right behavior individually:

- [Controller.v](../Co-processor/src/Controller.v) — emits `addr_a`, `addr_b`, `twiddle_addr` from `iteration`/`stage`; asserts `done` when (s=7, i=127).
- [ButterflyMemory.v](../Co-processor/src/ButterflyMemory.v) — 256×64-bit register file, sync dual-port write, combinational dual-port read.
- [ButterflyCompute.v](../Co-processor/src/ButterflyCompute.v) — pure combinational (A, B) = (a + W·b, a − W·b).
- [TwiddleMemory.v](../Co-processor/src/TwiddleMemory.v) — combinational ROM read, `$readmemh`-initialised from `src/twiddle.data`.

Nothing connects them yet — there is no top-level wrapper in `Co-processor/src/`. This plan adds one. A testbench is deferred to a follow-up.

## Approach

### Wrapper port list (minimal, per user choice)

```verilog
module FFT_Coprocessor (
    input  wire clk,
    input  wire rst,
    output wire done
);
```

Samples are loaded by the testbench writing directly to `uut.mem.rf[]` in bit-reversed positions before releasing `rst`; results are read out the same way after `done` asserts.

### Timing

The read→compute→write path is entirely combinational (mem read, twiddle ROM, ButterflyCompute). Both the Controller and the memory register on `posedge clk` with `we` high. So `we` can be held high every cycle — one butterfly per cycle, 1024 cycles total (8 stages × 128 butterflies). Consecutive butterflies in a stage touch disjoint pairs (the new address generator guarantees this), so there's no write-then-read hazard on the same address.

### Done latching

`Controller.done` is one-cycle pulse semantics: it asserts when `we && (s=7, i=127)` and clears whenever `we` falls. The wrapper needs a stable `done` for external consumers, so:

```verilog
reg done_latch;
always @(posedge clk) begin
    if (rst)            done_latch <= 1'b0;
    else if (ctrl_done) done_latch <= 1'b1;
end
assign done         = done_latch;
assign we_internal  = ~done_latch & ~rst;   // free-run until done, idle after
```

Once `done_latch` goes high, `we_internal` falls, Controller stops advancing, and `done` stays asserted.

### Module wiring (all internal wires)

| Signal | Driver → Consumer |
|---|---|
| `addr_a`, `addr_b` | Controller → ButterflyMemory |
| `twiddle_addr` | Controller → TwiddleMemory (`k`) |
| `dout_a_*`, `dout_b_*` | ButterflyMemory → ButterflyCompute (`a_*`, `b_*`) |
| `twiddle_real/imag` | TwiddleMemory → ButterflyCompute (`w_*`) |
| `A_*`, `B_*` | ButterflyCompute → ButterflyMemory (`din_a_*`, `din_b_*`) |
| `we_internal` | wrapper → both Controller and ButterflyMemory |

TwiddleMemory outputs are unsigned `[31:0]`; ButterflyCompute takes `signed [31:0]`. Verilog passes the bit pattern through unchanged — the Q10.22 two's-complement values are interpreted correctly on the receiving side. No casting needed.

### Signal semantics: what `rst` and `we` actually do

**`rst` — reset.** Active-high *synchronous* reset on the Controller. On any `posedge clk` while `rst=1` ([Controller.v:48-51](../Co-processor/src/Controller.v#L48-L51)):

- `iteration <= 0`, `stage <= 0`, `done <= 0`.

ButterflyMemory has **no reset** — `rf[]` keeps whatever values were written/loaded last. This is what lets the testbench load samples into `rf[]` *before* releasing `rst` and have them survive the reset pulse.

In the wrapper, `rst` does two jobs:

1. Holds the Controller's counters at zero so no butterfly is "in flight."
2. Gates `we_internal` low via `we_internal = ~done_latch & ~rst`, so no spurious writes happen while reset is asserted.

When `rst` is released, on the very next clock edge `we_internal` is high and the FFT begins immediately — there is no separate `start` pulse.

**`we` — write-enable / advance.** A single shared signal driven into **both** the Controller and ButterflyMemory. On any `posedge clk` while `we=1`:

- `ButterflyMemory` commits the butterfly result: `rf[addr_a] <= {A_real, A_imag}` and `rf[addr_b] <= {B_real, B_imag}` ([ButterflyMemory.v:30-35](../Co-processor/src/ButterflyMemory.v#L30-L35)).
- `Controller` advances: `iteration++`, or wraps to next `stage` at `iteration==127`, or asserts `done` at `(stage=7, iteration=127)` ([Controller.v:55-63](../Co-processor/src/Controller.v#L55-L63)).

`we` is the "tick" that says *this cycle's butterfly result is valid — store it and move on*. Because the entire read→compute→write data path is combinational (mem read → twiddle ROM → ButterflyCompute → mem din), `we` can be held high every cycle — one butterfly per clock.

In the wrapper, `we_internal = ~done_latch & ~rst`: free-runs at 1 from end-of-reset until `done_latch` goes high, then idles forever.

## Files

- **NEW [Co-processor/src/FFT_Coprocessor.v](../Co-processor/src/FFT_Coprocessor.v)** — the wrapper described above. Include guard `FFT_COPROCESSOR_V`, `timescale 1ns/1ps`, instances named `ctrl`, `mem`, `tw`, `bfly`.
- **EDIT [Co-processor/Makefile](../Co-processor/Makefile)** — add an `fft` target that at minimum compiles the wrapper (so we catch port/typo errors). With no testbench yet, the cleanest form is a syntax/elab check via `iverilog`:
    ```make
    fft:
    	iverilog -Wall -I src/ -o build/fft_sim \
    	    src/Controller.v src/ButterflyMemory.v src/ButterflyCompute.v \
    	    src/TwiddleMemory.v src/Adder.v src/Subtractor.v src/Multiplier.v \
    	    src/FFT_Coprocessor.v
    ```
    Sources must include the leaf arithmetic modules (`Adder.v`, `Subtractor.v`, `Multiplier.v`) that `ButterflyCompute` instantiates. Once a testbench is added later, `./build/fft_sim` and `gtkwave` lines join this target.

No edits to the four existing src modules. No testbench in this step (per user — deferred to a follow-up).

## Verification

Without a testbench, verification is limited to:

1. **Elaboration check** — run the `make fft` command above. `iverilog -Wall` should produce no errors or warnings (warnings on width/signedness of the twiddle-to-`w_*` connection are acceptable if they appear, but worth a quick look).
2. **Visual port-match check** — read the wrapper alongside each leaf module's port declaration to confirm every connection is `.name(signal)` style and no port is left dangling.

A functional smoke test (load samples → run → check outputs against a reference FFT) is deferred to the next iteration when a testbench is added.

## Out of scope

- Testbench (deferred).
- Bit-reversal hardware (testbench will own this when added).
- Streaming I/O ports / load FSM / readout FSM.
- Replacing the register-file memory with BRAM-style inferable memory.
- Pipelining the read→compute→write path beyond one butterfly per cycle.
