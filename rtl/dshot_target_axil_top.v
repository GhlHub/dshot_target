`timescale 1ns / 1ps

module dshot_target_axil_top(
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
    input  wire        pin_i,
    output wire        pin_o,
    output wire        pin_oe,
    output wire        irq
    );

wire        enable;
wire        reply_enable;
wire [15:0] reply_payload_word;
wire [15:0] pulse_threshold_clks;
wire [15:0] reply_delay_clks;
wire [15:0] reply_bit_clks;
wire [15:0] frame_timeout_clks;
wire        busy;
wire        rx_active;
wire        reply_pending;
wire        reply_active;
wire        frame_valid;
wire        frame_inverted;
wire        frame_crc_error;
wire        frame_timeout;
wire        reply_sent;
wire [15:0] frame_word;
wire [31:0] frame_count_good;
wire [31:0] frame_count_crc_error;
wire [31:0] reply_count;

dshot_target_axil_regs u_dshot_target_axil_regs(
    .s_axi_aclk          (s_axi_aclk),
    .s_axi_aresetn       (s_axi_aresetn),
    .s_axi_awaddr        (s_axi_awaddr),
    .s_axi_awvalid       (s_axi_awvalid),
    .s_axi_awready       (s_axi_awready),
    .s_axi_wdata         (s_axi_wdata),
    .s_axi_wstrb         (s_axi_wstrb),
    .s_axi_wvalid        (s_axi_wvalid),
    .s_axi_wready        (s_axi_wready),
    .s_axi_bresp         (s_axi_bresp),
    .s_axi_bvalid        (s_axi_bvalid),
    .s_axi_bready        (s_axi_bready),
    .s_axi_araddr        (s_axi_araddr),
    .s_axi_arvalid       (s_axi_arvalid),
    .s_axi_arready       (s_axi_arready),
    .s_axi_rdata         (s_axi_rdata),
    .s_axi_rresp         (s_axi_rresp),
    .s_axi_rvalid        (s_axi_rvalid),
    .s_axi_rready        (s_axi_rready),
    .enable              (enable),
    .reply_enable        (reply_enable),
    .reply_payload_word  (reply_payload_word),
    .pulse_threshold_clks(pulse_threshold_clks),
    .reply_delay_clks    (reply_delay_clks),
    .reply_bit_clks      (reply_bit_clks),
    .frame_timeout_clks  (frame_timeout_clks),
    .busy                (busy),
    .rx_active           (rx_active),
    .reply_pending       (reply_pending),
    .reply_active        (reply_active),
    .frame_valid         (frame_valid),
    .frame_inverted      (frame_inverted),
    .frame_crc_error     (frame_crc_error),
    .frame_timeout       (frame_timeout),
    .reply_sent          (reply_sent),
    .frame_word          (frame_word),
    .frame_count_good    (frame_count_good),
    .frame_count_crc_error(frame_count_crc_error),
    .reply_count         (reply_count),
    .irq                 (irq)
);

dshot_target_core u_dshot_target_core(
    .clk                 (s_axi_aclk),
    .rst                 (~s_axi_aresetn),
    .enable              (enable),
    .reply_enable        (reply_enable),
    .pin_i               (pin_i),
    .reply_payload_word  (reply_payload_word),
    .pulse_threshold_clks(pulse_threshold_clks),
    .reply_delay_clks    (reply_delay_clks),
    .reply_bit_clks      (reply_bit_clks),
    .frame_timeout_clks  (frame_timeout_clks),
    .pin_o               (pin_o),
    .pin_oe              (pin_oe),
    .busy                (busy),
    .rx_active           (rx_active),
    .reply_pending       (reply_pending),
    .reply_active        (reply_active),
    .frame_valid         (frame_valid),
    .frame_inverted      (frame_inverted),
    .frame_crc_error     (frame_crc_error),
    .frame_timeout       (frame_timeout),
    .reply_sent          (reply_sent),
    .frame_word          (frame_word),
    .frame_count_good    (frame_count_good),
    .frame_count_crc_error(frame_count_crc_error),
    .reply_count         (reply_count)
);

endmodule
