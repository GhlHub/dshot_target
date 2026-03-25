`timescale 1ns / 1ps

module dshot_target_core(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire        reply_enable,
    input  wire        pin_i,
    input  wire [15:0] reply_payload_word,
    input  wire [15:0] pulse_threshold_clks,
    input  wire [15:0] reply_delay_clks,
    input  wire [15:0] reply_bit_clks,
    input  wire [15:0] frame_timeout_clks,
    output wire        pin_o,
    output wire        pin_oe,
    output wire        busy,
    output wire        rx_active,
    output wire        reply_pending,
    output wire        reply_active,
    output reg         frame_valid,
    output reg         frame_inverted,
    output reg         frame_crc_error,
    output reg         frame_timeout,
    output reg         reply_sent,
    output reg [15:0]  frame_word,
    output reg [31:0]  frame_count_good,
    output reg [31:0]  frame_count_crc_error,
    output reg [31:0]  reply_count
    );

reg        pin_meta_reg;
reg        pin_sync_reg;
reg        pin_prev_reg;
reg        rx_active_reg;
reg        active_level_reg;
reg        frame_inverted_work_reg;
reg [15:0] active_count_reg;
reg [4:0]  bit_count_reg;
reg [15:0] frame_shift_reg;
reg [15:0] timeout_count_reg;

reg        reply_pending_reg;
reg        reply_active_reg;
reg [15:0] reply_delay_count_reg;
reg [15:0] reply_bit_count_reg;
reg [4:0]  reply_bits_left_reg;
reg [20:0] reply_shift_reg;
reg [1:0]  idle_stable_count_reg;

localparam [1:0] RX_ARM_COUNT_MAX = 2'd2;

wire line_edge;
wire active_to_inactive;
wire inactive_to_active;
wire decoded_bit;
wire [15:0] completed_frame_word;
wire [3:0]  completed_frame_crc;
wire        completed_frame_crc_error;

function [15:0] cycles_to_count;
    input [15:0] cycles;
    begin
        if (cycles <= 16'd1) begin
            cycles_to_count = 16'd0;
        end else begin
            cycles_to_count = cycles - 16'd1;
        end
    end
endfunction

function [3:0] dshot_crc12;
    input [11:0] value12;
    begin
        dshot_crc12 = (value12 ^ (value12 >> 4) ^ (value12 >> 8)) & 12'h00F;
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

assign line_edge          = (pin_sync_reg != pin_prev_reg);
assign active_to_inactive = rx_active_reg &&
                            (pin_prev_reg == active_level_reg) &&
                            (pin_sync_reg != active_level_reg);
assign inactive_to_active = rx_active_reg &&
                            (pin_prev_reg != active_level_reg) &&
                            (pin_sync_reg == active_level_reg);
assign decoded_bit        = (active_count_reg >= pulse_threshold_clks);
assign completed_frame_word = {frame_shift_reg[14:0], decoded_bit};
assign completed_frame_crc = frame_inverted_work_reg ?
                             (~dshot_crc12(completed_frame_word[15:4]) & 4'hF) :
                             dshot_crc12(completed_frame_word[15:4]);
assign completed_frame_crc_error = (completed_frame_word[3:0] != completed_frame_crc);

assign pin_o         = reply_active_reg ? reply_shift_reg[20] : 1'b1;
assign pin_oe        = reply_active_reg;
assign busy          = rx_active_reg | reply_pending_reg | reply_active_reg;
assign rx_active     = rx_active_reg;
assign reply_pending = reply_pending_reg;
assign reply_active  = reply_active_reg;

always @(posedge clk) begin
    if (rst) begin
        pin_meta_reg           <= 1'b1;
        pin_sync_reg           <= 1'b1;
        pin_prev_reg           <= 1'b1;
        rx_active_reg          <= 1'b0;
        active_level_reg       <= 1'b1;
        frame_inverted_work_reg <= 1'b0;
        active_count_reg       <= 16'h0000;
        bit_count_reg          <= 5'd0;
        frame_shift_reg        <= 16'h0000;
        timeout_count_reg      <= 16'h0000;
        reply_pending_reg      <= 1'b0;
        reply_active_reg       <= 1'b0;
        reply_delay_count_reg  <= 16'h0000;
        reply_bit_count_reg    <= 16'h0000;
        reply_bits_left_reg    <= 5'd0;
        reply_shift_reg        <= 21'h1F_FFFF;
        idle_stable_count_reg  <= 2'd0;
        frame_valid            <= 1'b0;
        frame_inverted         <= 1'b0;
        frame_crc_error        <= 1'b0;
        frame_timeout          <= 1'b0;
        reply_sent             <= 1'b0;
        frame_word             <= 16'h0000;
        frame_count_good       <= 32'h0000_0000;
        frame_count_crc_error  <= 32'h0000_0000;
        reply_count            <= 32'h0000_0000;
    end else begin
        pin_meta_reg  <= pin_i;
        pin_sync_reg  <= pin_meta_reg;
        pin_prev_reg  <= pin_sync_reg;
        frame_valid   <= 1'b0;
        frame_crc_error <= 1'b0;
        frame_timeout <= 1'b0;
        reply_sent    <= 1'b0;

        if (enable && !rx_active_reg && !reply_pending_reg && !reply_active_reg) begin
            if (line_edge) begin
                if (idle_stable_count_reg == RX_ARM_COUNT_MAX) begin
                    rx_active_reg           <= 1'b1;
                    active_level_reg        <= pin_sync_reg;
                    frame_inverted_work_reg <= (pin_sync_reg == 1'b0);
                    active_count_reg        <= 16'd1;
                    bit_count_reg           <= 5'd0;
                    frame_shift_reg         <= 16'h0000;
                    timeout_count_reg       <= frame_timeout_clks;
                end
                idle_stable_count_reg <= 2'd0;
            end else if (idle_stable_count_reg != RX_ARM_COUNT_MAX) begin
                idle_stable_count_reg <= idle_stable_count_reg + 2'd1;
            end
        end else begin
            if (!rx_active_reg && !reply_pending_reg && !reply_active_reg) begin
                idle_stable_count_reg <= 2'd0;
            end else begin
                idle_stable_count_reg <= 2'd0;

                if (rx_active_reg) begin
                    if (frame_timeout_clks != 16'h0000) begin
                        if (line_edge) begin
                            timeout_count_reg <= frame_timeout_clks;
                        end else if (timeout_count_reg != 16'h0000) begin
                            timeout_count_reg <= timeout_count_reg - 16'd1;
                        end else begin
                            rx_active_reg    <= 1'b0;
                            active_count_reg <= 16'h0000;
                            bit_count_reg    <= 5'd0;
                            frame_shift_reg  <= 16'h0000;
                            frame_timeout    <= 1'b1;
                        end
                    end

                    if (active_to_inactive) begin
                        if (bit_count_reg == 5'd15) begin
                            frame_word      <= completed_frame_word;
                            frame_inverted  <= frame_inverted_work_reg;
                            frame_crc_error <= completed_frame_crc_error;
                            frame_valid     <= 1'b1;
                            if (completed_frame_crc_error) begin
                                frame_count_crc_error <= frame_count_crc_error + 32'd1;
                            end else begin
                                frame_count_good <= frame_count_good + 32'd1;
                            end
                            rx_active_reg   <= 1'b0;

                            if (frame_inverted_work_reg && !completed_frame_crc_error && reply_enable) begin
                                reply_pending_reg     <= 1'b1;
                                reply_delay_count_reg <= cycles_to_count(reply_delay_clks);
                                reply_shift_reg       <= encode_reply_symbol(reply_payload_word);
                            end
                        end else begin
                            frame_shift_reg  <= {frame_shift_reg[14:0], decoded_bit};
                            bit_count_reg    <= bit_count_reg + 5'd1;
                        end
                        active_count_reg <= 16'h0000;
                    end else if (inactive_to_active) begin
                        active_count_reg <= 16'd1;
                    end else if (pin_sync_reg == active_level_reg) begin
                        active_count_reg <= active_count_reg + 16'd1;
                    end
                end

                if (reply_active_reg) begin
                    if (reply_bit_count_reg == 16'h0000) begin
                        if (reply_bits_left_reg == 5'd1) begin
                            reply_active_reg    <= 1'b0;
                            reply_bits_left_reg <= 5'd0;
                            reply_sent          <= 1'b1;
                            reply_count         <= reply_count + 32'd1;
                        end else begin
                            reply_shift_reg     <= {reply_shift_reg[19:0], 1'b1};
                            reply_bits_left_reg <= reply_bits_left_reg - 5'd1;
                            reply_bit_count_reg <= cycles_to_count(reply_bit_clks);
                        end
                    end else begin
                        reply_bit_count_reg <= reply_bit_count_reg - 16'd1;
                    end
                end else if (reply_pending_reg) begin
                    if (reply_delay_count_reg == 16'h0000) begin
                        reply_pending_reg   <= 1'b0;
                        reply_active_reg    <= 1'b1;
                        reply_bits_left_reg <= 5'd21;
                        reply_bit_count_reg <= cycles_to_count(reply_bit_clks);
                    end else begin
                        reply_delay_count_reg <= reply_delay_count_reg - 16'd1;
                    end
                end
            end
        end
    end
end

endmodule
