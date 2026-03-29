`timescale 1ns / 1ps

module dshot_target_axil_regs(
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    input  wire [7:0]  s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [7:0]  s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,
    output wire        enable,
    output wire        reply_enable,
    output wire [15:0] reply_payload_word,
    output wire        ext_dshot_mux_select,
    output wire [15:0] pulse_threshold_clks,
    output wire [15:0] reply_delay_clks,
    output wire [15:0] reply_bit_clks,
    output wire [15:0] frame_timeout_clks,
    input  wire        busy,
    input  wire        rx_active,
    input  wire        reply_pending,
    input  wire        reply_active,
    input  wire        frame_valid,
    input  wire        frame_inverted,
    input  wire        frame_crc_error,
    input  wire        frame_timeout,
    input  wire        reply_sent,
    input  wire [15:0] frame_word,
    input  wire [31:0] frame_count_good,
    input  wire [31:0] frame_count_crc_error,
    input  wire [31:0] reply_count,
    output wire        irq
    );

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

localparam integer CONTROL_ENABLE_BIT       = 0;
localparam integer CONTROL_REPLY_ENABLE_BIT = 1;
localparam integer CONTROL_SPEED_LSB        = 2;
localparam integer CONTROL_SPEED_MSB        = 4;
localparam integer CONTROL_PRESERVE_TIMING_BIT = 5;

localparam [2:0] DSHOT_SPEED_150  = 3'd0;
localparam [2:0] DSHOT_SPEED_300  = 3'd1;
localparam [2:0] DSHOT_SPEED_600  = 3'd2;
localparam [2:0] DSHOT_SPEED_1200 = 3'd3;

reg        awaddr_valid_reg;
reg [7:0]  awaddr_reg;
reg        wdata_valid_reg;
reg [31:0] wdata_reg;
reg [3:0]  wstrb_reg;
reg        bvalid_reg;
reg        araddr_valid_reg;
reg [7:0]  araddr_reg;
reg        rvalid_reg;
reg [31:0] rdata_reg;

reg        enable_reg;
reg        reply_enable_reg;
reg [2:0]  speed_reg;
reg        preserve_timing_reg;
reg [15:0] reply_payload_reg;
reg        ext_dshot_mux_select_reg;
reg [15:0] pulse_threshold_reg;
reg [15:0] reply_delay_reg;
reg [15:0] reply_bit_reg;
reg [15:0] frame_timeout_reg;
reg [31:0] status_mask_reg;
reg        sticky_reply_sent_reg;
reg        sticky_frame_timeout_reg;
reg        irq_reg;

wire       write_fire;
wire       read_fire;
wire [31:0] control_readback;
wire [31:0] status_readback;
wire [31:0] control_wdata;
wire [31:0] status_wdata;
wire [31:0] status_mask_wdata;
wire [31:0] reply_payload_wdata;
wire [31:0] ext_dshot_mux_select_wdata;
wire [31:0] pulse_threshold_wdata;
wire [31:0] reply_delay_wdata;
wire [31:0] reply_bit_wdata;
wire [31:0] frame_timeout_wdata;
wire [18:0] rx_fifo_wdata;
wire [18:0] rx_fifo_rd_data;
wire [5:0]  rx_fifo_occupancy;
wire        rx_fifo_empty;
wire        rx_fifo_full;
wire        rx_fifo_overflow;
wire        rx_fifo_pop;
wire        rx_fifo_overflow_clear;
wire        sticky_reply_sent_clear;
wire        sticky_frame_timeout_clear;

assign s_axi_awready = ~awaddr_valid_reg;
assign s_axi_wready  = ~wdata_valid_reg;
assign s_axi_bresp   = 2'b00;
assign s_axi_bvalid  = bvalid_reg;
assign s_axi_arready = ~araddr_valid_reg & ~rvalid_reg;
assign s_axi_rdata   = rdata_reg;
assign s_axi_rresp   = 2'b00;
assign s_axi_rvalid  = rvalid_reg;

assign write_fire = awaddr_valid_reg & wdata_valid_reg & ~bvalid_reg;
assign read_fire  = araddr_valid_reg & ~rvalid_reg;

assign enable              = enable_reg;
assign reply_enable        = reply_enable_reg;
assign reply_payload_word  = reply_payload_reg;
assign ext_dshot_mux_select = ext_dshot_mux_select_reg;
assign pulse_threshold_clks = pulse_threshold_reg;
assign reply_delay_clks    = reply_delay_reg;
assign reply_bit_clks      = reply_bit_reg;
assign frame_timeout_clks  = frame_timeout_reg;
assign irq                 = irq_reg;
assign rx_fifo_wdata       = {frame_crc_error, frame_inverted, frame_valid, frame_word};
assign rx_fifo_pop         = read_fire && (araddr_reg == ADDR_RX_FIFO_DATA) && !rx_fifo_empty;
assign rx_fifo_overflow_clear = write_fire && (awaddr_reg == ADDR_STATUS) && status_wdata[6];
assign sticky_reply_sent_clear = write_fire && (awaddr_reg == ADDR_STATUS) && status_wdata[5];
assign sticky_frame_timeout_clear = write_fire && (awaddr_reg == ADDR_STATUS) && status_wdata[7];

assign control_readback = {irq, 25'h0, preserve_timing_reg, speed_reg, reply_enable_reg, enable_reg};
assign status_readback  = {24'h000000,
                           sticky_frame_timeout_reg,
                           rx_fifo_overflow,
                           sticky_reply_sent_reg,
                           ~rx_fifo_empty,
                           reply_active,
                           reply_pending,
                           rx_active,
                           busy};

function [31:0] apply_wstrb32;
    input [31:0] old_value;
    input [31:0] new_value;
    input [3:0]  strobe;
    begin
        apply_wstrb32 = old_value;
        if (strobe[0]) apply_wstrb32[7:0]   = new_value[7:0];
        if (strobe[1]) apply_wstrb32[15:8]  = new_value[15:8];
        if (strobe[2]) apply_wstrb32[23:16] = new_value[23:16];
        if (strobe[3]) apply_wstrb32[31:24] = new_value[31:24];
    end
endfunction

assign control_wdata         = apply_wstrb32(control_readback, wdata_reg, wstrb_reg);
assign status_wdata          = apply_wstrb32(32'h0000_0000, wdata_reg, wstrb_reg);
assign status_mask_wdata     = apply_wstrb32(status_mask_reg, wdata_reg, wstrb_reg);
assign reply_payload_wdata   = apply_wstrb32({16'h0000, reply_payload_reg}, wdata_reg, wstrb_reg);
assign ext_dshot_mux_select_wdata = apply_wstrb32({31'h0000_0000, ext_dshot_mux_select_reg}, wdata_reg, wstrb_reg);
assign pulse_threshold_wdata = apply_wstrb32({16'h0000, pulse_threshold_reg}, wdata_reg, wstrb_reg);
assign reply_delay_wdata     = apply_wstrb32({16'h0000, reply_delay_reg}, wdata_reg, wstrb_reg);
assign reply_bit_wdata       = apply_wstrb32({16'h0000, reply_bit_reg}, wdata_reg, wstrb_reg);
assign frame_timeout_wdata   = apply_wstrb32({16'h0000, frame_timeout_reg}, wdata_reg, wstrb_reg);

dshot_target_rx_fifo #(
    .DATA_W(19),
    .DEPTH (32),
    .ADDR_W(5)
) u_dshot_target_rx_fifo (
    .clk      (s_axi_aclk),
    .rst      (~s_axi_aresetn),
    .clr_overflow(rx_fifo_overflow_clear),
    .wr_en    (frame_valid),
    .wr_data  (rx_fifo_wdata),
    .rd_en    (rx_fifo_pop),
    .rd_data  (rx_fifo_rd_data),
    .empty    (rx_fifo_empty),
    .full     (rx_fifo_full),
    .occupancy(rx_fifo_occupancy),
    .overflow (rx_fifo_overflow)
);

always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        awaddr_valid_reg          <= 1'b0;
        awaddr_reg                <= 8'h00;
        wdata_valid_reg           <= 1'b0;
        wdata_reg                 <= 32'h0000_0000;
        wstrb_reg                 <= 4'h0;
        bvalid_reg                <= 1'b0;
        araddr_valid_reg          <= 1'b0;
        araddr_reg                <= 8'h00;
        rvalid_reg                <= 1'b0;
        rdata_reg                 <= 32'h0000_0000;
        enable_reg                <= 1'b0;
        reply_enable_reg          <= 1'b0;
        speed_reg                 <= DSHOT_SPEED_600;
        preserve_timing_reg       <= 1'b0;
        reply_payload_reg         <= 16'h0000;
        ext_dshot_mux_select_reg  <= 1'b0;
        pulse_threshold_reg       <= 16'd56;
        reply_delay_reg           <= 16'd1800;
        reply_bit_reg             <= 16'd80;
        frame_timeout_reg         <= 16'd2000;
        status_mask_reg           <= 32'h0000_0000;
        sticky_reply_sent_reg     <= 1'b0;
        sticky_frame_timeout_reg  <= 1'b0;
        irq_reg                   <= 1'b0;
    end else begin
        if (s_axi_awvalid && s_axi_awready) begin
            awaddr_valid_reg <= 1'b1;
            awaddr_reg       <= s_axi_awaddr;
        end

        if (s_axi_wvalid && s_axi_wready) begin
            wdata_valid_reg <= 1'b1;
            wdata_reg       <= s_axi_wdata;
            wstrb_reg       <= s_axi_wstrb;
        end

        sticky_reply_sent_reg    <= (sticky_reply_sent_reg & ~sticky_reply_sent_clear) | reply_sent;
        sticky_frame_timeout_reg <= (sticky_frame_timeout_reg & ~sticky_frame_timeout_clear) | frame_timeout;
        irq_reg                  <= |(status_readback & status_mask_reg);

        if (write_fire) begin
            case (awaddr_reg)
                ADDR_CONTROL: begin
                    enable_reg       <= control_wdata[CONTROL_ENABLE_BIT];
                    reply_enable_reg <= control_wdata[CONTROL_REPLY_ENABLE_BIT];
                    speed_reg        <= control_wdata[CONTROL_SPEED_MSB:CONTROL_SPEED_LSB];
                    preserve_timing_reg <= control_wdata[CONTROL_PRESERVE_TIMING_BIT];

                    if (!control_wdata[CONTROL_PRESERVE_TIMING_BIT]) begin
                        case (control_wdata[CONTROL_SPEED_MSB:CONTROL_SPEED_LSB])
                            DSHOT_SPEED_150: begin
                                pulse_threshold_reg <= 16'd225;
                                reply_delay_reg     <= 16'd1800;
                                reply_bit_reg       <= 16'd320;
                                frame_timeout_reg   <= 16'd8000;
                            end
                            DSHOT_SPEED_300: begin
                                pulse_threshold_reg <= 16'd113;
                                reply_delay_reg     <= 16'd1800;
                                reply_bit_reg       <= 16'd160;
                                frame_timeout_reg   <= 16'd4000;
                            end
                            DSHOT_SPEED_600: begin
                                pulse_threshold_reg <= 16'd56;
                                reply_delay_reg     <= 16'd1800;
                                reply_bit_reg       <= 16'd80;
                                frame_timeout_reg   <= 16'd2000;
                            end
                            DSHOT_SPEED_1200: begin
                                pulse_threshold_reg <= 16'd28;
                                reply_delay_reg     <= 16'd1800;
                                reply_bit_reg       <= 16'd40;
                                frame_timeout_reg   <= 16'd1000;
                            end
                            default: begin
                                pulse_threshold_reg <= 16'd56;
                                reply_delay_reg     <= 16'd1800;
                                reply_bit_reg       <= 16'd80;
                                frame_timeout_reg   <= 16'd2000;
                            end
                        endcase
                    end
                end
                ADDR_STATUS: begin
                end
                ADDR_REPLY_PAYLOAD: begin
                    reply_payload_reg <= reply_payload_wdata[15:0];
                end
                ADDR_EXT_DSHOT_MUX_SELECT: begin
                    ext_dshot_mux_select_reg <= ext_dshot_mux_select_wdata[0];
                end
                ADDR_STATUS_MASK: begin
                    status_mask_reg <= status_mask_wdata;
                end
                ADDR_PULSE_THRESHOLD: begin
                    pulse_threshold_reg <= pulse_threshold_wdata[15:0];
                end
                ADDR_REPLY_DELAY: begin
                    reply_delay_reg <= reply_delay_wdata[15:0];
                end
                ADDR_REPLY_BIT: begin
                    reply_bit_reg <= reply_bit_wdata[15:0];
                end
                ADDR_FRAME_TIMEOUT: begin
                    frame_timeout_reg <= frame_timeout_wdata[15:0];
                end
                default: begin
                end
            endcase

            awaddr_valid_reg <= 1'b0;
            wdata_valid_reg  <= 1'b0;
            bvalid_reg       <= 1'b1;
        end

        if (bvalid_reg && s_axi_bready) begin
            bvalid_reg <= 1'b0;
        end

        if (s_axi_arvalid && s_axi_arready) begin
            araddr_valid_reg <= 1'b1;
            araddr_reg       <= s_axi_araddr;
        end

        if (read_fire) begin
            case (araddr_reg)
                ADDR_CONTROL: begin
                    rdata_reg <= control_readback;
                end
                ADDR_STATUS: begin
                    rdata_reg <= status_readback;
                end
                ADDR_REPLY_PAYLOAD: begin
                    rdata_reg <= {16'h0000, reply_payload_reg};
                end
                ADDR_EXT_DSHOT_MUX_SELECT: begin
                    rdata_reg <= {31'h0000_0000, ext_dshot_mux_select_reg};
                end
                ADDR_STATUS_MASK: begin
                    rdata_reg <= status_mask_reg;
                end
                ADDR_PULSE_THRESHOLD: begin
                    rdata_reg <= {16'h0000, pulse_threshold_reg};
                end
                ADDR_REPLY_DELAY: begin
                    rdata_reg <= {16'h0000, reply_delay_reg};
                end
                ADDR_REPLY_BIT: begin
                    rdata_reg <= {16'h0000, reply_bit_reg};
                end
                ADDR_FRAME_TIMEOUT: begin
                    rdata_reg <= {16'h0000, frame_timeout_reg};
                end
                ADDR_FRAME_COUNT_GOOD: begin
                    rdata_reg <= frame_count_good;
                end
                ADDR_REPLY_COUNT: begin
                    rdata_reg <= reply_count;
                end
                ADDR_FRAME_COUNT_CRC_ERROR: begin
                    rdata_reg <= frame_count_crc_error;
                end
                ADDR_RX_FIFO_DATA: begin
                    rdata_reg <= rx_fifo_empty ? 32'h0000_0000 : {13'h0000, rx_fifo_rd_data};
                end
                ADDR_RX_FIFO_STATUS: begin
                    rdata_reg <= {23'h000000, rx_fifo_overflow, rx_fifo_full, rx_fifo_empty, rx_fifo_occupancy};
                end
                ADDR_RX_FIFO_OCCUPANCY: begin
                    rdata_reg <= {26'h0000000, rx_fifo_occupancy};
                end
                default: begin
                    rdata_reg <= 32'h0000_0000;
                end
            endcase

            araddr_valid_reg <= 1'b0;
            rvalid_reg       <= 1'b1;
        end

        if (rvalid_reg && s_axi_rready) begin
            rvalid_reg <= 1'b0;
        end
    end
end

endmodule
