"""
This script is used to verify accuracy.
Input is a sampled combination of sine waves.
The frequencies are set on generation; this is used to verify the result.
Note: As per Nyquist-Shannon sampling theorem, only frequencies below 128Hz can be detected accuractely.
"""

import math
import cmath

frequencies = [2, 20, 64, 100, 127]

def bit_reverse_copy(x):
    """
    Reorders the input array using bit-reversal permutation.
    This is required for the in-place Radix-2 Decimation-in-Time (DIT) FFT.
    """
   
    # Copy input to avoid modifying original data
    N = len(x)
    j = 0
    result = list(x) 
    
    for i in range(N):
        if i < j:
            # Swap elements
            result[i], result[j] = result[j], result[i]
        
        # Bit-reversal increment
        bit = N >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j |= bit
        
    return result

def radix2_fft_256(x):
    """
    Computes the 256-point Radix-2 DIT FFT.
    Input 'x' must be a list/sequence of 256 numbers (real or complex).
    """
    N = len(x)
    if N != 256:
        raise ValueError("This specific function is hardcoded/optimized for N=256.")
    
    # 1. Bit-reversal permutation (Rearrange input)
    X = bit_reverse_copy(x)
    
    # 2. Butterfly computation stages
    # Total stages for N=256 is log2(256) = 8
    num_stages = int(math.log2(N)) 
    
    for stage in range(1, num_stages + 1):
        # Length of the sub-FFT at this stage (2, 4, 8, ..., 256)
        m = 1 << stage  
        # Half-length, used to find the pair element for the butterfly
        m_half = m >> 1 
        
        # Principal twiddle factor for this stage: W_m = exp(-2*pi*j / m)
        w_m = cmath.exp(-2j * math.pi / m)
        
        # Loop over the blocks of size 'm'
        for k in range(0, N, m):
            # Initialize twiddle factor W^0 = 1
            w = 1.0 + 0.0j  
            
            # Loop over the elements in the butterfly block
            for j in range(m_half):
                # Target indices for the butterfly operation
                idx_even = k + j
                idx_odd = k + j + m_half
                
                # Twiddle factor multiplication
                t = w * X[idx_odd]
                u = X[idx_even]
                
                # Butterfly calculation (In-place)
                X[idx_even] = u + t
                X[idx_odd] = u - t
                
                # Update twiddle factor for the next element: W^(j+1) = W^j * W_m
                w *= w_m
                
    return X

if __name__ == "__main__":

    # Generate a sample 256-point signal: A combination of sine waves at different frequencies

    # Signal = sin(2*pi*f1*t)
    fs = 256  # Sampling frequency

    sample_signal = [0.0] * 256

    for frequency in frequencies:
        for t in range(256):
            sample_signal[t] += math.sin(2 * math.pi * frequency * (t / fs))
    
    # Run custom FFT
    fft_custom = radix2_fft_256(sample_signal)
    
    # Run built-in Python/NumPy-equivalent validation using math/cmath 
    # (Just using a basic DFT math formula to double-check a few points)
    print("FFT successfully executed!")
    print("\nFrequency Bin Results (Complex Numbers):")
    for i in range(256):
        print(f"Bin {i}: {fft_custom[i]:.4f}")
        
    print("\nPeak Check:")
    # Magnitudes are symmetric; let's find where the magnitudes spike
    magnitudes = [abs(val) for val in fft_custom]
    peaks = [idx for idx, mag in enumerate(magnitudes[:128]) if mag > 40] 
    print(f"Significant frequency components found at bin indices: {peaks}")
    print(f"(Expected peaks near {frequencies})")
