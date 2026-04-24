module uart_decoder(
    input               clk,
    input               rst_n,
    input               uart_rx_sig,
    input       [15:0]  baud_div,

    output  reg [7:0]   uart_byte,
    output  reg         uart_byte_valid
);

localparam S_IDLE  = 2'd0;
localparam S_START = 2'd1;
localparam S_DATA  = 2'd2;
localparam S_STOP  = 2'd3;

reg [1:0]  state;
reg [15:0] baud_cnt;
reg [2:0]  bit_cnt;
reg [7:0]  rx_shift;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state           <= S_IDLE;
        baud_cnt        <= 16'd0;
        bit_cnt         <= 3'd0;
        rx_shift        <= 8'd0;
        uart_byte       <= 8'd0;
        uart_byte_valid <= 1'b0;
    end
    else begin
        uart_byte_valid <= 1'b0;

        case (state)
            S_IDLE: begin
                baud_cnt <= 16'd0;
                bit_cnt  <= 3'd0;

                if (uart_rx_sig == 1'b0) begin
                    state <= S_START;
                end
            end
            S_START: begin
                if (baud_cnt == (baud_div >> 1) - 1) begin
                    baud_cnt <= 16'd0;

                    if (uart_rx_sig == 1'b0) begin
                        state <= S_DATA;
                    end
                    else begin
                        state <= S_IDLE;
                    end
                end
                else begin
                    baud_cnt <= baud_cnt + 1'b1;
                end
            end

            S_DATA: begin
                if (baud_cnt == baud_div - 1) begin
                    baud_cnt <= 16'd0;
                    rx_shift[bit_cnt] <= uart_rx_sig;

                    if (bit_cnt == 3'd7) begin
                        bit_cnt <= 3'd0;
                        state   <= S_STOP;
                    end
                    else begin
                        bit_cnt <= bit_cnt + 1'b1;
                    end
                end
                else begin
                    baud_cnt <= baud_cnt + 1'b1;
                end
            end
				            S_STOP: begin
                if (baud_cnt == baud_div - 1) begin
                    baud_cnt <= 16'd0;
                    state    <= S_IDLE;

                    if (uart_rx_sig == 1'b1) begin
                        uart_byte       <= rx_shift;
                        uart_byte_valid <= 1'b1;
                    end
                end
                else begin
                    baud_cnt <= baud_cnt + 1'b1;
                end
            end

            default: begin
                state <= S_IDLE;
            end
        endcase
    end
end

endmodule
