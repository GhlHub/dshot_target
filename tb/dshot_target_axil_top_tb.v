`timescale 1ns / 1ps

module dshot_target_axil_top_tb;

localparam [7:0] ADDR_CONTROL         = 8'h00;
localparam [7:0] ADDR_STATUS          = 8'h04;
localparam [7:0] ADDR_STATUS_MASK     = 8'h08;
localparam [7:0] ADDR_REPLY_PAYLOAD   = 8'h0C;
localparam [7:0] ADDR_EXT_DSHOT_MUX_SELECT = 8'h10;
localparam [7:0] ADDR_PULSE_THRESHOLD = 8'h14;
localparam [7:0] ADDR_REPLY_DELAY     = 8'h18;
localparam [7:0] ADDR_REPLY_BIT       = 8'h1C;
localparam [7:0] ADDR_FRAME_TIMEOUT   = 8'h20;
localparam [7:0] ADDR_FRAME_COUNT_GOOD = 8'h24;
localparam [7:0] ADDR_REPLY_COUNT     = 8'h28;
localparam [7:0] ADDR_FRAME_COUNT_CRC_ERROR = 8'h2C;
localparam [7:0] ADDR_RX_FIFO_DATA    = 8'h30;
localparam [7:0] ADDR_RX_FIFO_STATUS  = 8'h34;
localparam [7:0] ADDR_RX_FIFO_OCCUPANCY = 8'h38;

localparam integer CONTROL_PRESERVE_TIMING_BIT = 5;
localparam [2:0] DSHOT_SPEED_300 = 3'd1;
localparam [2:0] DSHOT_SPEED_600 = 3'd2;

reg         clk;
reg         rst_n;
reg  [7:0]  s_axi_awaddr;
reg         s_axi_awvalid;
wire        s_axi_awready;
reg  [31:0] s_axi_wdata;
reg  [3:0]  s_axi_wstrb;
reg         s_axi_wvalid;
wire        s_axi_wready;
wire [1:0]  s_axi_bresp;
wire        s_axi_bvalid;
reg         s_axi_bready;
reg  [7:0]  s_axi_araddr;
reg         s_axi_arvalid;
wire        s_axi_arready;
wire [31:0] s_axi_rdata;
wire [1:0]  s_axi_rresp;
wire        s_axi_rvalid;
reg         s_axi_rready;
wire        pin_o;
wire        pin_oeb;
wire        ext_dshot_mux_select;
wire        pin_i;
wire        irq;

reg         host_drive_en;
reg         host_drive_val;
reg         idle_level;

reg [31:0] read_data_reg;
reg [11:0] tx12_value;
reg [15:0] normal_frame;
reg [15:0] bidir_frame;
reg [15:0] bidir_bad_crc_frame;
reg [15:0] reply_payload_word;
integer    idx;

wire shared_line;

dshot_target_axil_top dut(
    .s_axi_aclk   (clk),
    .s_axi_aresetn(rst_n),
    .s_axi_awaddr (s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata  (s_axi_wdata),
    .s_axi_wstrb  (s_axi_wstrb),
    .s_axi_wvalid (s_axi_wvalid),
    .s_axi_wready (s_axi_wready),
    .s_axi_bresp  (s_axi_bresp),
    .s_axi_bvalid (s_axi_bvalid),
    .s_axi_bready (s_axi_bready),
    .s_axi_araddr (s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata  (s_axi_rdata),
    .s_axi_rresp  (s_axi_rresp),
    .s_axi_rvalid (s_axi_rvalid),
    .s_axi_rready (s_axi_rready),
    .pin_i        (pin_i),
    .pin_o        (pin_o),
    .pin_oeb      (pin_oeb),
    .ext_dshot_mux_select(ext_dshot_mux_select),
    .irq          (irq)
);

assign shared_line = host_drive_en ? host_drive_val :
                     !pin_oeb ? pin_o :
                     idle_level;
assign pin_i = shared_line;

function [3:0] dshot_crc12;
    input [11:0] value12;
    begin
        dshot_crc12 = (value12 ^ (value12 >> 4) ^ (value12 >> 8)) & 4'hF;
    end
endfunction

function [3:0] dshot_crc12_inv;
    input [11:0] value12;
    begin
        dshot_crc12_inv = (~(value12 ^ (value12 >> 4) ^ (value12 >> 8))) & 4'hF;
    end
endfunction

function [4:0] encode_4b5b;
    input [3:0] nibble;
    begin
        case (nibble)
            4'h0: encode_4b5b = 5'h19;
            4'h1: encode_4b5b = 5'h1B;
            4'h2: encode_4b5b = 5'h12;
            4'h3: encode_4b5b = 5'h13;
            4'h4: encode_4b5b = 5'h1D;
            4'h5: encode_4b5b = 5'h15;
            4'h6: encode_4b5b = 5'h16;
            4'h7: encode_4b5b = 5'h17;
            4'h8: encode_4b5b = 5'h1A;
            4'h9: encode_4b5b = 5'h09;
            4'hA: encode_4b5b = 5'h0A;
            4'hB: encode_4b5b = 5'h0B;
            4'hC: encode_4b5b = 5'h1E;
            4'hD: encode_4b5b = 5'h0D;
            4'hE: encode_4b5b = 5'h0E;
            default: encode_4b5b = 5'h0F;
        endcase
    end
endfunction

function [20:0] encode_reply_symbol;
    input [15:0] payload_word;
    reg   [19:0] gcr_word;
    reg   [20:0] symbol_word;
    integer idx;
    begin
        gcr_word = {
            encode_4b5b(payload_word[15:12]),
            encode_4b5b(payload_word[11:8]),
            encode_4b5b(payload_word[7:4]),
            encode_4b5b(payload_word[3:0])
        };

        symbol_word[20] = 1'b0;
        for (idx = 19; idx >= 0; idx = idx - 1) begin
            if (gcr_word[idx]) begin
                symbol_word[idx] = ~symbol_word[idx + 1];
            end else begin
                symbol_word[idx] = symbol_word[idx + 1];
            end
        end

        encode_reply_symbol = symbol_word;
    end
endfunction

task axil_write;
    input [7:0] addr;
    input [31:0] data;
    reg aw_done;
    reg w_done;
    begin
        aw_done = 1'b0;
        w_done  = 1'b0;

        @(posedge clk);
        s_axi_awaddr  <= addr;
        s_axi_awvalid <= 1'b1;
        s_axi_wdata   <= data;
        s_axi_wstrb   <= 4'hF;
        s_axi_wvalid  <= 1'b1;

        while (!(aw_done && w_done)) begin
            @(posedge clk);
            if (s_axi_awvalid && s_axi_awready) begin
                s_axi_awvalid <= 1'b0;
                aw_done = 1'b1;
            end
            if (s_axi_wvalid && s_axi_wready) begin
                s_axi_wvalid <= 1'b0;
                w_done = 1'b1;
            end
        end

        s_axi_bready <= 1'b1;
        while (!s_axi_bvalid) begin
            @(posedge clk);
        end
        @(posedge clk);
        s_axi_bready <= 1'b0;
    end
endtask

task axil_read;
    input [7:0] addr;
    output [31:0] data;
    reg ar_done;
    begin
        ar_done = 1'b0;

        @(posedge clk);
        s_axi_araddr  <= addr;
        s_axi_arvalid <= 1'b1;

        while (!ar_done) begin
            @(posedge clk);
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_arvalid <= 1'b0;
                ar_done = 1'b1;
            end
        end

        s_axi_rready <= 1'b1;
        while (!s_axi_rvalid) begin
            @(posedge clk);
        end
        data = s_axi_rdata;
        @(posedge clk);
        s_axi_rready <= 1'b0;
    end
endtask

task host_send_frame;
    input [15:0] frame_word;
    input integer bidir_mode;
    input integer t0h_clks;
    input integer t1h_clks;
    input integer bit_clks;
    integer bit_idx;
    integer active_cycles;
    integer inactive_cycles;
    reg active_level;
    reg inactive_level;
    begin
        active_level   = bidir_mode ? 1'b0 : 1'b1;
        inactive_level = ~active_level;
        idle_level     = inactive_level;
        host_drive_en  = 1'b1;
        host_drive_val = inactive_level;

        repeat (4) @(posedge clk);
        for (bit_idx = 15; bit_idx >= 0; bit_idx = bit_idx - 1) begin
            active_cycles   = frame_word[bit_idx] ? t1h_clks : t0h_clks;
            inactive_cycles = bit_clks - active_cycles;

            host_drive_val = active_level;
            repeat (active_cycles) @(posedge clk);

            host_drive_val = inactive_level;
            repeat (inactive_cycles) @(posedge clk);
        end

        host_drive_en = 1'b0;
    end
endtask

task ensure_no_reply;
    input integer cycle_count;
    integer idx;
    begin
        for (idx = 0; idx < cycle_count; idx = idx + 1) begin
            @(posedge clk);
            if (!pin_oeb) begin
                $display("ERROR: unexpected target reply at cycle %0d", idx);
                $fatal;
            end
        end
    end
endtask

task ensure_no_irq_cycles;
    input integer cycle_count;
    integer idx;
    begin
        for (idx = 0; idx < cycle_count; idx = idx + 1) begin
            @(posedge clk);
            if (irq) begin
                $display("ERROR: unexpected IRQ at cycle %0d", idx);
                $fatal;
            end
        end
    end
endtask

task wait_for_irq_assert;
    integer watchdog;
    begin
        watchdog = 0;
        while (!irq && (watchdog < 10000)) begin
            @(posedge clk);
            watchdog = watchdog + 1;
        end
        if (!irq) begin
            $display("ERROR: timed out waiting for IRQ");
            $fatal;
        end
    end
endtask

task wait_for_reply_start;
    integer watchdog;
    begin
        watchdog = 0;
        while (pin_oeb && (watchdog < 10000)) begin
            @(posedge clk);
            watchdog = watchdog + 1;
        end
        if (pin_oeb) begin
            $display("ERROR: timed out waiting for target reply");
            $fatal;
        end
    end
endtask

task wait_for_status_bit_set;
    input integer bit_idx;
    reg [31:0] status_word;
    integer watchdog;
    begin
        status_word = 32'h0000_0000;
        watchdog = 0;
        while ((status_word[bit_idx] !== 1'b1) && (watchdog < 1000)) begin
            axil_read(ADDR_STATUS, status_word);
            if (status_word[bit_idx] !== 1'b1) begin
                watchdog = watchdog + 1;
            end
        end
        if (status_word[bit_idx] !== 1'b1) begin
            $display("ERROR: timed out waiting for STATUS[%0d] to assert", bit_idx);
            $fatal;
        end
    end
endtask

task check_reply_waveform;
    input [15:0] expected_payload;
    input integer reply_bit_clks;
    reg [20:0] expected_symbol;
    integer bit_idx;
    begin
        expected_symbol = encode_reply_symbol(expected_payload);
        wait_for_reply_start;

        for (bit_idx = 20; bit_idx >= 0; bit_idx = bit_idx - 1) begin
            if (shared_line !== expected_symbol[bit_idx]) begin
                $display("ERROR: reply bit mismatch at symbol bit %0d. exp=%0d got=%0d",
                         bit_idx, expected_symbol[bit_idx], shared_line);
                $fatal;
            end
            repeat (reply_bit_clks) @(posedge clk);
        end

        if (pin_oeb !== 1'b1) begin
            $display("ERROR: target kept driving after final reply bit");
            $fatal;
        end
    end
endtask

initial begin
    clk = 1'b0;
    forever #8.333 clk = ~clk;
end

initial begin
    s_axi_awaddr  = 8'h00;
    s_axi_awvalid = 1'b0;
    s_axi_wdata   = 32'h0000_0000;
    s_axi_wstrb   = 4'h0;
    s_axi_wvalid  = 1'b0;
    s_axi_bready  = 1'b0;
    s_axi_araddr  = 8'h00;
    s_axi_arvalid = 1'b0;
    s_axi_rready  = 1'b0;
    rst_n         = 1'b0;
    host_drive_en = 1'b0;
    host_drive_val = 1'b0;
    idle_level    = 1'b0;

    tx12_value         = 12'h345;
    normal_frame       = {tx12_value, dshot_crc12(tx12_value)};
    bidir_frame        = {tx12_value, dshot_crc12_inv(tx12_value)};
    bidir_bad_crc_frame = {tx12_value, dshot_crc12_inv(tx12_value) ^ 4'h1};
    reply_payload_word = 16'h2A5C;

    $dumpfile("log/dshot_target_axil_top_tb.vcd");
    $dumpvars(0, dshot_target_axil_top_tb);

    repeat (10) @(posedge clk);
    rst_n = 1'b1;
    repeat (10) @(posedge clk);

    axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b0, 1'b1});
    axil_write(ADDR_REPLY_PAYLOAD, {16'h0000, reply_payload_word});
    axil_write(ADDR_STATUS_MASK, 32'h0000_0010);
    axil_read(ADDR_EXT_DSHOT_MUX_SELECT, read_data_reg);
    if (read_data_reg !== 32'h0000_0000 || ext_dshot_mux_select !== 1'b0) begin
        $display("ERROR: ext_dshot_mux_select default mismatch. reg=%h pin=%b", read_data_reg, ext_dshot_mux_select);
        $fatal;
    end
    axil_write(ADDR_EXT_DSHOT_MUX_SELECT, 32'h0000_0001);
    axil_read(ADDR_EXT_DSHOT_MUX_SELECT, read_data_reg);
    if (read_data_reg !== 32'h0000_0001 || ext_dshot_mux_select !== 1'b1) begin
        $display("ERROR: ext_dshot_mux_select set mismatch. reg=%h pin=%b", read_data_reg, ext_dshot_mux_select);
        $fatal;
    end
    axil_write(ADDR_EXT_DSHOT_MUX_SELECT, 32'h0000_0000);
    axil_read(ADDR_EXT_DSHOT_MUX_SELECT, read_data_reg);
    if (read_data_reg !== 32'h0000_0000 || ext_dshot_mux_select !== 1'b0) begin
        $display("ERROR: ext_dshot_mux_select clear mismatch. reg=%h pin=%b", read_data_reg, ext_dshot_mux_select);
        $fatal;
    end
    ensure_no_irq_cycles(8);

    host_send_frame(normal_frame, 0, 38, 75, 100);
    repeat (64) @(posedge clk);
    if (!irq) begin
        $display("ERROR: IRQ did not assert for masked RX FIFO nonempty status");
        $fatal;
    end

    axil_read(ADDR_RX_FIFO_STATUS, read_data_reg);
    if (read_data_reg[5:0] !== 6'd1 || read_data_reg[6] !== 1'b0) begin
        $display("ERROR: RX FIFO status mismatch after normal frame. got=%h", read_data_reg);
        $fatal;
    end
    axil_read(ADDR_RX_FIFO_OCCUPANCY, read_data_reg);
    if (read_data_reg[5:0] !== 6'd1) begin
        $display("ERROR: RX FIFO occupancy mismatch after normal frame. got=%h", read_data_reg);
        $fatal;
    end

    axil_read(ADDR_STATUS, read_data_reg);
    if (read_data_reg[4] !== 1'b1) begin
        $display("ERROR: RX FIFO nonempty status bit not set after normal frame");
        $fatal;
    end
    if (read_data_reg[6] !== 1'b0) begin
        $display("ERROR: RX FIFO overflow set during normal frame");
        $fatal;
    end
    axil_read(ADDR_CONTROL, read_data_reg);
    if (read_data_reg[31] !== irq) begin
        $display("ERROR: CONTROL[31] did not mirror IRQ after normal frame");
        $fatal;
    end

    axil_read(ADDR_RX_FIFO_DATA, read_data_reg);
    if (read_data_reg[18:0] !== {1'b0, 1'b0, 1'b1, normal_frame}) begin
        $display("ERROR: RX FIFO data mismatch after normal frame. exp=%h got=%h",
                 {13'h0000, 1'b0, 1'b0, 1'b1, normal_frame}, read_data_reg);
        $fatal;
    end

    ensure_no_reply(2200);

    repeat (4) @(posedge clk);
    if (irq) begin
        $display("ERROR: IRQ did not clear after draining RX FIFO");
        $fatal;
    end

    axil_write(ADDR_PULSE_THRESHOLD, 32'd90);
    axil_write(ADDR_REPLY_DELAY, 32'd1234);
    axil_write(ADDR_REPLY_BIT, 32'd91);
    axil_write(ADDR_FRAME_TIMEOUT, 32'd3456);
    axil_write(ADDR_CONTROL, {25'h0, 1'b1, DSHOT_SPEED_300, 1'b0, 1'b1});

    axil_read(ADDR_CONTROL, read_data_reg);
    if (read_data_reg[CONTROL_PRESERVE_TIMING_BIT] !== 1'b1) begin
        $display("ERROR: CONTROL preserve-timing bit did not read back high");
        $fatal;
    end
    if (read_data_reg[4:2] !== DSHOT_SPEED_300) begin
        $display("ERROR: CONTROL speed readback mismatch with preserve-timing set. got=%h", read_data_reg);
        $fatal;
    end
    axil_read(ADDR_PULSE_THRESHOLD, read_data_reg);
    if (read_data_reg[15:0] !== 16'd90) begin
        $display("ERROR: pulse threshold changed despite preserve-timing control write. got=%0d", read_data_reg[15:0]);
        $fatal;
    end
    axil_read(ADDR_REPLY_DELAY, read_data_reg);
    if (read_data_reg[15:0] !== 16'd1234) begin
        $display("ERROR: reply delay changed despite preserve-timing control write. got=%0d", read_data_reg[15:0]);
        $fatal;
    end
    axil_read(ADDR_REPLY_BIT, read_data_reg);
    if (read_data_reg[15:0] !== 16'd91) begin
        $display("ERROR: reply bit timing changed despite preserve-timing control write. got=%0d", read_data_reg[15:0]);
        $fatal;
    end
    axil_read(ADDR_FRAME_TIMEOUT, read_data_reg);
    if (read_data_reg[15:0] !== 16'd3456) begin
        $display("ERROR: frame timeout changed despite preserve-timing control write. got=%0d", read_data_reg[15:0]);
        $fatal;
    end

    axil_write(ADDR_CONTROL, {25'h0, 1'b0, DSHOT_SPEED_600, 1'b0, 1'b1});
    axil_read(ADDR_CONTROL, read_data_reg);
    if (read_data_reg[CONTROL_PRESERVE_TIMING_BIT] !== 1'b0) begin
        $display("ERROR: CONTROL preserve-timing bit did not clear");
        $fatal;
    end
    axil_read(ADDR_PULSE_THRESHOLD, read_data_reg);
    if (read_data_reg[15:0] !== 16'd56) begin
        $display("ERROR: pulse threshold did not reload from preset when preserve-timing cleared. got=%0d", read_data_reg[15:0]);
        $fatal;
    end
    axil_read(ADDR_REPLY_DELAY, read_data_reg);
    if (read_data_reg[15:0] !== 16'd1800) begin
        $display("ERROR: reply delay did not reload from preset when preserve-timing cleared. got=%0d", read_data_reg[15:0]);
        $fatal;
    end
    axil_read(ADDR_REPLY_BIT, read_data_reg);
    if (read_data_reg[15:0] !== 16'd80) begin
        $display("ERROR: reply bit timing did not reload from preset when preserve-timing cleared. got=%0d", read_data_reg[15:0]);
        $fatal;
    end
    axil_read(ADDR_FRAME_TIMEOUT, read_data_reg);
    if (read_data_reg[15:0] !== 16'd2000) begin
        $display("ERROR: frame timeout did not reload from preset when preserve-timing cleared. got=%0d", read_data_reg[15:0]);
        $fatal;
    end

    axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b0, 1'b0});
    idle_level = 1'b1;
    repeat (32) @(posedge clk);
    axil_write(ADDR_STATUS, 32'h0000_0050);
    axil_write(ADDR_STATUS_MASK, 32'h0000_0020);
    axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b1, 1'b1});
    ensure_no_irq_cycles(8);

    fork
        begin
            check_reply_waveform(reply_payload_word, 80);
        end
        begin
            host_send_frame(bidir_frame, 1, 38, 75, 100);
        end
    join

    repeat (32) @(posedge clk);
    wait_for_irq_assert;

    axil_read(ADDR_STATUS, read_data_reg);
    if (read_data_reg[5] !== 1'b1) begin
        $display("ERROR: reply-sent sticky bit not set");
        $fatal;
    end
    if (read_data_reg[6] !== 1'b0) begin
        $display("ERROR: RX FIFO overflow bit unexpectedly set after bidirectional frame");
        $fatal;
    end

    axil_read(ADDR_STATUS_MASK, read_data_reg);
    if (read_data_reg !== 32'h0000_0020) begin
        $display("ERROR: status mask readback mismatch. exp=0x20 got=%h", read_data_reg);
        $fatal;
    end

    axil_read(ADDR_RX_FIFO_STATUS, read_data_reg);
    if (read_data_reg[5:0] !== 6'd1 || read_data_reg[6] !== 1'b0) begin
        $display("ERROR: RX FIFO status mismatch after bidirectional frame. got=%h", read_data_reg);
        $fatal;
    end
    axil_read(ADDR_RX_FIFO_OCCUPANCY, read_data_reg);
    if (read_data_reg[5:0] !== 6'd1) begin
        $display("ERROR: RX FIFO occupancy mismatch after bidirectional frame. got=%h", read_data_reg);
        $fatal;
    end

    axil_read(ADDR_RX_FIFO_DATA, read_data_reg);
    if (read_data_reg[18:0] !== {1'b0, 1'b1, 1'b1, bidir_frame}) begin
        $display("ERROR: RX FIFO data mismatch after bidirectional frame. exp=%h got=%h",
                 {13'h0000, 1'b0, 1'b1, 1'b1, bidir_frame}, read_data_reg);
        $fatal;
    end

    axil_read(ADDR_FRAME_COUNT_GOOD, read_data_reg);
    if (read_data_reg !== 32'd2) begin
        $display("ERROR: good frame count mismatch. exp=2 got=%0d", read_data_reg);
        $fatal;
    end

    axil_read(ADDR_REPLY_COUNT, read_data_reg);
    if (read_data_reg !== 32'd1) begin
        $display("ERROR: reply count mismatch. exp=1 got=%0d", read_data_reg);
        $fatal;
    end
    axil_read(ADDR_FRAME_COUNT_CRC_ERROR, read_data_reg);
    if (read_data_reg !== 32'd0) begin
        $display("ERROR: CRC-error frame count mismatch before bad-CRC frame. exp=0 got=%0d", read_data_reg);
        $fatal;
    end

    axil_write(ADDR_STATUS, 32'h0000_00A0);
    axil_write(ADDR_STATUS_MASK, 32'h0000_0000);
    ensure_no_irq_cycles(8);

    fork
        begin
            check_reply_waveform(reply_payload_word, 80);
        end
        begin
            host_send_frame(bidir_frame, 1, 38, 75, 100);
        end
        begin
            repeat (200) @(posedge clk);
            axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b1, 1'b0});
            axil_read(ADDR_CONTROL, read_data_reg);
            if (read_data_reg[31] !== irq) begin
                $display("ERROR: CONTROL[31] did not mirror IRQ during deferred disable");
                $fatal;
            end
        end
    join

    repeat (32) @(posedge clk);
    axil_read(ADDR_CONTROL, read_data_reg);
    if (read_data_reg[0] !== 1'b0) begin
        $display("ERROR: control enable readback did not clear after deferred-disable request");
        $fatal;
    end

    axil_read(ADDR_RX_FIFO_OCCUPANCY, read_data_reg);
    if (read_data_reg[5:0] !== 6'd1) begin
        $display("ERROR: RX FIFO occupancy mismatch after deferred-disable transaction. got=%h", read_data_reg);
        $fatal;
    end
    axil_read(ADDR_RX_FIFO_DATA, read_data_reg);
    if (read_data_reg[18:0] !== {1'b0, 1'b1, 1'b1, bidir_frame}) begin
        $display("ERROR: RX FIFO data mismatch after deferred-disable transaction. exp=%h got=%h",
                 {13'h0000, 1'b0, 1'b1, 1'b1, bidir_frame}, read_data_reg);
        $fatal;
    end

    axil_read(ADDR_FRAME_COUNT_GOOD, read_data_reg);
    if (read_data_reg !== 32'd3) begin
        $display("ERROR: good frame count mismatch after deferred-disable transaction. exp=3 got=%0d", read_data_reg);
        $fatal;
    end
    axil_read(ADDR_REPLY_COUNT, read_data_reg);
    if (read_data_reg !== 32'd2) begin
        $display("ERROR: reply count mismatch after deferred-disable transaction. exp=2 got=%0d", read_data_reg);
        $fatal;
    end

    host_send_frame(bidir_frame, 1, 38, 75, 100);
    repeat (64) @(posedge clk);
    ensure_no_reply(2200);

    axil_read(ADDR_RX_FIFO_OCCUPANCY, read_data_reg);
    if (read_data_reg[5:0] !== 6'd0) begin
        $display("ERROR: frame was captured after deferred disable took effect. occupancy=%0d", read_data_reg[5:0]);
        $fatal;
    end
    axil_read(ADDR_FRAME_COUNT_GOOD, read_data_reg);
    if (read_data_reg !== 32'd3) begin
        $display("ERROR: good frame count changed while disabled. got=%0d", read_data_reg);
        $fatal;
    end
    axil_read(ADDR_REPLY_COUNT, read_data_reg);
    if (read_data_reg !== 32'd2) begin
        $display("ERROR: reply count changed while disabled. got=%0d", read_data_reg);
        $fatal;
    end

    axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b1, 1'b1});
    ensure_no_irq_cycles(8);

    axil_write(ADDR_STATUS, 32'h0000_00A0);
    axil_write(ADDR_STATUS_MASK, 32'h0000_0000);
    ensure_no_irq_cycles(8);

    host_send_frame(bidir_frame, 1, 38, 75, 100);
    wait_for_status_bit_set(2);
    axil_read(ADDR_STATUS, read_data_reg);
    if (read_data_reg[2] !== 1'b1 || read_data_reg[3] !== 1'b0) begin
        $display("ERROR: expected reply_pending before deferred disable during pending. status=%h", read_data_reg);
        $fatal;
    end
    if (pin_oeb !== 1'b1) begin
        $display("ERROR: target started replying before pending-state disable");
        $fatal;
    end
    axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b1, 1'b0});
    check_reply_waveform(reply_payload_word, 80);

    repeat (32) @(posedge clk);
    axil_read(ADDR_CONTROL, read_data_reg);
    if (read_data_reg[0] !== 1'b0) begin
        $display("ERROR: control enable readback did not clear after reply-pending disable request");
        $fatal;
    end
    axil_read(ADDR_RX_FIFO_OCCUPANCY, read_data_reg);
    if (read_data_reg[5:0] !== 6'd1) begin
        $display("ERROR: RX FIFO occupancy mismatch after reply-pending disable transaction. got=%h", read_data_reg);
        $fatal;
    end
    axil_read(ADDR_RX_FIFO_DATA, read_data_reg);
    if (read_data_reg[18:0] !== {1'b0, 1'b1, 1'b1, bidir_frame}) begin
        $display("ERROR: RX FIFO data mismatch after reply-pending disable transaction. exp=%h got=%h",
                 {13'h0000, 1'b0, 1'b1, 1'b1, bidir_frame}, read_data_reg);
        $fatal;
    end
    axil_read(ADDR_FRAME_COUNT_GOOD, read_data_reg);
    if (read_data_reg !== 32'd4) begin
        $display("ERROR: good frame count mismatch after reply-pending disable transaction. exp=4 got=%0d", read_data_reg);
        $fatal;
    end
    axil_read(ADDR_REPLY_COUNT, read_data_reg);
    if (read_data_reg !== 32'd3) begin
        $display("ERROR: reply count mismatch after reply-pending disable transaction. exp=3 got=%0d", read_data_reg);
        $fatal;
    end

    host_send_frame(bidir_frame, 1, 38, 75, 100);
    repeat (64) @(posedge clk);
    ensure_no_reply(2200);
    axil_read(ADDR_RX_FIFO_OCCUPANCY, read_data_reg);
    if (read_data_reg[5:0] !== 6'd0) begin
        $display("ERROR: frame was captured after reply-pending disable took effect. occupancy=%0d", read_data_reg[5:0]);
        $fatal;
    end

    axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b1, 1'b1});
    ensure_no_irq_cycles(8);

    axil_write(ADDR_STATUS, 32'h0000_00A0);
    axil_write(ADDR_STATUS_MASK, 32'h0000_0000);
    ensure_no_irq_cycles(8);

    fork
        begin
            check_reply_waveform(reply_payload_word, 80);
        end
        begin
            host_send_frame(bidir_frame, 1, 38, 75, 100);
        end
        begin : disable_during_reply_active
            reg [31:0] status_word;
            wait_for_reply_start;
            repeat (20) @(posedge clk);
            if (pin_oeb !== 1'b0) begin
                $display("ERROR: target was not actively replying when active-state disable was issued");
                $fatal;
            end
            axil_read(ADDR_STATUS, status_word);
            if (status_word[3] !== 1'b1) begin
                $display("ERROR: STATUS[3] not set during reply-active disable. status=%h", status_word);
                $fatal;
            end
            axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b1, 1'b0});
        end
    join

    repeat (32) @(posedge clk);
    axil_read(ADDR_CONTROL, read_data_reg);
    if (read_data_reg[0] !== 1'b0) begin
        $display("ERROR: control enable readback did not clear after reply-active disable request");
        $fatal;
    end
    axil_read(ADDR_RX_FIFO_OCCUPANCY, read_data_reg);
    if (read_data_reg[5:0] !== 6'd1) begin
        $display("ERROR: RX FIFO occupancy mismatch after reply-active disable transaction. got=%h", read_data_reg);
        $fatal;
    end
    axil_read(ADDR_RX_FIFO_DATA, read_data_reg);
    if (read_data_reg[18:0] !== {1'b0, 1'b1, 1'b1, bidir_frame}) begin
        $display("ERROR: RX FIFO data mismatch after reply-active disable transaction. exp=%h got=%h",
                 {13'h0000, 1'b0, 1'b1, 1'b1, bidir_frame}, read_data_reg);
        $fatal;
    end
    axil_read(ADDR_FRAME_COUNT_GOOD, read_data_reg);
    if (read_data_reg !== 32'd5) begin
        $display("ERROR: good frame count mismatch after reply-active disable transaction. exp=5 got=%0d", read_data_reg);
        $fatal;
    end
    axil_read(ADDR_REPLY_COUNT, read_data_reg);
    if (read_data_reg !== 32'd4) begin
        $display("ERROR: reply count mismatch after reply-active disable transaction. exp=4 got=%0d", read_data_reg);
        $fatal;
    end

    host_send_frame(bidir_frame, 1, 38, 75, 100);
    repeat (64) @(posedge clk);
    ensure_no_reply(2200);
    axil_read(ADDR_RX_FIFO_OCCUPANCY, read_data_reg);
    if (read_data_reg[5:0] !== 6'd0) begin
        $display("ERROR: frame was captured after reply-active disable took effect. occupancy=%0d", read_data_reg[5:0]);
        $fatal;
    end

    axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b1, 1'b1});
    ensure_no_irq_cycles(8);

    axil_write(ADDR_STATUS, 32'h0000_0020);
    axil_write(ADDR_STATUS_MASK, 32'h0000_0010);
    ensure_no_irq_cycles(8);

    host_send_frame(bidir_bad_crc_frame, 1, 38, 75, 100);
    repeat (64) @(posedge clk);
    if (!irq) begin
        $display("ERROR: IRQ did not assert for masked RX FIFO nonempty after bad-CRC frame");
        $fatal;
    end

    axil_read(ADDR_RX_FIFO_STATUS, read_data_reg);
    if (read_data_reg[5:0] !== 6'd1 || read_data_reg[6] !== 1'b0) begin
        $display("ERROR: RX FIFO status mismatch after bad-CRC frame. got=%h", read_data_reg);
        $fatal;
    end

    axil_read(ADDR_RX_FIFO_DATA, read_data_reg);
    if (read_data_reg[18:0] !== {1'b1, 1'b1, 1'b1, bidir_bad_crc_frame}) begin
        $display("ERROR: RX FIFO data mismatch after bad-CRC frame. exp=%h got=%h",
                 {13'h0000, 1'b1, 1'b1, 1'b1, bidir_bad_crc_frame}, read_data_reg);
        $fatal;
    end

    ensure_no_reply(2200);

    axil_read(ADDR_REPLY_COUNT, read_data_reg);
    if (read_data_reg !== 32'd4) begin
        $display("ERROR: reply count changed after bad-CRC bidirectional frame. got=%0d", read_data_reg);
        $fatal;
    end

    axil_read(ADDR_FRAME_COUNT_GOOD, read_data_reg);
    if (read_data_reg !== 32'd5) begin
        $display("ERROR: good frame count mismatch after bad-CRC frame. exp=5 got=%0d", read_data_reg);
        $fatal;
    end
    axil_read(ADDR_FRAME_COUNT_CRC_ERROR, read_data_reg);
    if (read_data_reg !== 32'd1) begin
        $display("ERROR: CRC-error frame count mismatch after bad-CRC frame. exp=1 got=%0d", read_data_reg);
        $fatal;
    end

    repeat (2200) @(posedge clk);
    axil_read(ADDR_STATUS, read_data_reg);
    if (read_data_reg[7] !== 1'b0) begin
        $display("ERROR: false frame_timeout asserted after reply release or bad-CRC frame");
        $fatal;
    end

    repeat (4) @(posedge clk);
    if (irq) begin
        $display("ERROR: IRQ did not clear after draining bad-CRC frame from RX FIFO");
        $fatal;
    end

    axil_read(ADDR_CONTROL, read_data_reg);
    if (read_data_reg[31] !== 1'b0) begin
        $display("ERROR: CONTROL[31] stayed high after IRQ cleared");
        $fatal;
    end

begin : drain_fifo_loop
    while (1) begin
        axil_read(ADDR_RX_FIFO_OCCUPANCY, read_data_reg);
        if (read_data_reg[5:0] == 6'd0) begin
            disable drain_fifo_loop;
        end
        axil_read(ADDR_RX_FIFO_DATA, read_data_reg);
    end
end
    repeat (4) @(posedge clk);
    axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b0, 1'b0});
    host_drive_en = 1'b0;
    idle_level = 1'b0;
    repeat (8) @(posedge clk);
    axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b0, 1'b1});
    axil_write(ADDR_STATUS, 32'h0000_0040);
    axil_write(ADDR_STATUS_MASK, 32'h0000_0040);

    for (idx = 0; idx < 32; idx = idx + 1) begin
        host_send_frame(normal_frame, 0, 38, 75, 100);
        repeat (64) @(posedge clk);
        axil_read(ADDR_RX_FIFO_OCCUPANCY, read_data_reg);
        if (read_data_reg[5:0] !== (idx + 1)) begin
            $display("ERROR: RX FIFO occupancy mismatch while filling. exp=%0d got=%0d",
                     idx + 1, read_data_reg[5:0]);
            $fatal;
        end
    end

    axil_read(ADDR_RX_FIFO_STATUS, read_data_reg);
    if (read_data_reg[5:0] !== 6'd32 || read_data_reg[7] !== 1'b1 || read_data_reg[8] !== 1'b0) begin
        $display("ERROR: RX FIFO not full before overflow test. got=%h", read_data_reg);
        $fatal;
    end

    host_send_frame(normal_frame, 0, 38, 75, 100);
    repeat (64) @(posedge clk);

    axil_read(ADDR_STATUS, read_data_reg);
    if (read_data_reg[6] !== 1'b1) begin
        $display("ERROR: RX FIFO overflow flag did not set after overflow");
        $fatal;
    end
    if (!irq) begin
        $display("ERROR: IRQ did not assert for RX FIFO nonempty/overflow mask after overflow");
        $fatal;
    end

    axil_read(ADDR_RX_FIFO_STATUS, read_data_reg);
    if (read_data_reg[8] !== 1'b1) begin
        $display("ERROR: RX FIFO status overflow flag did not set after overflow");
        $fatal;
    end

    $display("PASS: dshot target captured FIFO-backed command frames, replied with AXI-loaded payload, generated masked IRQs, and flagged RX FIFO overflow");
    $finish;
end

endmodule
