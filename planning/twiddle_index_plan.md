# Twiddle-Index Logic for the Butterfly FFT Co-processor

## Context

The Cooley-Tukey radix-2 FFT computes each butterfly as `A' = A + W·B`, `B' = A − W·B`, where the twiddle factor `W` is `W_N^k` for some index `k` that depends on which butterfly within which stage is executing. Right now the co-processor's [Controller.v](../Co-processor/src/Controller.v) emits `iteration[6:0]` (0–127) and `stage[2:0]` (0–7), and [TwiddleMemory.v](../Co-processor/src/TwiddleMemory.v) accepts an 8-bit address `k` — but **nothing is computing `k` from (iteration, stage)**. That's the gap this plan fills.

This is the first concrete integration step in Bucket A from the earlier state-of-code summary. After this, the next dependency is wiring the controller's outputs into a top-level `FFT_Coprocessor.v` wrapper.

---

## The math

Standard in-place **DIT radix-2** Cooley-Tukey on `N=256` samples with stages `s` 0-indexed from 0 to 7:

- Group span at stage `s` = `2^(s+1)` samples.
- Butterflies per group = `2^s`; number of groups = `N / 2^(s+1) = 2^(7−s)`.
- Within a group, butterfly index `j ∈ {0, 1, …, 2^s − 1}`.
- Twiddle factor = `W_N^(j · N / 2^(s+1)) = W_256^(j · 2^(7−s))`.

Mapping the global iteration counter `i ∈ {0..127}` to `(group, j)`:
- `j = i[s−1:0]` — the low `s` bits of iteration index the butterfly's position within its group.
- `group = i[6:s]` — the upper bits index which group we're in.

So the twiddle ROM address is:

> **`k = (i mod 2^s) · 2^(7−s)` = take the low `s` bits of `iteration` and place them in the top `s` bit positions of a 7-bit field, zero-padding the rest.**

Concrete table (column = stage, row = first few iterations):

| iter | s=0 | s=1 | s=2 | s=3 | s=7 |
|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 0  | 0  | 0  | 0  |
| 1 | 0 | 64 | 32 | 16 | 1  |
| 2 | 0 | 0  | 64 | 32 | 2  |
| 3 | 0 | 64 | 96 | 48 | 3  |
| 4 | 0 | 0  | 0  | 64 | 4  |
| … | … | …  | …  | …  | …  |
| 127 | 0 | 64 | 96 | 112 | 127 |

`k` is 7 bits (0..127) which the existing `TwiddleMemory` already accepts — it masks `k[6:0]` internally (see [TwiddleMemory.v:51](../Co-processor/src/TwiddleMemory.v#L51)), so the 8-bit `k` port can be driven with `{1'b0, k[6:0]}`.

**Note on `iteration` vs. memory address:** The twiddle formula uses the **raw natural-order** iteration counter, not the bit-reversed address. The bit-reversal in the address path is for sample storage layout (DIT requires bit-reversed input), and is independent of the twiddle-index computation.

---

## Recommended implementation

Add the twiddle-index generator inside [Controller.v](../Co-processor/src/Controller.v) — it already has `iteration` and `stage` in scope and already emits other addresses, so this keeps related logic together and avoids exposing the counters externally just to recompute the same thing in the wrapper.

**New port on `Controller`:**
```verilog
output wire [7:0] twiddle_addr   // index k into TwiddleMemory
```

**Combinational logic (case statement — readable, synthesizes to a small mux):**
```verilog
reg [6:0] k;
always @(*) begin
    case (stage)
        3'd0: k = 7'd0;
        3'd1: k = {iteration[0],    6'd0};
        3'd2: k = {iteration[1:0],  5'd0};
        3'd3: k = {iteration[2:0],  4'd0};
        3'd4: k = {iteration[3:0],  3'd0};
        3'd5: k = {iteration[4:0],  2'd0};
        3'd6: k = {iteration[5:0],  1'd0};
        3'd7: k =  iteration[6:0];
        default: k = 7'd0;
    endcase
end
assign twiddle_addr = {1'b0, k};
```

Alternative one-liner using variable shift (equivalent, may be less explicit during synthesis review):
```verilog
wire [6:0] j_mask = (7'd1 << stage) - 1'b1;
assign twiddle_addr = {1'b0, (iteration & j_mask) << (3'd7 - stage)};
```

The case form is preferred — it matches the textbook table 1:1 and makes regressions easy to spot.

---

## Critical files

- [Co-processor/src/Controller.v](../Co-processor/src/Controller.v) — **add** `twiddle_addr` output and the combinational block above. No changes to existing sequential logic or address generation.
- [Co-processor/src/TwiddleMemory.v](../Co-processor/src/TwiddleMemory.v) — **no change**; the existing `k` input port consumes the new signal directly.
- [Co-processor/tb/Controller_tb.v](../Co-processor/tb/Controller_tb.v) — **add** assertions on `twiddle_addr` for known (stage, iteration) pairs (see Verification).

No new files needed at this step.

---

## Verification

1. Extend [Controller_tb.v](../Co-processor/tb/Controller_tb.v) with checks at landmark (stage, iteration) pairs that exercise each stage's pattern. Add a helper `check_twiddle(exp_k)` and call it after the existing `step` calls at:
    - `(s=0, i=0..3)` → expect `k = 0, 0, 0, 0`
    - `(s=1, i=0,1,2,3)` → expect `k = 0, 64, 0, 64`
    - `(s=2, i=0,1,2,3,4)` → expect `k = 0, 32, 64, 96, 0`
    - `(s=3, i=0,1,2)` → expect `k = 0, 16, 32`
    - `(s=7, i=0,1,127)` → expect `k = 0, 1, 127`
2. Run via the existing Makefile target: `make butterflyctr` in [Co-processor/](../Co-processor/) — it already compiles and runs `Controller_tb` and dumps a VCD to `waves/Controller_tb.vcd`.
3. Spot-check the VCD in GTKWave: as you scrub through stage 7, `twiddle_addr` should ramp linearly with iteration; at stage 0 it should stay at 0.
4. Cross-check against any reference DIT table from a textbook (e.g. Proakis & Manolakis, Oppenheim & Schafer) for `N=8` scaled up to `N=256` — the column for stage `s` should match `iteration[s-1:0] << (7-s)`.

---

## Out of scope (flagged for follow-up)

The address-generation logic at [Controller.v:72-81](../Co-processor/src/Controller.v#L72-L81) is **stage-independent** — `addr_a_rev` and `addr_b_rev` are functions of `iteration` only, not of `stage`. A real in-place DIT pairing needs `addr_b = addr_a + 2^s`, which varies per stage. The twiddle-index plan above does not depend on this being correct (it uses `iteration`/`stage` directly), but the co-processor will not produce a valid FFT until the address generator is fixed. This is a separate task; flag for the next planning round.