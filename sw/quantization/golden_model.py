"""
Golden Fixed-Point (Q15.16) Model and Test Vector Generator
Faithfully reproducing the specifications from:
"FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition in Unmanned Surface Vehicles"
Sensors 2026, 26, 1626.
"""

import numpy as np
import os

# Constants for Q15.16 Fixed-Point Arithmetic
Q_FRAC_BITS = 16
SCALE = 1 << Q_FRAC_BITS  # 65536
INT32_MIN = -2147483648
INT32_MAX = 2147483647


def float_to_q1516(val):
    """
    Implements Equation (5) of paper:
    xfx = sat( round(x * 2^16) )
    """
    scaled = np.round(val * SCALE).astype(np.int64)
    saturated = np.clip(scaled, INT32_MIN, INT32_MAX).astype(np.int32)
    return saturated


def q1516_to_float(val):
    """Converts 32-bit Q15.16 integer back to floating point."""
    return val.astype(np.float64) / SCALE


def q1516_mult(a, b):
    """
    Multiplies two Q15.16 numbers:
    a * b produces 64-bit Q30.32 product.
    Rounds with + 2^15, shifts right 16 bits, and saturates to signed 32-bit.
    """
    a_64 = np.int64(a)
    b_64 = np.int64(b)
    prod_64 = a_64 * b_64
    # Rounding to nearest integer: add 2^(15) before right-shift of 16
    rounded = (prod_64 + (1 << (Q_FRAC_BITS - 1))) >> Q_FRAC_BITS
    return np.int32(np.clip(rounded, INT32_MIN, INT32_MAX))


def serialize_weights(w_array):
    """
    Implements Equation (6) & (7) of paper:
    Index order: W[o, i, ky, kx]
    idx(o, i, ky, kx) = ((o * Cin + i) * Ky + ky) * Kx + kx
    Equivalent to C-contiguous 1D flattening.
    """
    assert w_array.ndim == 4, "Weight array must be (Cout, Cin, Ky, Kx)"
    return w_array.ravel(order='C')


def conv2d_q1516(input_fm, weights, biases, stride=1, padding=1):
    """
    Bit-accurate layer-level convolution matching Equation (1) of the paper:
    input_fm: (Cin, H, W) in int32 Q15.16
    weights: (Cout, Cin, Ky, Kx) in int32 Q15.16
    biases: (Cout,) in int32 Q15.16
    """
    Cin, H, W = input_fm.shape
    Cout, _, Ky, Kx = weights.shape

    # Zero padding
    if padding > 0:
        padded = np.zeros((Cin, H + 2 * padding, W + 2 * padding), dtype=np.int32)
        padded[:, padding:padding + H, padding:padding + W] = input_fm
    else:
        padded = input_fm

    H_pad, W_pad = padded.shape[1], padded.shape[2]
    H_out = (H + 2 * padding - Ky) // stride + 1
    W_out = (W + 2 * padding - Kx) // stride + 1

    output_fm = np.zeros((Cout, H_out, W_out), dtype=np.int32)

    for o in range(Cout):
        for out_y in range(H_out):
            in_y = out_y * stride
            for out_x in range(W_out):
                in_x = out_x * stride
                
                # Start accumulation with bias bo
                accum = np.int64(biases[o])
                
                # Accumulate over Cin channels and Ky x Kx window
                for c in range(Cin):
                    for ky in range(Ky):
                        for kx in range(Kx):
                            px = padded[c, in_y + ky, in_x + kx]
                            wt = weights[o, c, ky, kx]
                            # 64-bit product
                            prod = (np.int64(px) * np.int64(wt) + (1 << 15)) >> 16
                            accum += prod
                
                # Saturation to signed 32-bit
                res = np.clip(accum, INT32_MIN, INT32_MAX)
                # ReLU activation: clip negative to 0
                output_fm[o, out_y, out_x] = max(0, res)

    return output_fm


def maxpool2d_q1516(input_fm, pool_size=2, stride=2):
    """Bit-accurate 2x2 max-pooling with stride 2."""
    C, H, W = input_fm.shape
    H_out = (H - pool_size) // stride + 1
    W_out = (W - pool_size) // stride + 1

    pooled = np.zeros((C, H_out, W_out), dtype=np.int32)
    for c in range(C):
        for y in range(H_out):
            in_y = y * stride
            for x in range(W_out):
                in_x = x * stride
                window = input_fm[c, in_y:in_y + pool_size, in_x:in_x + pool_size]
                pooled[c, y, x] = np.max(window)

    return pooled


def generate_test_vectors(out_dir):
    """
    Generates deterministic test vectors and reference hex files for VHDL simulation.
    Uses a small test feature map (Cin=2, Cout=2, H=5, W=5) for fast cycle-accurate RTL verification.
    """
    os.makedirs(out_dir, exist_ok=True)
    np.random.seed(42)

    Cin, Cout, H, W = 2, 2, 5, 5
    Ky, Kx = 3, 3

    # Generate synthetic float inputs in realistic range [-1.0, 1.0]
    in_float = np.random.uniform(-1.0, 1.0, size=(Cin, H, W)).astype(np.float32)
    w_float = np.random.uniform(-0.5, 0.5, size=(Cout, Cin, Ky, Kx)).astype(np.float32)
    b_float = np.random.uniform(-0.1, 0.1, size=(Cout,)).astype(np.float32)

    # Quantize to Q15.16
    in_q16 = float_to_q1516(in_float)
    w_q16 = float_to_q1516(w_float)
    b_q16 = float_to_q1516(b_float)

    # Compute expected Golden Outputs
    out_conv_q16 = conv2d_q1516(in_q16, w_q16, b_q16, stride=1, padding=1)
    out_pool_q16 = maxpool2d_q1516(out_conv_q16, pool_size=2, stride=2)

    # Export to hex files (32-bit signed in 8-char hex format)
    def write_hex(filepath, arr_1d):
        with open(filepath, 'w') as f:
            for val in arr_1d:
                # Format as 32-bit unsigned hex representation of signed int32
                u32 = int(val) & 0xFFFFFFFF
                f.write(f"{u32:08X}\n")

    # Serialize weights as per Eq. 7
    w_flat = serialize_weights(w_q16)
    in_flat = in_q16.ravel(order='C')
    conv_flat = out_conv_q16.ravel(order='C')
    pool_flat = out_pool_q16.ravel(order='C')

    write_hex(os.path.join(out_dir, "input_pixels.hex"), in_flat)
    write_hex(os.path.join(out_dir, "weights.hex"), w_flat)
    write_hex(os.path.join(out_dir, "biases.hex"), b_q16)
    write_hex(os.path.join(out_dir, "expected_conv_relu.hex"), conv_flat)
    write_hex(os.path.join(out_dir, "expected_maxpool.hex"), pool_flat)

    print(f"[OK] Generated golden test vectors in: {out_dir}")
    print(f"     Inputs: {in_flat.shape[0]} words")
    print(f"     Weights: {w_flat.shape[0]} words")
    print(f"     Expected Conv+ReLU: {conv_flat.shape[0]} words (Shape: {out_conv_q16.shape})")
    print(f"     Expected MaxPool: {pool_flat.shape[0]} words (Shape: {out_pool_q16.shape})")


if __name__ == "__main__":
    test_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../tb/vectors")
    generate_test_vectors(test_dir)
