# alexnet-hw-accelerator-verilog

## Description

This project implements a custom hardware accelerator for the first convolutional layer of **AlexNet**, written in **Verilog RTL** and synthesized using the **Nangate 45nm Open Cell Library**. The design targets ASIC/FPGA platforms and demonstrates an end-to-end deep learning pipeline comprising:

- **2D convolution** (49 total convolutions with 11×11 filters)
- **ReLU activation**
- **Overlapping max pooling** with stride = 2 and overlap factor z = 3

The design operates on a reduced-size grayscale image (35×35), simulates streaming feature map data, and fully pipelines all components for throughput-optimized computation.

### Architecture Overview

- **6-stage pipeline**: Fetch → Multiply → Accumulate → Activate (ReLU) → Pool → Writeback
- **FSM controller**: Manages convolution state transitions, memory addressing, and timing
- **MAC units**: 11 multipliers + 11 adders compute one convolution column per clock cycle
- **Interleaved memory banks**: 11 memory modules store pixel rows for concurrent access
- **Filter memory**: Stores 49 filters, each split across 11 vertical slices (1 per column)
- **Address-driven pooling**: Lookup table determines when and where to pool outputs

### Performance & Validation

- Fully processes all convolutions in **547 clock cycles**
- Produces results that **match MATLAB model outputs exactly**
- Synthesis performed for multiple cycle targets (e.g., 1 kHz and 10 GHz)
- Full area reports and critical path timing available

This project was developed for **EEC 281: VLSI Digital Signal Processing** at UC Davis as a final digital design project.

---

## Key Features

- RTL implementation of 49 11x11 convolutions with stride of 4
- Pipelined ReLU activation module operating per cycle
- Overlapped max pooling (3×3 region, stride 2) via address-aware logic
- FSM-based sequencing across convolution passes
- 11 interleaved memory modules for pixel access
- Single-port memory access strategy for ASIC feasibility
- Verification against a MATLAB model for correctness
- Synthesized with realistic technology libraries (Nangate 45nm)

---
## Pipeline Block Diagram

<img width="754" alt="Screenshot 2025-04-10 at 8 05 30 PM" src="https://github.com/user-attachments/assets/19d5966c-263a-43f6-b607-5869f0596e46" />

---
## Project Files

```bash
.
├── main.v             # Top-level module coordinating all submodules
├── processor.v        # Main datapath unit including convolution, ReLU, and max pool
├── conv_col.v         # Column-wise convolution unit with MAC logic
├── fsm.v              # Finite State Machine controller
├── max_pool.v         # Max pooling unit triggered via address decoder
├── ReLU.v             # ReLU module (max(0, x)) for post-convolution activation
├── mem8_105.v         # 8-bit, 105-depth memory (3-row pixel storage)
├── mem8_140.v         # 8-bit, 140-depth memory (4-row pixel storage)
├── mem23_9.v          # 23-bit, 9-depth memory for max pool outputs
├── mem88_11.v         # 88-bit, 11-depth filter coefficient memory
└── processor_tb.v     # Testbench for top-level processor module
```

## Technologies Used

- Verilog HDL
- FSM Design & Pipelining
- ASIC Synthesis (Nangate 45nm Open Cell Library)
- MAC Units (Multiply-Accumulate)
- Memory Design (Single-Port SRAM Simulation)
- MATLAB Co-simulation and Verification
- Deep Learning Layer Architecture (AlexNet)

## Author

**Dalton Davis**  
Graduate Student – UC Davis 
EEC 281: VLSI Digital Signal Processing

## Tags (for resume/search optimization)

Verilog, Digital Design, ASIC, CNN Accelerator, RTL, MAC Unit, FSM Controller, Max Pooling, ReLU, AlexNet, Pipelining, Hardware Accelerator, Deep Learning Hardware
