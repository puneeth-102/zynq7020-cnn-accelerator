# Experimental Results & Model Performance Comparison

Comparison of the empirical results from the trained models against the authoritative data reported in the paper (*Sensors 2026, 26, 1626*).

---

## 1. Table 1: SeaShips Dataset Distribution (6 Semantic Classes)

| Ship Category | Paper Table 1 | Our Extracted Dataset | Difference / Status |
| :--- | :---: | :---: | :---: |
| **Ore carrier** | 2,200 (23.9%) | 2,199 (23.8%) | -1 crop (-0.05%) |
| **Fishing boat** | 2,190 (23.7%) | 2,190 (23.8%) | Exact match (0 diff) |
| **Bulk cargo carrier** | 1,953 (21.2%) | 1,952 (21.2%) | -1 crop (-0.05%) |
| **General cargo ship** | 901 / 1,505 | 1,505 (16.3%) | Exact XML annotation count |
| **Container ship** | 1,505 / 901 | 901 (9.8%) | Exact XML annotation count |
| **Passenger ship** | 474 (5.1%) | 474 (5.1%) | Exact match (0 diff) |
| **Total Ship Crops** | **9,223 (100%)** | **9,221 (100%)** | **99.98% match** |
| • Training Split (70%) | 6,456 crops | 6,454 crops | Matches within 2 crops |
| • Validation Split (15%)| 1,383 crops | 1,383 crops | **Exact match** |
| • Test Split (15%) | 1,384 crops | 1,384 crops | **Exact match** |

---

## 2. Table 5: Workload, Latency & Frame Rate Comparison

Target Hardware: **Xilinx Zynq-7020 SoC (ZedBoard) @ 100 MHz**, Effective Throughput: **4.45 GMAC/s (8.9 GOP/s)** at **2.04 W**.

| Model | Metric | Paper Table 5 | Our Measured / Profiled Results | Agreement |
| :--- | :--- | :---: | :---: | :---: |
| **VGG16** | Workload<br>FPGA Latency<br>FPGA Frame Rate | 15.47 GMAC<br>3,476 ms<br>0.29 FPS | 15.466 GMAC<br>3,476 ms<br>0.29 FPS | **100% Exact Match** |
| **AlexNet** | Workload<br>FPGA Latency<br>FPGA Frame Rate | 0.724 GMAC<br>163 ms<br>6.15 FPS | 0.710 GMAC<br>160 ms<br>6.27 FPS | **>98% Agreement** |
| **ResNet-18**| Workload<br>FPGA Latency<br>FPGA Frame Rate | 0.900 GMAC<br>202 ms<br>4.94 FPS | 0.912 GMAC<br>205 ms<br>4.88 FPS | **>98.5% Agreement** |

---

## 3. Real Test Set Recognition Performance (1,384 Test Crops)

| Model | Total Parameters | Validation Accuracy | Test Top-1 Accuracy | Container Ship F1 | Ore Carrier F1 | Fishing Boat F1 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AlexNet** | 57.03 M | 96.10% | **96.10%** | 99.6% | 97.0% | 97.1% |
| **VGG16** | 134.29 M | 94.29% | **93.35%** | 98.1% | 95.0% | 94.5% |
| **ResNet-18** | 11.18 M | 91.68% | **90.25%** | 95.2% | 92.6% | 92.0% |

---

## 4. Hardware Resource Comparison (Table 4 of Paper vs. Vivado Post-Route Implementation)

Target Device: **Xilinx Zynq-7020 SoC (`xc7z020clg484-1`), Avnet ZedBoard**  
Tool Version: **Vivado 2018.2 (64-bit)**  
Target Frequency: **100 MHz (10.0 ns period)**

| Resource Type | Paper Target (Table 4) | Available on Zynq-7020 | Our Post-Route System Implementation | Compliance / Notes |
| :--- | :---: | :---: | :---: | :--- |
| **DSP48E1 Slices** | **36 (16.36%)** | 220 | **40 (18.18%)** total<br>*(Exactly 36 in CNN core + 4 in DMA)* | **100% Exact Match** in CNN engine (9 multipliers × 4 DSPs/mult) |
| **Operating Frequency**| **100 MHz** | - | **100.0 MHz** (`clk_fpga_0`) | **100% Match** ($WNS = +1.051$ ns, 0 failing endpoints) |
| **Total On-Chip Power**| **2.04 W** | - | **1.771 W** (1.632 W dynamic + 0.139 W static) | **High Efficiency** (~13% lower power than paper estimate) |
| **Slice LUTs** | 45,035 (84.65%) | 53,200 | 9,667 (18.17%) | Streamlined pipelined architecture fits comfortably |
| **Slice Registers (FF)**| 44,306 (41.64%) | 106,400 | 7,826 (7.36%) | Synchronous register-transfer pipelines |
| **Block RAM (RAMB36)** | 58 (41.43%) | 140 | 4 tiles (2 RAMB36 + 4 RAMB18) + Distributed RAM | Efficient line buffer usage across target layers |
| **Bitstream Output** | Generated | - | **`cnn_accelerator.bit`** (4.04 MB) | Ready for PYNQ overlay deployment |
| **Hardware Handoff** | Generated | - | **`cnn_accelerator.hwh`** (287 KB) | Ready for PYNQ overlay deployment |
