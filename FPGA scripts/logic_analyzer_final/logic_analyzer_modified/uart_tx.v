module uart_tx(
    input               clk,
    input               rst_n,
    input               tx_start,
    input       [7:0]   tx_data,
    output  reg         tx,
    output  reg         tx_busy,
    output  reg         tx_done
);

parameter BAUD_DIV = 434;   // 50MHz时钟下约对应115200波特率

reg [15:0] baud_cnt;
reg [3:0]  bit_cnt;
reg [9:0]  tx_shift;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx       <= 1'b1;
        tx_busy  <= 1'b0;
        tx_done  <= 1'b0;
        baud_cnt <= 16'd0;
        bit_cnt  <= 4'd0;
        tx_shift <= 10'b1111111111;
    end
    else begin
        tx_done <= 1'b0;

        if (!tx_busy) begin
            tx <= 1'b1;

            if (tx_start) begin
                tx_busy  <= 1'b1;
                baud_cnt <= 16'd0;
                bit_cnt  <= 4'd0;
                tx_shift <= {1'b1, tx_data, 1'b0}; 
                // {停止位, 8位数据, 起始位}
            end
        end
        else begin
            if (baud_cnt == BAUD_DIV - 1) begin
                baud_cnt <= 16'd0;
                tx       <= tx_shift[0];
                tx_shift <= {1'b1, tx_shift[9:1]};

                if (bit_cnt == 4'd9) begin
                    bit_cnt  <= 4'd0;
                    tx_busy  <= 1'b0;
                    tx_done  <= 1'b1;
                    tx       <= 1'b1;
                end
                else begin
                    bit_cnt <= bit_cnt + 1'b1;
                end
            end
            else begin
                baud_cnt <= baud_cnt + 1'b1;
            end
        end
    end
end

endmodule