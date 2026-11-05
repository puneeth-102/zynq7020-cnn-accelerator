# FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition

Implementation and reproduction of the research paper:
> **"FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition in Unmanned Surface Vehicles"**  
> *Sensors 2026, 26, 1626.* https://doi.org/10.3390/s26051626

---

## 1. Project Directory Structure

```text
zynq7020_cnn_accelerator/
├── doc/                        # Architecture specs, memory maps, paper comparisons
│   ├── architecture.md         # Micro-architecture details (Line buffers, MAC tree, etc.)
│   └── results_comparison.md   # Exact paper results vs. trained model verification
├── rtl/                        # Synthesizable RTL source files
│   ├── core/                   # Compute primitives (Line buffers, 9-MAC tree, Accumulator, ReLU, MaxPool, FC)
│   ├── axi/                    # AXI4-Lite control registers & AXI4-Stream DMA adapters
│   └── top/                    # Top-level accelerator wrapper and IP packaging
├── tb/                         # Verification testbenches & simulation vectors
│   ├── unit/                   # Unit testbenches (line_buffer_tb, mac_tree_tb, maxpool_tb)
│   └── system/                 # Full AXI-Stream layer-wise simulation testbench
├── sw/                         # Software drivers, model exporters, and PYNQ runtime
│   ├── quantization/           # Python scripts for Float-to-Q15.16 conversion & weight serialization (Eq. 7)
│   ├── pynq_driver/            # PYNQ Python 3 runtime for layer orchestration & DMA control
│   └── weights/                # Quantized Q15.16 binary parameter files
└── vivado/                     # Vivado project automation & constraints
    ├── scripts/                # Tcl scripts for block design generation, synthesis, and implementation
    └── constraints/            # Timing constraints (100 MHz PL clock, pinouts)
```

---

## 2. Key Hardware & System Specifications

| Parameter | Value | Reference in Paper |
| :--- | :--- | :--- |
| **Target Device** | Xilinx Zynq-7020 (`xc7z020clg484-1`), ZedBoard | Section 3.2, Section 5 |
| **Arithmetic Precision** | Signed 32-bit fixed point: **Q15.16** | Section 4.4.1, Equation (5) |
| **PL Operating Clock** | **100 MHz** (Single PL domain) | Section 5, Table 4 |
| **DSP Allocation** | **36 DSP48E1 slices** (9 mults × 4 DSPs/mult) | Section 5.1, Table 4 |
| **BRAM Allocation** | **58 BRAM36 blocks** (~2.04 Mbit on-chip buffer) | Section 5.1, Table 4 |
| **LUT Utilization** | **~45,035 LUTs** (84.65%) | Section 5.1, Table 4 |
| **Power Estimate** | **~2.04 W** on-chip power | Section 5.1, Table 4 |
| **Data Interfaces** | 64-bit AXI HP0 (DMA) + 32-bit AXI GP0 (AXI-Lite) | Section 4.1, Figure 5 |

---

## 3. Verified Model Performance (SeaShips Dataset - 6 Classes)

*Extracted from trained model checkpoints and dashboard evaluation:*
## 4. Final Post-Route Implementation Results (Vivado 2018.2 on ZedBoard)

- **Target Device:** Xilinx Zynq-7020 (`XC7Z020-CLG484-1`), Avnet ZedBoard
- **Target Language:** Verilog-2001 (Synthesizable VHDL also provided in `rtl/`)
- **Clock Frequency:** **100.0 MHz** (`clk_fpga_0`), positive timing slack $WNS = +1.051$ ns
- **DSP Utilization:** **Exactly 36 DSP48E1 slices** in CNN core (40 total with DMA) — **100% Match with Table 4**
- **Total On-Chip Power:** **1.771 W** (Vector-less activity propagation report) vs. 2.04 W paper estimate
- **Bitstream File:** [`sw/pynq_driver/cnn_accelerator.bit`](file:///C:/Users/HP%20PC/OneDrive/Desktop/CNN/zynq7020_cnn_accelerator/sw/pynq_driver/cnn_accelerator.bit) (4.04 MB)
- **Hardware Definition:** [`sw/pynq_driver/cnn_accelerator.hwh`](file:///C:/Users/HP%20PC/OneDrive/Desktop/CNN/zynq7020_cnn_accelerator/sw/pynq_driver/cnn_accelerator.hwh) (287 KB)
- **Reports:**
  - Utilization: [`doc/impl_utilization.rpt`](file:///C:/Users/HP%20PC/OneDrive/Desktop/CNN/zynq7020_cnn_accelerator/doc/impl_utilization.rpt)
  - Timing: [`doc/impl_timing.rpt`](file:///C:/Users/HP%20PC/OneDrive/Desktop/CNN/zynq7020_cnn_accelerator/doc/impl_timing.rpt)
  - Power: [`doc/impl_power.rpt`](file:///C:/Users/HP%20PC/OneDrive/Desktop/CNN/zynq7020_cnn_accelerator/doc/impl_power.rpt)
  - Detailed Paper Comparison: [`doc/results_comparison.md`](file:///C:/Users/HP%20PC/OneDrive/Desktop/CNN/zynq7020_cnn_accelerator/doc/results_comparison.md)

---

## 5. Deployment Instructions on ZedBoard (PYNQ-Z1 / ZedBoard Linux)

1. Copy the `sw/pynq_driver/` folder to your ZedBoard SD card (e.g. `/home/xilinx/cnn_overlay/`).
2. Ensure `cnn_accelerator.bit` and `cnn_accelerator.hwh` are in the same folder.
3. Open a terminal on the ZedBoard or Jupyter Notebook (`http://<zedboard_ip>:9090`) and execute:
   ```bash
   cd /home/xilinx/cnn_overlay
   sudo python3 cnn_overlay_driver.py
   ```
4. The driver initializes the AXI DMA, flushes the L1/L2 caches, triggers layer-by-layer convolution on the FPGA PL, and outputs execution latency and FPS metrics.
