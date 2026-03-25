`timescale 1ns / 1ps

module dshot_target_rx_fifo_tb;

logic        clk;
logic        rst;
logic        clr_overflow;
logic        wr_en;
logic [17:0] wr_data;
logic        rd_en;
wire  [17:0] rd_data;
wire         empty;
wire         full;
wire  [5:0]  occupancy;
wire         overflow;
integer      idx;

dshot_target_rx_fifo #(
    .DATA_W(18),
    .DEPTH (32),
    .ADDR_W(5)
) dut (
    .clk         (clk),
    .rst         (rst),
    .clr_overflow(clr_overflow),
    .wr_en       (wr_en),
    .wr_data     (wr_data),
    .rd_en       (rd_en),
    .rd_data     (rd_data),
    .empty       (empty),
    .full        (full),
    .occupancy   (occupancy),
    .overflow    (overflow)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    rst          = 1'b1;
    clr_overflow = 1'b0;
    wr_en        = 1'b0;
    wr_data      = 18'h00000;
    rd_en        = 1'b0;

    repeat (4) @(posedge clk);
    rst = 1'b0;
    repeat (2) @(posedge clk);

    for (idx = 0; idx < 32; idx = idx + 1) begin
        @(posedge clk);
        wr_en   <= 1'b1;
        wr_data <= idx[17:0];
    end

    @(posedge clk);
    wr_en <= 1'b0;

    @(posedge clk);
    if (occupancy !== 6'd32 || !full || empty || overflow) begin
        $display("ERROR: FIFO fill mismatch. occupancy=%0d full=%0d empty=%0d overflow=%0d",
                 occupancy, full, empty, overflow);
        $fatal;
    end

    @(posedge clk);
    clr_overflow <= 1'b1;
    wr_en        <= 1'b1;
    wr_data      <= 18'h3FFFF;

    @(posedge clk);
    clr_overflow <= 1'b0;
    wr_en        <= 1'b0;

    @(posedge clk);
    if (!overflow) begin
        $display("ERROR: overflow was lost when clear and overflow happened together");
        $fatal;
    end
    if (occupancy !== 6'd32 || !full) begin
        $display("ERROR: FIFO state changed unexpectedly during clear-and-overflow race. occupancy=%0d full=%0d",
                 occupancy, full);
        $fatal;
    end

    @(posedge clk);
    clr_overflow <= 1'b1;

    @(posedge clk);
    clr_overflow <= 1'b0;

    @(posedge clk);
    if (overflow) begin
        $display("ERROR: overflow did not clear without a new drop");
        $fatal;
    end

    $display("PASS: RX FIFO preserves overflow on simultaneous clear-and-overflow");
    $finish;
end

endmodule
