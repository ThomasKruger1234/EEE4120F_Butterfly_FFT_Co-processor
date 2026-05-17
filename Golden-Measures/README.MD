Use `fft-floating.py` to measure accuracy and `fft-fixed.py` to measure precision.

`signal-generator.py` creates a combination of sampled sine waves the can be loaded into the FPGA memory for processing.
It creates an output hex file where every two lines represent the real then imaginary magnitude.
