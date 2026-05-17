"""
This script is used to verify precision. 
It uses Q10.22 fixed point integers instead of floating point precision.
Input is a sampled combination of sine waves.
The frequencies are set on generation; this is used to verify the result.
Note: As per Nyquist-Shannon sampling theorem, only frequencies below 128Hz can be detected accuractely.
"""

import math

frequencies = [1, 5, 127]

# Q10.22 Constants
FRACTIONAL_BITS = 22
SCALE_FACTOR = 1 << FRACTIONAL_BITS  # 2^22 = 4194304

def float_to_q10_22(x):
    """Converts a float to a Q10.22 fixed-point integer."""
    return int(round(x * SCALE_FACTOR))

def q10_22_to_float(x):
    """Converts a Q10.22 fixed-point integer back to a float."""
    return float(x) / SCALE_FACTOR

def fixed_mul(a, b):
    """
    Multiplies two Q10.22 fixed-point numbers.
    (a * b) >> 22 keeps the fractional binary point in the correct spot.
    """
    # Using python's arbitrary precision ints prevents intermediate 64-bit overflow
    return (a * b) >> FRACTIONAL_BITS

def bit_reverse_copy(x_real, x_imag):
    """Reorders the real and imag arrays using bit-reversal."""
    N = len(x_real)
    j = 0
    r_res = list(x_real)
    i_res = list(x_imag)
    
    for i in range(N):
        if i < j:
            r_res[i], r_res[j] = r_res[j], r_res[i]
            i_res[i], i_res[j] = i_res[j], i_res[i]
        
        bit = N >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j |= bit
        
    return r_res, i_res

def generate_twiddle_factors_q10_22(N):
    """
    Pre-computes lookup tables for W_N^k twiddle factors in Q10.22 format.
    W_N^k = cos(2*pi*k/N) - j*sin(2*pi*k/N)
    """
    w_real = []
    w_imag = []
    for k in range(N // 2):
        angle = -2.0 * math.pi * k / N
        w_real.append(float_to_q10_22(math.cos(angle)))
        w_imag.append(float_to_q10_22(math.sin(angle)))
    return w_real, w_imag

def radix2_fft_256_fixed(x_real):
    """
    Computes 256-point Radix-2 FFT using strictly integer arithmetic (Q10.22).
    Includes scaling at each stage to prevent integer overflow.
    """
    N = len(x_real)
    if N != 256:
        raise ValueError("Optimized strictly for N=256")
        
    # Initialize imaginary part to 0 in Q10.22 format
    x_imag = [0] * N
    
    # 1. Bit-reversal permutation
    X_real, X_imag = bit_reverse_copy(x_real, x_imag)
    
    # 2. Pre-compute twiddle factors table
    twiddle_r, twiddle_i = generate_twiddle_factors_q10_22(N)
    
    num_stages = 8 # log2(256)
    
    # 3. FFT Butterfly Stages
    for stage in range(1, num_stages + 1):
        m = 1 << stage
        m_half = m >> 1
        
        # Determine the step size in our pre-calculated twiddle table
        # At stage 1, we use W_2 (step = 128). At stage 8, we use W_256 (step = 1).
        twiddle_step = N // m 
        
        for k in range(0, N, m):
            for j in range(m_half):
                idx_even = k + j
                idx_odd = k + j + m_half
                
                # Fetch fixed-point twiddle factor components
                w_r = twiddle_r[j * twiddle_step]
                w_i = twiddle_i[j * twiddle_step]
                
                # Complex multiplication in fixed-point: 
                # t_real = (X_odd_r * w_r) - (X_odd_i * w_i)
                # t_imag = (X_odd_r * w_i) + (X_odd_i * w_r)
                t_r = fixed_mul(X_real[idx_odd], w_r) - fixed_mul(X_imag[idx_odd], w_i)
                t_i = fixed_mul(X_real[idx_odd], w_i) + fixed_mul(X_imag[idx_odd], w_r)
                
                u_r = X_real[idx_even]
                u_i = X_imag[idx_even]
                
                # Butterfly Calculation + Scaling down by 2 (>> 1) to prevent overflow
                X_real[idx_even] = (u_r + t_r) >> 1
                X_imag[idx_even] = (u_i + t_i) >> 1
                
                X_real[idx_odd] = (u_r - t_r) >> 1
                X_imag[idx_odd] = (u_i - t_i) >> 1
                
    return X_real, X_imag

if __name__ == "__main__":
    fs = 256
    
    # Signal = sin(2*pi*f1*t)
    fs = 256  # Sampling frequency

    sample_signal = [0.0] * 256

    for frequency in frequencies:
        for t in range(256):
            sample_signal[t] += math.sin(2 * math.pi * frequency * (t / fs))
    
    sample_signal = [sample * (1/len(frequencies)) for sample in sample_signal] 
    
    # Convert entire input vector to Q10.22 Integers
    fixed_signal = [float_to_q10_22(sample) for sample in sample_signal]
    
    # Run the Fixed-Point FFT
    X_fixed_real, X_fixed_imag = radix2_fft_256_fixed(fixed_signal)
    
    print("Fixed-Point (Q10.22) FFT complete.")
    print("\nFirst 5 Bins in Raw Q10.22 Form (Integers):")
    for i in range(5):
        print(f"Bin {i} -> Real: {X_fixed_real[i]}, Imag: {X_fixed_imag[i]}")
            
    # Assuming X_fixed_real and X_fixed_imag are the integer outputs from the FFT...

    print("Scanning for peaks entirely in Q10.22 Fixed-Point...")

    # Define a fixed-point threshold. 
    # If we want a threshold equivalent to a float magnitude of ~5.0:
    # (5.0 / 256 scaling) = 0.0195. In Q10.22, that is roughly 81920.
    # Squared magnitude threshold = 81920 * 81920 >> 22 = 1600
    FIXED_THRESHOLD = 1600 

    print()
    for i in range(128): # Only check the first half (positive frequencies)
        # Compute squared magnitude using fixed-point math
        mag_squared = fixed_mul(X_fixed_real[i], X_fixed_real[i]) + fixed_mul(X_fixed_imag[i], X_fixed_imag[i])
        
        # Check against our integer threshold
        if mag_squared > FIXED_THRESHOLD:
            print(f"Peak detected at Bin {i}! Raw Fixed-Point Mag^2 Integer value: {mag_squared}")

    print()
    print(f"Peaks expected at {frequencies}")
        

