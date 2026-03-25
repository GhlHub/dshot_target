`timescale 1ns / 1ps

module dshot_target_rx_fifo #(
    parameter integer DATA_W = 18,
    parameter integer DEPTH  = 32,
    parameter integer ADDR_W = 5
    )(
    input  wire              clk,
    input  wire              rst,
    input  wire              clr_overflow,
    input  wire              wr_en,
    input  wire [DATA_W-1:0] wr_data,
    input  wire              rd_en,
    output wire [DATA_W-1:0] rd_data,
    output wire              empty,
    output wire              full,
    output reg  [ADDR_W:0]   occupancy,
    output reg               overflow
    );

reg [DATA_W-1:0] mem [0:DEPTH-1];
reg [ADDR_W-1:0] wr_ptr;
reg [ADDR_W-1:0] rd_ptr;

wire do_read;
wire do_write;

assign empty    = (occupancy == {(ADDR_W+1){1'b0}});
assign full     = (occupancy == DEPTH[ADDR_W:0]);
assign do_read  = rd_en && !empty;
assign do_write = wr_en && (!full || do_read);
assign rd_data  = mem[rd_ptr];

always @(posedge clk) begin
    if (rst) begin
        wr_ptr    <= {ADDR_W{1'b0}};
        rd_ptr    <= {ADDR_W{1'b0}};
        occupancy <= {(ADDR_W+1){1'b0}};
        overflow  <= 1'b0;
    end else begin
        if (do_write) begin
            mem[wr_ptr] <= wr_data;
            wr_ptr <= wr_ptr + {{(ADDR_W-1){1'b0}}, 1'b1};
        end

        if (do_read) begin
            rd_ptr <= rd_ptr + {{(ADDR_W-1){1'b0}}, 1'b1};
        end

        case ({do_write, do_read})
            2'b10: occupancy <= occupancy + {{ADDR_W{1'b0}}, 1'b1};
            2'b01: occupancy <= occupancy - {{ADDR_W{1'b0}}, 1'b1};
            default: occupancy <= occupancy;
        endcase

        if (wr_en && full && !do_read) begin
            overflow <= 1'b1;
        end else if (clr_overflow) begin
            overflow <= 1'b0;
        end
    end
end

endmodule
