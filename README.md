# Systolic_array
This is a personal project of mine in an attempt to better understand custom datapaths and power consumption. It is written in SystemVerilog and is highly parameterized
## 1. Architecture Overview
![Top Level Architecture](Systolic_Img.png)
This design follows the Weight Stationary architecture and contains:
**Systolic Grid**: A parameterized mesh of Processing Elements performing Multiply-Accumulate (MAC) operations. The weights are pre-loaded vertically using a countdown Address Generation Unit, while activation streams march horizontally.
**Skew & Deskew Units:** Register structures that offset the input and the corresponding output , so that the resulting matrix is the correct one.
* **Memory Subsystem:** Three independent synchronous SRAM banks (`bank_a` for weights, `bank_b` for activations, `bank_c` for outputs) managed via dedicated AGUs and controlled by a FSM.
