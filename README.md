# Parameterized Multiply-Accumulate (MAC) Unit

## Project Overview

This project presents the RTL design and functional verification of a parameterized **Multiply-Accumulate (MAC) Unit** using Verilog HDL and SystemVerilog.

A MAC unit performs multiplication followed by accumulation. It multiplies two input operands and adds the product to the accumulated value.

The fundamental operation is:

\[
ACC_{next} = ACC_{base} + (A \times B)
\]

The design supports configurable operand and accumulator widths, signed and unsigned multiplication modes, accumulator clearing, and a valid-ready handshake interface.

The repository includes the RTL implementation, a SystemVerilog constrained-random verification environment, simulation logs, waveform data, timing constraints, and a Cadence Genus synthesis script.

## Repository Highlights

- Parameterized MAC architecture.
- Configurable operand and accumulator widths.
- Signed and unsigned multiplication support.
- Valid-ready handshake interface.
- Accumulator clear control.
- SystemVerilog constrained-random verification.
- Scoreboard-based functional checking.
- 50,000 simulation transactions.
- Cadence Incisive simulation results.
- SDC timing constraints.
- Cadence Genus synthesis script.

## RTL Architecture

The primary RTL implementation is located in:

`rtl/mac_unit.v`

### Design Parameters

| Parameter | Default Value | Description |
|---|---:|---|
| `W` | 16 | Input operand width |
| `ACC_W` | 40 | Accumulator width |
| `SIGNED` | 1 | Selects signed or unsigned multiplication |

The default configuration uses 16-bit input operands and a 40-bit accumulator.

### Interface Signals

| Signal | Direction | Description |
|---|---|---|
| `clk` | Input | System clock |
| `rst_n` | Input | Active-low synchronous reset |
| `valid_in` | Input | Indicates valid input operands |
| `clear_acc` | Input | Clears the previous accumulated value before the next accepted operation |
| `a` | Input | First multiplication operand |
| `b` | Input | Second multiplication operand |
| `ready_out` | Input | Indicates downstream receiver readiness |
| `ready_in` | Output | Indicates that the MAC unit can accept input |
| `valid_out` | Output | Indicates that the output is valid |
| `result` | Output | Accumulated result |

### Functional Features

**1. Parameterized multiplication**

The design supports configurable operand widths through the `W` parameter.

**2. Signed and unsigned operation**

The `SIGNED` parameter selects the multiplication mode.

**3. Accumulator clear**

The `clear_acc` control allows the accumulated value to be cleared before processing a newly accepted input transaction.

**4. Valid-ready handshake**

The interface uses `valid_in`, `ready_in`, `valid_out`, and `ready_out` to coordinate data transfers.

**5. Output buffering**

The design includes a one-entry output buffer that holds the output while the downstream receiver is not ready.

## Functional Verification

The functional verification environment is implemented using SystemVerilog.

The verification-specific RTL and testbench are maintained separately from the primary RTL implementation.

### Verification Files

| File | Description |
|---|---|
| `verification/rtl/mac_unit.v` | Verification-specific MAC RTL implementation |
| `verification/testbench/mac_unit_tb.sv` | SystemVerilog testbench |
| `verification/simulation/run.sh` | Simulation execution script |

### Verification Configuration

The testbench instantiates the verification-specific MAC implementation with the following configuration:

| Parameter | Value |
|---|---:|
| `W` | 8 |
| `ACC_W` | 40 |
| `SIGNED` | 1 |
| Simulation transactions | 50,000 |

**Note:** The primary RTL and verification-specific RTL are separate source files with different parameter defaults and implementation details. The verification results reported below correspond to the verification-specific implementation and its testbench configuration, not automatically to every configuration of the primary RTL.

### Constrained-Random Testing

The testbench generates different categories of operand combinations, including:

- Bit-pattern combinations.
- Extreme positive operands.
- Extreme negative operands.
- Small positive operands.
- Small negative operands.
- Mid-range operands.

### Protocol Scenarios

The verification environment also exercises different interface conditions:

| Scenario | Description |
|---|---|
| Active Flow | Normal input and output transactions |
| Backpressure | Downstream receiver temporarily not ready |
| Starvation | No valid input transaction available |
| Dead Cycle | Idle transaction cycles |

### Scoreboard-Based Checking

A scoreboard is used to check the expected accumulated result and interface behavior against the DUT outputs.

The testbench monitors the transactions and reports pass/fail results during simulation.

## Simulation Results

The provided Cadence Incisive simulation log reports the following results:

<details>
<summary>Simulation summary</summary>

| Metric | Result |
|---|---:|
| Total simulation transactions | 50,000 |
| Passed | 50,000 |
| Failed | 0 |
| Final simulation time | 500,035 ns |
| Simulation status | PASS |

</details>

### Reported Operand Coverage

The following coverage values are reported for selected operand combinations:

| Operand Combination | Coverage |
|---|---:|
| Extreme Positive × Extreme Negative | 100% |
| Extreme Negative × Extreme Positive | 100% |
| Extreme Negative × Extreme Negative | 100% |
| Extreme Positive × Extreme Positive | 100% |
| Bit Patterns × Extreme Positive | 97.07% |
| Bit Patterns × Extreme Negative | 96.00% |
| Bit Patterns × Bit Patterns | 87.20% |

These values represent the reported coverage zones from the simulation log. They should not be interpreted as an overall functional coverage percentage.

### Simulation Evidence

Simulation outputs are included in the repository:

- `verification/simulation/logs/irun.log`
- `verification/simulation/logs/irun.history`
- `verification/simulation/waveforms/mac_unit_dump.vcd`

The VCD file can be opened using a compatible waveform viewer.

## Timing Constraints

Timing constraints are defined in:

`constraints/mac_unit.sdc`

### Clock and I/O Constraints

| Constraint | Value |
|---|---:|
| Clock period | 10 ns |
| Clock frequency | 100 MHz |
| Clock waveform | 0–5 ns |
| Input delay | 2.0 ns |
| Output delay | 0.1 ns |

The reset input is declared as a false path in the SDC file.

## Synthesis Flow

A Cadence Genus synthesis script is provided in:

`scripts/mac_unit.tcl`

The script includes the following stages:

1. Read the Verilog HDL source.
2. Elaborate the design.
3. Perform design checks.
4. Load timing constraints.
5. Run generic synthesis.
6. Perform technology mapping.
7. Generate synthesis and timing reports.
8. Write the mapped Verilog netlist.

### Technology Library

The supplied synthesis script references:

- Liberty library: `slow_vdd1v0_basicCells.lib`
- PDK directory: `/home/cad/VLSI2Lab/Digital/library/`

These paths are environment-specific and must be updated according to the available technology library and PDK installation.

**Important:** The repository contains the synthesis script, but does not include verified synthesis results or completed area, power, and timing measurements. These results should be added after successfully running the flow in the target environment.

## Repository Structure

```text
MAC-Unit-RTL-and-Functional-Verification/
│
├── README.md
│
├── rtl/
│   └── mac_unit.v
│
├── constraints/
│   └── mac_unit.sdc
│
├── scripts/
│   └── mac_unit.tcl
│
├── verification/
│   │
│   ├── rtl/
│   │   └── mac_unit.v
│   │
│   ├── testbench/
│   │   └── mac_unit_tb.sv
│   │
│   └── simulation/
│       ├── run.sh
│       │
│       ├── logs/
│       │   ├── irun.log
│       │   └── irun.history
│       │
│       └── waveforms/
│           └── mac_unit_dump.vcd
│
└── docs/
```

## Tools and Technologies

| Tool / Technology | Purpose |
|---|---|
| Verilog HDL | RTL design |
| SystemVerilog | Functional verification |
| Cadence Incisive | RTL simulation |
| Cadence Genus | Logic synthesis flow |
| Liberty | Standard-cell technology library |
| SDC | Timing constraint definition |

## Future Improvements

Potential improvements to the project include:

- Extend verification to additional operand widths.
- Verify both signed and unsigned operation modes.
- Add directed corner-case test scenarios.
- Expand functional coverage.
- Run synthesis using an available technology library.
- Evaluate area, timing, and power.
- Add synthesis reports and waveform screenshots.

