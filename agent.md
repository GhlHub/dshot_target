# DSHOT Target Agent Notes

## Clock Assumption

The design intent is a single `60 MHz` `s_axi_aclk` domain.

- AXI-Lite register accesses run on `s_axi_aclk`
- command pulse-width decode runs on `s_axi_aclk`
- `pin_i` is synchronized and then observed through a 5-sample majority filter before edge detection and pulse-width measurement
- reply turnaround and reply bit timing are counted in `60 MHz` clock cycles
- `irq` is a registered AXI-clock-domain output generated from `STATUS & STATUS_MASK`
- top-level reply drive uses `pin_o` plus active-low output enable `pin_oeb`
- received commands are pushed into a 32-entry RX FIFO as `{frame_crc_error, frame_inverted, frame_valid, frame_word[15:0]}`
- `REPLY_PAYLOAD` is snapshotted when a valid bidirectional frame finishes decoding, not when reply drive begins
- AXI register `0x10[0]` drives top-level output `ext_dshot_mux_select`
- bidirectional frames with CRC errors are captured in the RX FIFO but do not trigger replies
- `CONTROL[31]` is a read-only mirror of the current top-level `irq`
- `CONTROL[5]` is `preserve_timing`
- when `CONTROL[5]=0`, any `CONTROL` write reloads `PULSE_THRESHOLD`, `REPLY_DELAY`, `REPLY_BIT`, and `FRAME_TIMEOUT` from the selected preset table entry
- when `CONTROL[5]=1`, `CONTROL` writes update `enable`, `reply_enable`, and `speed` without reloading those timing registers
- `CONTROL[4:2]` still reflects the last selected preset code when `CONTROL[5]=1`, but the live timing is whatever is currently programmed into the timing registers
- clearing `CONTROL.enable` stops new transactions from starting but lets an in-flight receive/reply complete
- only modify `PULSE_THRESHOLD`, `REPLY_DELAY`, `REPLY_BIT`, and `FRAME_TIMEOUT` while `STATUS[0]` `busy` is `0`
- modifying those timing registers while `busy=1` leads to unpredictable behavior for the in-flight receive or reply transaction
- `FRAME_COUNT_GOOD` tracks only good-CRC received frames
- `FRAME_COUNT_CRC_ERROR` tracks received frames whose CRC nibble did not match

Current preset examples:

- `DSHOT600`: `REPLY_BIT = 80`, about `1.33 us`
- `REPLY_DELAY = 1800`, exactly `30 us`

If the block is moved to a different AXI clock, the preset timing values in `rtl/dshot_target_axil_regs.v` need to be rescaled.
