module clk_div(
    input               clk,
    input               rst_n,
    input       [7:0]   sample_div_cfg,
    output  reg         sample_en
);

reg [15:0] div_target;
reg [15:0] cnt;

// 按 50MHz 系统时钟映射
// 0x00 -> 50MHz  (每拍采样一次)
// 0x01 -> 10MHz
// 0x02 -> 5MHz
// 0x03 -> 1MHz
// 0x04 -> 100kHz
// 0x05 -> 10kHz
always @(*) begin
    case (sample_div_cfg)
        8'h00: div_target = 16'd1;
        8'h01: div_target = 16'd5;
        8'h02: div_target = 16'd10;
        8'h03: div_target = 16'd50;
        8'h04: div_target = 16'd500;
        8'h05: div_target = 16'd5000;
        default: div_target = 16'd50;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt       <= 16'd0;
        sample_en <= 1'b0;
    end
    else begin
        if (div_target <= 16'd1) begin
            cnt       <= 16'd0;
            sample_en <= 1'b1;
        end
        else if (cnt == div_target - 1'b1) begin
            cnt       <= 16'd0;
            sample_en <= 1'b1;
        end
        else begin
            cnt       <= cnt + 1'b1;
            sample_en <= 1'b0;
        end
    end
end

endmodule