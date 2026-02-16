import numpy as np
from scipy.signal import convolve2d


image = np.zeros((32, 32), dtype=np.int16)
image[:, 14:18] = 0xAA  # Columns 14, 15, 16, 17 set to 170

# 2. Define the Sobel-X Kernel (Vertical Edge Detection)
kernel = np.array([
    [-1, 0, 1],
    [-2, 0, 2],
    [-1, 0, 1]
], dtype=np.int16)

# 3. Perform Convolution
# 'valid' mode gives the 30x30 inner area (just like the monitor logic)
output_raw = convolve2d(image, kernel, mode='valid')

# 4. Perform Clipping (Simulating the FPGA hardware)
output_clipped = np.clip(output_raw, 0, 255).astype(np.uint8)

def print_matrix(matrix, title):
    print(f"\n--- {title} ---")
    for row in matrix:
        print(" ".join(f"{int(x):02x}" if title == "CLIPPED OUTPUT" else f"{int(x):4d}" for x in row))

print_matrix(output_raw, "RAW CONVOLUTION (WITH NEGATIVES)")
print_matrix(output_clipped, "CLIPPED OUTPUT")