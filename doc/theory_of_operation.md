# Theory Of Operation

## Overview

This block is the target-side complement to the `dshot_host` reference design.

It watches the shared DSHOT line, reconstructs the 16-bit command word from pulse widths, and optionally emits a bidirectional response that was preloaded over AXI-Lite.

The design intent is a single `60 MHz` `s_axi_aclk` domain. All timing registers and built-in presets are defined in `60 MHz` clock cycles.

## Receive Path

The target does not see the host's internal `pin_oe`, only the shared wire level on `pin_i`.

The input path uses a 5-sample oversampling filter inside the `60 MHz` clock domain. `pin_i` is first synchronized and then passed through a 5-sample majority filter before edge detection and pulse-width measurement.

Receive sequencing:

1. Detect a filtered line transition and treat the new level as the active pulse level.
2. Measure how long the line remains at that active level.
3. Compare the measured pulse width against `PULSE_THRESHOLD`.
4. Shift the decoded bit into a 16-bit frame register.
5. After 16 pulses, increment either `FRAME_COUNT_GOOD` or `FRAME_COUNT_CRC_ERROR` and push one RX FIFO entry.

If software clears `CONTROL.enable` while a transaction is in progress, the current receive/reply transaction is still allowed to finish. The cleared `enable` only prevents a new transaction from starting.

If the active polarity was low, the frame is treated as a bidirectional command.

Each RX FIFO entry carries:

```text
{frame_crc_error, frame_inverted, frame_valid, frame_word[15:0]}
```

Frames with a CRC mismatch are still counted and pushed into the RX FIFO, with `frame_crc_error` set.

## Reply Path

When all of these are true:

- the block is enabled
- `reply_enable` is set
- the decoded frame used inverted polarity
- the decoded frame CRC is correct

the target schedules a reply:

1. wait `REPLY_DELAY` clocks
2. GCR-encode the 16-bit `REPLY_PAYLOAD` register into a 21-bit reply symbol
3. drive each symbol bit for `REPLY_BIT` clocks on `pin_o` with `pin_oeb` asserted low

The transmitted reply word is exactly the AXI-loaded register contents.

`REPLY_PAYLOAD` is sampled when the received bidirectional command frame completes and the reply is scheduled. That sampled value is shifted out later after the turnaround delay, so writes to `REPLY_PAYLOAD` during the pending or active reply window only affect a later transaction.

## Interrupt Path

The AXI-Lite block exposes a `STATUS_MASK` register with the same bit positions as `STATUS`.

The top-level `irq` output is the reduction-OR of:

```text
STATUS & STATUS_MASK
```

This allows software to treat any live or sticky status bit as an interrupt source without adding a separate event controller.

`STATUS[4]` now reflects RX FIFO non-empty rather than per-frame valid metadata, since that metadata is carried in the FIFO entry itself.

## Line-Level Assumption

Shared-wire target decode is most reliable for bidirectional DSHOT because the host command starts with an explicit polarity inversion on the line.

Normal-polarity capture is still implemented, but it requires the external line bias to make the start of frame visible to the target.
