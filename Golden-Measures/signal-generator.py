import math
# Define the frequencies present in your telemetry signal (in Hz)
frequencies = [10, 25]  

def to_q10_22_hex(val):
    """Converts a float value to a 32-bit signed Q10.22 hex string."""
    # Scale float to Q10.22 integer space
    q_val = int(round(val * (1 << 22)))
    
    # Handle 32-bit signed integer clipping boundaries
    if q_val >= (1 << 31):
        q_val = (1 << 31) - 1
    elif q_val < -(1 << 31):
        q_val = -(1 << 31)
        
    # Handle 2's complement representation for negative numbers
    if q_val < 0:
        q_val = (1 << 32) + q_val
        
    # Return as an 8-character uppercase hex string
    return f"{q_val:08X}"

def generate_fft_sequential_vectors():
    fs = 256  # Sampling frequency
    N = 256   # Number of points
        
    # Initialize arrays
    sample_signal_real = [0.0] * N
    sample_signal_imag = [0.0] * N 

    # 1. Synthesize the multi-tone time-domain signal
    for frequency in frequencies:
        for t in range(N):
            sample_signal_real[t] += math.sin(2 * math.pi * frequency * (t / fs))

    # 2. Write real and imaginary values sequentially into a single file
    with open("input_sequential.mem", "w") as f:
        for t in range(N):
            hex_real = to_q10_22_hex(sample_signal_real[t])
            hex_imag = to_q10_22_hex(sample_signal_imag[t])
            
            # Real followed immediately by Imaginary for each sample
            f.write(f"{hex_real}\n")
            f.write(f"{hex_imag}\n")

    print("Successfully generated interleaved test vector file:")
    print("  -> 'input_sequential.mem' (512 lines alternating Real/Imag data)")

if __name__ == "__main__":
    generate_fft_sequential_vectors()
