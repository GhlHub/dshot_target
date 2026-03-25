# Register Map

## Summary

This register map assumes a single `60 MHz` `s_axi_aclk` domain.

All timing fields are expressed in `60 MHz` clock cycles.

| Addr | Name | Access | Description |
| --- | --- | --- | --- |
| `0x00` | `CONTROL` | `RW` | enable, reply-enable, and timing preset select |
| `0x04` | `STATUS` | `RW1C/R` | live state and sticky events |
| `0x08` | `STATUS_MASK` | `RW` | per-bit interrupt mask matching `STATUS` |
| `0x0C` | `REPLY_PAYLOAD` | `RW` | 16-bit reply word returned in bidirectional mode |
| `0x14` | `PULSE_THRESHOLD` | `RW` | pulse-width threshold for `0` vs `1` decode |
| `0x18` | `REPLY_DELAY` | `RW` | turnaround delay before the target starts replying |
| `0x1C` | `REPLY_BIT` | `RW` | clocks per reply symbol bit |
| `0x20` | `FRAME_TIMEOUT` | `RW` | timeout while receiving a partial command frame |
| `0x24` | `FRAME_COUNT_GOOD` | `R` | total received frames with good CRC |
| `0x28` | `REPLY_COUNT` | `R` | total transmitted replies |
| `0x2C` | `FRAME_COUNT_CRC_ERROR` | `R` | total received frames with CRC errors |
| `0x30` | `RX_FIFO_DATA` | `R(pop)` | pop one received command entry |
| `0x34` | `RX_FIFO_STATUS` | `R` | RX FIFO occupancy and flags |
| `0x38` | `RX_FIFO_OCCUPANCY` | `R` | RX FIFO occupancy only |

## `0x00` `CONTROL`

| Bits | Name | Description |
| --- | --- | --- |
| `[0]` | `enable` | enables frame capture and reply generation |
| `[1]` | `reply_enable` | allows replies for bidirectional frames |
| `[4:2]` | `speed` | loads built-in timing presets |
| `[5]` | `preserve_timing` | when `1`, `CONTROL` writes update control bits without reloading timing registers from the preset table |
| `[30:6]` | reserved | write `0` |
| `[31]` | `irq_state` | live, read-only mirror of the current top-level `irq` output |

`enable` behavior:

- writing `1` enables new frame capture immediately
- writing `0` blocks new transactions from starting
- if a receive or reply transaction is already in progress, that transaction is allowed to finish before the disable fully takes effect
- when `preserve_timing=0`, any `CONTROL` write reloads `PULSE_THRESHOLD`, `REPLY_DELAY`, `REPLY_BIT`, and `FRAME_TIMEOUT` from the selected preset
- when `preserve_timing=1`, `CONTROL` writes leave those timing registers unchanged
- `CONTROL[4:2]` always reads back the last selected preset code, even when `preserve_timing=1`
- when `preserve_timing=1`, `CONTROL[4:2]` should be treated as metadata only; the live timing is defined by `PULSE_THRESHOLD`, `REPLY_DELAY`, `REPLY_BIT`, and `FRAME_TIMEOUT`

Preset effects:

- `DSHOT150`: threshold `225`, reply bit `320`, frame timeout `8000`
- `DSHOT300`: threshold `113`, reply bit `160`, frame timeout `4000`
- `DSHOT600`: threshold `56`, reply bit `80`, frame timeout `2000`
- `DSHOT1200`: threshold `28`, reply bit `40`, frame timeout `1000`

`REPLY_DELAY` is reloaded to `1800` clocks for every preset, which is `30 us` at `60 MHz`.

Timing register safety:

- software should only modify `PULSE_THRESHOLD`, `REPLY_DELAY`, `REPLY_BIT`, and `FRAME_TIMEOUT` while `STATUS[0]` `busy` is `0`
- modifying those timing registers while `busy=1` leads to unpredictable behavior for the in-flight receive or reply transaction

## `0x04` `STATUS`

| Bits | Name | Description |
| --- | --- | --- |
| `[0]` | `busy` | target is receiving or replying |
| `[1]` | `rx_active` | command receive state is active |
| `[2]` | `reply_pending` | frame accepted, waiting for turnaround to expire |
| `[3]` | `reply_active` | target is currently driving the reply |
| `[4]` | `rx_fifo_nonempty` | live, set when the RX FIFO holds at least one entry |
| `[5]` | `reply_sent` | sticky, set when a reply finishes |
| `[6]` | `rx_fifo_overflow` | sticky, set when a received frame is dropped because the FIFO is full |
| `[7]` | `frame_timeout` | sticky, set when a partial frame times out |
| `[31:8]` | reserved | read as `0` |

Bits `[7]`, `[6]`, and `[5]` are write-one-to-clear. Bit `[4]` is live status and ignores writes.

## `0x08` `STATUS_MASK`

`STATUS_MASK` mirrors the `STATUS` bit layout.

If any bit is set in both `STATUS` and `STATUS_MASK`, the top-level `irq` output is asserted.

Example:

- setting `STATUS_MASK[4]` enables interrupts on RX FIFO non-empty
- setting `STATUS_MASK[5]` enables interrupts on sticky `reply_sent`
- setting `STATUS_MASK[0]` would make `irq` follow the live `busy` bit

## `0x30` `RX_FIFO_DATA`

Reading this register pops one 32-entry RX FIFO entry and returns:

```text
{13'h0, frame_crc_error, frame_inverted, frame_valid, frame_word[15:0]}
```

`frame_valid` is included in the entry format as requested and is `1` for every captured 16-pulse frame entry.

`frame_crc_error` is `1` when the received frame's CRC nibble does not match the expected DShot CRC for the decoded 12-bit payload.

If the FIFO is empty, the read returns `0`.

## `0x34` `RX_FIFO_STATUS`

| Bits | Name | Description |
| --- | --- | --- |
| `[5:0]` | `occupancy` | FIFO occupancy, `0..32` |
| `[6]` | `empty` | FIFO empty |
| `[7]` | `full` | FIFO full |
| `[8]` | `overflow` | sticky overflow indicator |
| `[31:9]` | reserved | read as `0` |

## `0x38` `RX_FIFO_OCCUPANCY`

| Bits | Name | Description |
| --- | --- | --- |
| `[5:0]` | `occupancy` | FIFO occupancy, `0..32` |
| `[31:6]` | reserved | read as `0` |

## `0x0C` `REPLY_PAYLOAD`

| Bits | Name | Description |
| --- | --- | --- |
| `[15:0]` | `reply_payload_word` | 16-bit word transmitted back in bidirectional mode |
| `[31:16]` | reserved | read as `0` |

The payload is GCR-encoded and differentially expanded for line transmission, but the register contents themselves are sent unchanged.

The design snapshots `REPLY_PAYLOAD` when a valid bidirectional command frame completes decode and a reply is scheduled. Updating the register while the reply is pending or already transmitting does not change the in-flight reply.

Bidirectional frames with a CRC error are still pushed into `RX_FIFO_DATA`, but they do not schedule a reply.
