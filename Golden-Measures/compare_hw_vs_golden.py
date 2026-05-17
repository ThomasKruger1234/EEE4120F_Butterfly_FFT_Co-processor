#!/usr/bin/env python3
"""
Bit-for-bit comparison between the FFT co-processor's simulation output
and the Q10.22 fixed-point golden model.

Usage:
    python3 compare_hw_vs_golden.py <input_mem> <hw_dump>

  <input_mem>  same file the testbench loads (e.g. input_sequential.mem):
               512 hex lines, alternating Q10.22 real/imag per sample.
  <hw_dump>    capture of the testbench stdout produced by
               `vvp build/fft_coprocessor_sim`. Parses the 256 "k | ..."
               lines printed by dump_outputs.
"""
import math
import re
import sys

FRACTIONAL_BITS = 22
SCALE = 1 << FRACTIONAL_BITS
N = 256


def s32(u):
    u &= (1 << 32) - 1
    return u - (1 << 32) if u & (1 << 31) else u


def fixed_mul(a, b):
    return (a * b) >> FRACTIONAL_BITS


def bit_reverse_copy(xr, xi):
    j = 0
    r = list(xr)
    i = list(xi)
    for k in range(N):
        if k < j:
            r[k], r[j] = r[j], r[k]
            i[k], i[j] = i[j], i[k]
        bit = N >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j |= bit
    return r, i


def gen_twiddles():
    wr = [int(round(math.cos(-2 * math.pi * k / N) * SCALE)) for k in range(N // 2)]
    wi = [int(round(math.sin(-2 * math.pi * k / N) * SCALE)) for k in range(N // 2)]
    return wr, wi


def radix2_fft_fixed(xr, xi):
    """Q10.22 radix-2 DIT FFT with per-stage >>1 scaling (matches the hardware)."""
    X_real, X_imag = bit_reverse_copy(xr, xi)
    twiddle_r, twiddle_i = gen_twiddles()
    for stage in range(1, 9):
        m = 1 << stage
        m_half = m >> 1
        step = N // m
        for k in range(0, N, m):
            for j in range(m_half):
                ie = k + j
                io = k + j + m_half
                wr = twiddle_r[j * step]
                wi = twiddle_i[j * step]
                t_r = fixed_mul(X_real[io], wr) - fixed_mul(X_imag[io], wi)
                t_i = fixed_mul(X_real[io], wi) + fixed_mul(X_imag[io], wr)
                u_r = X_real[ie]
                u_i = X_imag[ie]
                X_real[ie] = (u_r + t_r) >> 1
                X_imag[ie] = (u_i + t_i) >> 1
                X_real[io] = (u_r - t_r) >> 1
                X_imag[io] = (u_i - t_i) >> 1
    return X_real, X_imag


def load_input(path):
    with open(path) as f:
        lines = [ln.strip() for ln in f if ln.strip()]
    assert len(lines) == 2 * N, f"expected {2*N} hex lines, got {len(lines)}"
    xr, xi = [], []
    for i in range(0, 2 * N, 2):
        xr.append(s32(int(lines[i], 16)))
        xi.append(s32(int(lines[i + 1], 16)))
    return xr, xi


def parse_hw_dump(path):
    """Parses the 256 'k | 0xRRRRRRRR ... | 0xIIIIIIII ...' lines."""
    row = re.compile(r"^\s*(\d+)\s*\|\s*0x([0-9a-fA-F]+)\s+\S+\s*\|\s*0x([0-9a-fA-F]+)")
    bins = {}
    with open(path) as f:
        for line in f:
            m = row.match(line)
            if m:
                bins[int(m.group(1))] = (s32(int(m.group(2), 16)),
                                         s32(int(m.group(3), 16)))
    assert len(bins) == N, f"expected {N} bins, parsed {len(bins)}"
    return bins


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    xr, xi = load_input(sys.argv[1])
    gr, gi = radix2_fft_fixed(xr, xi)
    hw = parse_hw_dump(sys.argv[2])

    print(f"{'k':>3} | {'HW re':>12} {'GOLD re':>12} {'Δre':>6} | "
          f"{'HW im':>12} {'GOLD im':>12} {'Δim':>6}")
    print("-" * 76)

    exact = 0
    mismatches = []
    for k in range(N):
        hr, hi = hw[k]
        dr = hr - gr[k]
        di = hi - gi[k]
        if dr == 0 and di == 0:
            exact += 1
        else:
            mismatches.append(k)
        # Print bins with non-negligible magnitude or any mismatch.
        mag = math.sqrt((gr[k] / SCALE) ** 2 + (gi[k] / SCALE) ** 2)
        if mag > 1e-3 or dr or di:
            mark = " <<" if (dr or di) else ""
            print(f"{k:>3} | {hr/SCALE:>12.6f} {gr[k]/SCALE:>12.6f} {dr:>6d} | "
                  f"{hi/SCALE:>12.6f} {gi[k]/SCALE:>12.6f} {di:>6d}{mark}")

    print("-" * 76)
    print(f"Exact bit-for-bit matches: {exact}/{N}")
    if mismatches:
        max_dr = max(abs(hw[k][0] - gr[k]) for k in mismatches)
        max_di = max(abs(hw[k][1] - gi[k]) for k in mismatches)
        print(f"Mismatched bins: {mismatches}")
        print(f"Max |Δre| = {max_dr} LSB ({max_dr/SCALE:.3e})")
        print(f"Max |Δim| = {max_di} LSB ({max_di/SCALE:.3e})")
        sys.exit(1)
    print("PASS: hardware output matches the Q10.22 golden bit-for-bit.")


if __name__ == "__main__":
    main()
