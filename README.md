# 256-Point NTT Accelerator

RTL implementation of a 256-point Number Theoretic Transform (NTT) accelerator for post-quantum cryptography, targeting the Kyber / ML-KEM parameter set.

The design implements an iterative, in-place NTT/INTT datapath using a time-multiplexed butterfly unit, dual-port coefficient memory, dedicated twiddle-factor ROM, and an FSM-based controller.

## Highlights

* 256-point NTT for `q = 3329`
* Forward NTT using Cooley–Tukey (CT)
* Inverse NTT using Gentleman–Sande (GS)
* In-place coefficient processing
* Single shared butterfly processing element
* Montgomery modular multiplication and reduction
* Dual-port `256 × 16-bit` coefficient RAM
* `128 × 16-bit` twiddle-factor ROM
* Deterministic control and fixed transform latency
* FPGA/ASIC-oriented RTL architecture

## Architecture

```text
                         ┌──────────────────────┐
                         │     top_module       │
                         │                      │
                         │   ┌──────────────┐   │
                         │   │     FSM      │   │
                         │   └──────┬───────┘   │
                         │          │           │
                         │   ┌──────▼───────┐   │
                         │   │   addr_gen   │   │
                         │   └──┬────────┬──┘   │
                         │      │        │      │
                         │      ▼        ▼      │
                         │     RAM     tw_rom   │
                         │      │        │      │
                         │      └───┬────┘      │
                         │          ▼           │
                         │      ┌─────────┐     │
                         │      │ bf_unit │     │
                         │      └────┬────┘     │
                         │           │          │
                         │           ▼          │
                         │      RAM write-back  │
                         └──────────────────────┘
```

The accelerator operates directly on coefficients stored in RAM. For each butterfly, the controller generates two coefficient addresses and the corresponding twiddle-factor address. The butterfly unit performs modular arithmetic and writes the results back to the same memory locations.

## Repository Structure

```text
.
├── rtl/
│   ├── top_module.v
│   ├── fsm.v
│   ├── addr_gen.v
│   ├── bf_unit.v
│   ├── tw_rom.v
│   └── ram.v
│
├── tb/
│   └── ...
│
├── docs/
│   └── design.md
│
└── README.md
```

## Module Overview

| Module       | Description                                                              |
| ------------ | ------------------------------------------------------------------------ |
| `top_module` | Top-level integration and host/RAM arbitration                           |
| `fsm`        | Controls NTT stages, butterfly sequencing, RAM writes and status signals |
| `addr_gen`   | Generates coefficient and twiddle-factor addresses                       |
| `bf_unit`    | Performs CT/GS butterfly operations and modular arithmetic               |
| `tw_rom`     | Stores Montgomery-domain twiddle factors                                 |
| `ram`        | Dual-port coefficient storage                                            |

## NTT Configuration

| Parameter           |           Value |
| ------------------- | --------------: |
| Transform size      |             256 |
| Modulus `q`         |            3329 |
| Coefficient width   |         16 bits |
| Stages              |               7 |
| Butterflies / stage |             128 |
| Total butterflies   |             896 |
| Cycles / butterfly  |               3 |
| Transform latency   |     2688 cycles |
| Forward algorithm   |    Cooley–Tukey |
| Inverse algorithm   | Gentleman–Sande |

## Butterfly Datapath

### Forward NTT

The forward datapath uses a Cooley–Tukey butterfly:

```text
t  = Montgomery(B × W)

A' = A + t (mod q)
B' = A - t (mod q)
```

### Inverse NTT

The inverse datapath uses a Gentleman–Sande butterfly:

```text
A' = A + B (mod q)

B' = Montgomery((A - B) × W)
```

## Arithmetic

The butterfly unit operates in the Montgomery domain to avoid direct modular division during multiplication.

Main parameters:

```text
q      = 3329
Q_INV  = 62209
R      = 2^16
```

Modular addition and subtraction use conditional correction to keep coefficients within the valid residue range.

## Control Flow

Each butterfly is processed in three FSM states:

```text
READ → CALC → WRITE
```

The complete transform consists of:

```text
7 stages
× 128 butterflies
× 3 cycles
= 2688 cycles
```

The same datapath is reused for both forward and inverse transforms, with the operation selected through the `mode` input.

## Interface

```text
clk       : system clock
rst       : reset
start     : start transform
mode      : 0 = forward NTT, 1 = inverse NTT

ext_we    : host RAM write enable
ext_addr  : host RAM address
ext_din   : host RAM write data
ext_dout  : host RAM read data

busy      : transform in progress
done      : transform complete
```

### Host Operation

Before starting a transform, the host loads the 256 coefficients through the external RAM interface.

```text
Host
  │
  ├── write coefficients
  │
  ├── assert start
  │
  ├── wait for busy/done
  │
  └── read transformed coefficients
```

External memory access is disabled while the NTT engine owns the RAM.


## Current Status

**RTL architecture:** Implemented

**Forward NTT datapath:** Implemented

**Inverse NTT datapath:** Implemented

**Address generation:** Verified

**Memory subsystem:** Implemented

**Twiddle ROM:** Implemented

**End-to-end ML-KEM validation:** In progress


