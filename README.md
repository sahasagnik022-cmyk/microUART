readme_content = """# Parameterizable 8-Bit UART Design and Verification

![Verilog](https://img.shields.io/badge/Language-Verilog-blue.svg)
![Simulator](https://img.shields.io/badge/Simulator-QuestaSim-green.svg)
![Coverage](https://img.shields.io/badge/Coverage-100%25-brightgreen.svg)

## 📌 Project Overview
This repository contains the RTL design and comprehensive verification environment for a parameterizable, full-duplex Universal Asynchronous Receiver-Transmitter (UART) written in Verilog. 

The primary goal of this project was to design a robust serial communication core capable of handling physical-layer anomalies (like electrical glitches and framing errors) and to architect a self-checking testbench that achieves **100% Code and FSM coverage** using a Golden Reference Model.

## ✨ Key Features
- **Highly Parameterizable:** Easily configure Data Width (`WIDTH`), System Clock Frequency (`CLK_FREQ`), and Baud Rate (`BAUD_RATE`) without modifying the internal RTL.
- **Full-Duplex Operation:** Independent Transmitter (TX) and Receiver (RX) blocks capable of simultaneous operation.
- **Advanced RX Oversampling:** The receiver utilizes center-sampling logic to filter out transient voltage noise and cleanly discard corrupted frames.
- **Pipelined TX:** Seamless back-to-back byte transmission without wasting idle cycles between frames.
- **Hardware Safe-States:** Fully mapped FSMs with unreachable `default` states defined for synthesis safety.

## 🏗️ Architecture

### Design Under Test (DUT)
1. **`baud_gen.v`**: A mathematical clock divider that generates a unified baud tick from the high-speed system clock, keeping the TX and RX FSMs synchronized.
2. **`uart_tx.v`**: A 4-state FSM (IDLE, START, DATA, STOP) that functions as a parallel-to-serial converter.
3. **`uart_rx.v`**: An advanced serial-to-parallel converter utilizing center-sampling to guarantee data integrity.
4. **`top.v` (or `MicroUART.v`)**: The structural wrapper that cleanly instantiates the submodules.

### Verification Environment
The testbench (`tb_master_uart.v`) is architected to professional standards:
- **Golden Reference Model (`uart_ref.v`):** A custom "Stop-and-Wait" data integrity checker that operates independently of protocol flags.
- **Physical Loopback MUX:** Dynamically routes TX output into RX input for closed-loop integrity checks, or disconnects them for manual fault injection.
- **Parallel Threading:** Utilizes `fork...join` blocks to prevent delta-cycle race conditions and perfectly synchronize the driver with the DUT latency.

## 🧪 Verification & Coverage
The testbench bombards the DUT with 100+ automated random payloads alongside targeted corner-case tasks. 

**Simulated Corner Cases:**
- Asynchronous mid-flight resets (`START -> IDLE` recovery).
- False Start Bit injection (`rx_start_glitch`).
- Stop Bit corruption / Framing Errors.

**Coverage Results (QuestaSim):**
- **Statement Coverage:** 100.00%
- **Branch Coverage:** 100.00%
- **Toggle Coverage:** 100.00%
- **FSM State & Transition Coverage:** 100.00%

*(Note: Unreachable post-synthesis `default` states were gracefully excluded via `// coverage off` pragmas).*
