module capture_ctrl(
    input               clk,
    input               rst_n,
    input               sample_en,
    input       [7:0]   din_sync,

    input               cmd_start,
    input               cmd_stop,

    input               trigger_enable,
    input               trigger_hit,

    output  reg         ram_wr_en,
    output  reg [10:0]  ram_wr_addr,
    output  reg [7:0]   ram_wr_data,
    output  reg         capture_done_pulse
);

localparam S_IDLE         = 2'd0;
localparam S_WAIT_TRIGGER = 2'd1;
localparam S_CAPTURE      = 2'd2;
localparam S_DONE         = 2'd3;

reg [1:0] state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state              <= S_IDLE;
        ram_wr_en          <= 1'b0;
        ram_wr_addr        <= 11'd0;
        ram_wr_data        <= 8'd0;
        capture_done_pulse <= 1'b0;
    end
    else begin
        // 默认值
        ram_wr_en          <= 1'b0;
        capture_done_pulse <= 1'b0;

        case (state)
            // 空闲：等待开始命令
            S_IDLE: begin
                ram_wr_addr <= 11'd0;

                if (cmd_stop) begin
                    state       <= S_IDLE;
                    ram_wr_addr <= 11'd0;
                end
                else if (cmd_start) begin
                    ram_wr_addr <= 11'd0;

                    if (trigger_enable)
                        state <= S_WAIT_TRIGGER;
                    else
                        state <= S_CAPTURE;
                end
            end

            // 等待触发
            S_WAIT_TRIGGER: begin
                if (cmd_stop) begin
                    state       <= S_IDLE;
                    ram_wr_addr <= 11'd0;
                end
                else if (trigger_hit) begin
                    ram_wr_addr <= 11'd0;
                    state       <= S_CAPTURE;
                end
            end

            // 采样写 RAM
            S_CAPTURE: begin
                if (cmd_stop) begin
                    state       <= S_IDLE;
                    ram_wr_addr <= 11'd0;
                end
                else if (sample_en) begin
                    ram_wr_en   <= 1'b1;
                    ram_wr_data <= din_sync;

                    if (ram_wr_addr == 11'd2047) begin
                        capture_done_pulse <= 1'b1;
                        state              <= S_DONE;
                    end
                    else begin
                        ram_wr_addr <= ram_wr_addr + 1'b1;
                    end
                end
            end

            // 一帧采样完成，等待下一次开始
            // 配合 top.v 里的 capture_start_cmd = cmd_start | upload_done
            // 上传完成后会自动再来一拍 cmd_start，从而进入下一轮采样
            S_DONE: begin
                if (cmd_stop) begin
                    state       <= S_IDLE;
                    ram_wr_addr <= 11'd0;
                end
                else if (cmd_start) begin
                    ram_wr_addr <= 11'd0;

                    if (trigger_enable)
                        state <= S_WAIT_TRIGGER;
                    else
                        state <= S_CAPTURE;
                end
            end

            default: begin
                state              <= S_IDLE;
                ram_wr_addr        <= 11'd0;
                ram_wr_en          <= 1'b0;
                ram_wr_data        <= 8'd0;
                capture_done_pulse <= 1'b0;
            end
        endcase
    end
end

endmodule