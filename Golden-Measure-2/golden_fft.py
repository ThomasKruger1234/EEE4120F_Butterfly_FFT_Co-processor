#!/usr/bin/env python3
"""
Golden measure for the 256-point FFT co-processor.

Reads 256 complex samples in Q10.22 fixed-point format from an input file,
computes the FFT in floating-point (NumPy), then writes 256 complex results
back in the same Q10.22 format.

File format (input and output):
  - One sample per line.
  - Each line is a 64-bit hex value (16 hex chars, no '0x' prefix).
  - Upper 32 bits = real part (Q10.22, two's complement)
  - Lower 32 bits = imaginary part (Q10.22, two's complement)

Usage:
    python3 golden_fft.py input.data output.data
"""

import sys
import numpy as np

N = 256
FRAC_BITS = 22
SCALE = 1 << FRAC_BITS          # 2^22
INT_MIN = -(1 << 31)
INT_MAX = (1 << 31) - 1


def q1022_to_float(bits32):
    """Convert a 32-bit two's-complement Q10.22 value to a Python float."""
    if bits32 & 0x80000000:
        bits32 -= 1 << 32
    return bits32 / SCALE


def float_to_q1022(x):
    """Convert a float to 32-bit two's-complement Q10.22 (saturating)."""
    q = int(round(x * SCALE))
    q = max(INT_MIN, min(INT_MAX, q))
    return q & 0xFFFFFFFF


def read_samples(path):
    samples = np.zeros(N, dtype=np.complex128)
    with open(path) as f:
        lines = [ln.strip() for ln in f if ln.strip()]
    if len(lines) != N:
        raise ValueError(f"Expected {N} samples, got {len(lines)} in {path}")
    for i, line in enumerate(lines):
        word = int(line, 16)
        re_bits = (word >> 32) & 0xFFFFFFFF
        im_bits = word & 0xFFFFFFFF
        samples[i] = complex(q1022_to_float(re_bits), q1022_to_float(im_bits))
    return samples


def write_samples(path, samples):
    with open(path, "w") as f:
        for s in samples:
            re_bits = float_to_q1022(s.real)
            im_bits = float_to_q1022(s.imag)
            word = (re_bits << 32) | im_bits
            f.write(f"{word:016x}\n")


def main():
    if len(sys.argv) != 3:
        print("usage: golden_fft.py <input.data> <output.data>", file=sys.stderr)
        sys.exit(1)

    in_path, out_path = sys.argv[1], sys.argv[2]
    x = read_samples(in_path)
    X = np.fft.fft(x)
    write_samples(out_path, X)
    print(f"Wrote {N} FFT results to {out_path}")


if __name__ == "__main__":
    main()
