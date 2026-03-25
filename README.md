# DSHOT Target

AXI-Lite controlled DSHOT target IP that listens for host command frames and, when the host uses bidirectional DSHOT, replies with a preloaded 16-bit message from an AXI-Lite register.

## Clocking

The design intent is a single `60 MHz` `s_axi_aclk` domain.

All AXI-Lite logic, frame decoding, and reply timing use that same clock. The built-in timing presets and the documented clock-count values assume `60 MHz`.

## Contents

- `rtl/`: synthesizable RTL
- `tb/`: self-checking simulation
- `doc/`: register map and design notes

## Top-Level Module

- `rtl/dshot_target_axil_top.v`

External interfaces:

- AXI-Lite slave
- DSHOT pin triplet: `pin_i`, `pin_o`, `pin_oe`
- interrupt output: `irq`

The target monitors `pin_i` for an incoming DSHOT frame. If the decoded frame was sent with inverted polarity, the target treats it as a bidirectional command and emits a 21-bit GCR-coded reply on `pin_o`/`pin_oe`.

## Features

- AXI-Lite register for the reply payload word
- Configurable pulse-width threshold for command decode
- Configurable reply turnaround and reply bit timing
- 32-entry RX FIFO carrying `{frame_crc_error, frame_inverted, frame_valid, frame_word[15:0]}`
- Sticky status for reply-sent, RX FIFO overflow, and frame-timeout
- Status-mask-based interrupt output
- Frame and reply counters

## Register Highlights

- `0x00`: control
  - bit `0`: target enable
  - bit `1`: bidirectional reply enable
  - bits `[4:2]`: preset select
  - bit `5`: preserve timing registers on `CONTROL` writes
- `0x08`: status mask
- `0x0C`: reply payload
- `0x14`: pulse-width threshold
- `0x18`: reply delay
- `0x1C`: reply bit clocks
- `0x20`: frame timeout
- `0x24`: good-frame count
- `0x28`: reply count
- `0x2C`: CRC-error frame count
- `0x30`: RX FIFO data pop
- `0x34`: RX FIFO status
- `0x38`: RX FIFO occupancy

## Notes

- The reply payload is transmitted exactly as loaded in `REPLY_PAYLOAD`; the target does not modify the 16-bit word before GCR encoding it.
- `REPLY_PAYLOAD` is snapshotted when a valid bidirectional host frame finishes decoding. Changes made while the reply is pending or actively transmitting only affect a later reply.
- Bidirectional frames with a CRC error are still captured into the RX FIFO, but they do not trigger a reply.
- Clearing `CONTROL.enable` does not abort an in-flight receive or reply; it blocks new transactions and lets the current one complete.
- `CONTROL[5]` prevents `CONTROL` writes from reloading `PULSE_THRESHOLD`, `REPLY_DELAY`, `REPLY_BIT`, and `FRAME_TIMEOUT` from the preset table.
- `CONTROL[4:2]` still reads back the last selected preset code when `CONTROL[5]=1`, but the live timing comes from the timing registers, not from that preset code.
- `irq` is asserted when any masked `STATUS` bit is high.
- `CONTROL[31]` is a read-only mirror of the current top-level `irq` signal.
- Received command metadata now lives in the RX FIFO rather than in sticky `STATUS` bits.
- Modifying `PULSE_THRESHOLD`, `REPLY_DELAY`, `REPLY_BIT`, or `FRAME_TIMEOUT` while `STATUS.busy=1` leads to unpredictable behavior for the in-flight transaction. Software should only change those registers while idle.
- Reliable shared-wire operation is centered on bidirectional DSHOT, where the host command is polarity-inverted and the start edge is explicit on the line.
- Normal-polarity frame capture depends on the external line idle bias providing a visible start transition.

## Simulation

Example:

```sh
cd /raid/work/dshot_target
mkdir -p log
iverilog -g2012 -o log/dshot_target_axil_top_tb.out rtl/*.v tb/dshot_target_axil_top_tb.v
vvp log/dshot_target_axil_top_tb.out
```
