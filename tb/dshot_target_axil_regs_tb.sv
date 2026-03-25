`timescale 1ns / 1ps

module dshot_target_axil_regs_tb;

localparam [7:0] ADDR_STATUS = 8'h04;

logic        clk;
logic        s_axi_aresetn;
logic [7:0]  s_axi_awaddr;
logic        s_axi_awvalid;
wire         s_axi_awready;
logic [31:0] s_axi_wdata;
logic [3:0]  s_axi_wstrb;
logic        s_axi_wvalid;
wire         s_axi_wready;
wire  [1:0]  s_axi_bresp;
wire         s_axi_bvalid;
logic        s_axi_bready;
logic [7:0]  s_axi_araddr;
logic        s_axi_arvalid;
wire         s_axi_arready;
wire  [31:0] s_axi_rdata;
wire  [1:0]  s_axi_rresp;
wire         s_axi_rvalid;
logic        s_axi_rready;
logic        busy;
logic        rx_active;
logic        reply_pending;
logic        reply_active;
logic        frame_valid;
logic        frame_inverted;
logic        frame_crc_error;
logic        frame_timeout;
logic        reply_sent;
logic [15:0] frame_word;
logic [31:0] frame_count_good;
logic [31:0] frame_count_crc_error;
logic [31:0] reply_count;
wire         irq;
logic [31:0] read_data_reg;

dshot_target_axil_regs dut (
    .s_axi_aclk          (clk),
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
    .enable              (),
    .reply_enable        (),
    .reply_payload_word  (),
    .pulse_threshold_clks(),
    .reply_delay_clks    (),
    .reply_bit_clks      (),
    .frame_timeout_clks  (),
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

task automatic axil_read;
    input  logic [7:0]  addr;
    output logic [31:0] data;
    logic ar_done;
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

task automatic axil_write_with_events;
    input logic [31:0] status_clear_mask;
    input logic        pulse_reply_sent;
    input logic        pulse_frame_timeout;
    logic aw_done;
    logic w_done;
    begin
        aw_done = 1'b0;
        w_done  = 1'b0;

        @(posedge clk);
        s_axi_awaddr  <= ADDR_STATUS;
        s_axi_awvalid <= 1'b1;
        s_axi_wdata   <= status_clear_mask;
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

        reply_sent    <= pulse_reply_sent;
        frame_timeout <= pulse_frame_timeout;
        @(posedge clk);
        reply_sent    <= 1'b0;
        frame_timeout <= 1'b0;

        s_axi_bready <= 1'b1;
        while (!s_axi_bvalid) begin
            @(posedge clk);
        end
        @(posedge clk);
        s_axi_bready <= 1'b0;
    end
endtask

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    s_axi_aresetn = 1'b0;
    s_axi_awaddr  = 8'h00;
    s_axi_awvalid = 1'b0;
    s_axi_wdata   = 32'h0000_0000;
    s_axi_wstrb   = 4'h0;
    s_axi_wvalid  = 1'b0;
    s_axi_bready  = 1'b0;
    s_axi_araddr  = 8'h00;
    s_axi_arvalid = 1'b0;
    s_axi_rready  = 1'b0;
    busy          = 1'b0;
    rx_active     = 1'b0;
    reply_pending = 1'b0;
    reply_active  = 1'b0;
    frame_valid   = 1'b0;
    frame_inverted = 1'b0;
    frame_crc_error = 1'b0;
    frame_timeout = 1'b0;
    reply_sent    = 1'b0;
    frame_word    = 16'h0000;
    frame_count_good = 32'h0000_0000;
    frame_count_crc_error = 32'h0000_0000;
    reply_count   = 32'h0000_0000;

    repeat (4) @(posedge clk);
    s_axi_aresetn = 1'b1;
    repeat (2) @(posedge clk);

    reply_sent    <= 1'b1;
    frame_timeout <= 1'b1;
    @(posedge clk);
    reply_sent    <= 1'b0;
    frame_timeout <= 1'b0;
    @(posedge clk);

    axil_read(ADDR_STATUS, read_data_reg);
    if (read_data_reg[7:5] !== 3'b101) begin
        $display("ERROR: sticky status bits failed to set before W1C race test. got=%h", read_data_reg);
        $fatal;
    end

    axil_write_with_events(32'h0000_00A0, 1'b1, 1'b1);
    axil_read(ADDR_STATUS, read_data_reg);
    if (read_data_reg[7:5] !== 3'b101) begin
        $display("ERROR: sticky status bits were lost during simultaneous W1C and event. got=%h", read_data_reg);
        $fatal;
    end

    axil_write_with_events(32'h0000_00A0, 1'b0, 1'b0);
    axil_read(ADDR_STATUS, read_data_reg);
    if (read_data_reg[7:5] !== 3'b000) begin
        $display("ERROR: sticky status bits did not clear when no new event arrived. got=%h", read_data_reg);
        $fatal;
    end

    $display("PASS: AXI status sticky bits preserve simultaneous W1C and new events");
    $finish;
end

endmodule
