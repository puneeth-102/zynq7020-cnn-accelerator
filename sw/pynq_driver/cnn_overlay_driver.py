"""
PYNQ Python 3 Runtime Driver for CNN Accelerator on Zynq-7020
Reproduces Section 4.4, Section 4.5 & Table 6 of:
"FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
(Sensors 2026, 26, 1626)
"""

import time
import numpy as np

# In target environment: from pynq import Overlay, allocate, MMIO
try:
    from pynq import Overlay, allocate, MMIO
except ImportError:
    # Allow running on host/PC for testing and dry-runs
    Overlay = None
    allocate = None
    MMIO = None

# Register Offset Definitions (matching axi_lite_regs.vhd)
REG_CTRL_STATUS = 0x00  # [0]: start, [1]: done, [2]: reset
REG_IMG_DIMS    = 0x04  # [15:0]: W, [31:16]: H
REG_CHANNELS    = 0x08  # [15:0]: Cin, [31:16]: Cout
REG_CONFIG      = 0x0C  # [0]: pad_en, [1]: pool_en, [2]: relu_en, [4:3]: mode
REG_BASE_STATUS = 0x10


class ZynqCNNAccelerator:
    def __init__(self, bitstream_path="cnn_accelerator.bit", ctrl_base_addr=0x43C00000):
        if Overlay is not None:
            self.overlay = Overlay(bitstream_path)
            self.dma = self.overlay.axi_dma_0
            self.ctrl = MMIO(ctrl_base_addr, 0x1000)
            print("[INFO] Zynq CNN Accelerator Overlay Loaded successfully.")
        else:
            self.overlay = None
            self.dma = None
            self.ctrl = None
            print("[WARN] Running in simulation/mock mode (PYNQ package not detected).")

    def reset_accelerator(self):
        """Issues a soft-reset to the PL datapath."""
        if self.ctrl:
            self.ctrl.write(REG_CTRL_STATUS, 0x04) # Assert reset
            time.sleep(0.001)
            self.ctrl.write(REG_CTRL_STATUS, 0x00) # Release reset

    def configure_layer(self, width, height, cin, cout, pad_en=True, pool_en=False, relu_en=True, mode=0):
        """
        Programs layer hyperparameters into PL AXI-Lite control registers.
        mode: 0 = Conv, 1 = Pool, 2 = FC
        """
        if not self.ctrl:
            return

        dims_val = (height << 16) | (width & 0xFFFF)
        ch_val   = (cout << 16) | (cin & 0xFFFF)
        cfg_val  = ((mode & 0x03) << 3) | (int(relu_en) << 2) | (int(pool_en) << 1) | int(pad_en)

        self.ctrl.write(REG_IMG_DIMS, dims_val)
        self.ctrl.write(REG_CHANNELS, ch_val)
        self.ctrl.write(REG_CONFIG, cfg_val)

    def execute_layer(self, fm_in_buf, fm_out_buf):
        """
        Executes a layer with DMA streaming over 64-bit HP0, cache maintenance,
        and high-resolution latency profiling.
        """
        if self.dma is None:
            return 0.0

        t_start = time.perf_counter()

        # 1. CPU Cache Maintenance: Flush input buffers to DDR
        fm_in_buf.flush()

        # 2. Start accelerator core
        self.ctrl.write(REG_CTRL_STATUS, 0x01)

        # 3. Trigger AXI DMA transfers (MM2S & S2MM)
        self.dma.recvchannel.transfer(fm_out_buf)
        self.dma.sendchannel.transfer(fm_in_buf)

        # 4. Wait for DMA completion
        self.dma.sendchannel.wait()
        self.dma.recvchannel.wait()

        # 5. CPU Cache Invalidation: Invalidate output buffer to read back fresh DDR results
        fm_out_buf.invalidate()

        t_end = time.perf_counter()
        return (t_end - t_start) * 1000.0 # Return latency in ms

    def run_inference_alexnet(self, input_image_q16):
        """
        Runs layer-by-layer AlexNet inference matching Table 5 & Table 6.
        """
        print("[RUN] Starting AlexNet inference on Zynq-7020 PL...")
        total_time_ms = 0.0

        # Layer 1 to 5 dimensions for AlexNet
        layers = [
            {"name": "conv1", "w": 224, "h": 224, "cin": 3,   "cout": 96,  "pad": True,  "pool": True},
            {"name": "conv2", "w": 55,  "h": 55,  "cin": 96,  "cout": 256, "pad": True,  "pool": True},
            {"name": "conv3", "w": 27,  "h": 27,  "cin": 256, "cout": 384, "pad": True,  "pool": False},
            {"name": "conv4", "w": 13,  "h": 13,  "cin": 384, "cout": 384, "pad": True,  "pool": False},
            {"name": "conv5", "w": 13,  "h": 13,  "cin": 384, "cout": 256, "pad": True,  "pool": True},
        ]

        # Allocate ping-pong buffers in contiguous DDR memory (CMA)
        buf_a = allocate(shape=(224 * 224 * 4,), dtype=np.int32)
        buf_b = allocate(shape=(224 * 224 * 4,), dtype=np.int32)

        buf_a[:input_image_q16.size] = input_image_q16.ravel()

        cur_in, cur_out = buf_a, buf_b
        for l in layers:
            self.configure_layer(l["w"], l["h"], l["cin"], l["cout"],
                                 pad_en=l["pad"], pool_en=l["pool"], relu_en=True)
            lat_ms = self.execute_layer(cur_in, cur_out)
            total_time_ms += lat_ms
            # Ping-pong swap
            cur_in, cur_out = cur_out, cur_in

        print(f"[DONE] End-to-end PL inference latency: {total_time_ms:.2f} ms")
        return total_time_ms


if __name__ == "__main__":
    print("Zynq-7020 CNN Accelerator Driver Module Ready.")
