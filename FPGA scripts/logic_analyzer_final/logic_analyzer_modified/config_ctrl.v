module config_ctrl(
    input               clk,
    input               rst_n,
    input               rx_done,
    input       [7:0]   rx_data,

    output  reg         cmd_start,
    output  reg         cmd_stop,
    output  reg         cmd_force_upload,

    output  reg [7:0]   sample_div_cfg,
    output  reg [7:0]   trigger_mode_cfg,
    output  reg [7:0]   trigger_param1,
    output  reg [7:0]   trigger_param2
);

localparam S_WAIT_AA = 3'd0;
localparam S_WAIT_55 = 3'd1;
localparam S_CMD     = 3'd2;
localparam S_DIV     = 3'd3;
localparam S_MODE    = 3'd4;
localparam S_P1      = 3'd5;
localparam S_P2      = 3'd6;
localparam S_CKS     = 3'd7;

reg [2:0] state;
reg [7:0] checksum_acc;

reg [7:0] cmd_byte;
reg [7:0] div_byte;
reg [7:0] mode_byte;
reg [7:0] p1_byte;
reg [7:0] p2_byte;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state            <= S_WAIT_AA;
        checksum_acc     <= 8'd0;

        cmd_byte         <= 8'd0;
        div_byte         <= 8'h03;   // 默认 1MHz
        mode_byte        <= 8'h00;   // 默认无触发
        p1_byte          <= 8'd0;
        p2_byte          <= 8'd0;

        sample_div_cfg   <= 8'h03;
        trigger_mode_cfg <= 8'h00;
        trigger_param1   <= 8'd0;
        trigger_param2   <= 8'd0;

        cmd_start        <= 1'b0;
        cmd_stop         <= 1'b0;
        cmd_force_upload <= 1'b0;
    end
    else begin
        // 这些命令信号设计成单拍脉冲
        cmd_start        <= 1'b0;
        cmd_stop         <= 1'b0;
        cmd_force_upload <= 1'b0;

        if (rx_done) begin
            case (state)
                S_WAIT_AA: begin
                    if (rx_data == 8'hAA) begin
                        checksum_acc <= 8'hAA;
                        state        <= S_WAIT_55;
                    end
                end

                S_WAIT_55: begin
                    if (rx_data == 8'h55) begin
                        checksum_acc <= 8'hFF;   // AA + 55 = FF
                        state        <= S_CMD;
                    end
                    else if (rx_data == 8'hAA) begin
                        checksum_acc <= 8'hAA;
                        state        <= S_WAIT_55;
                    end
                    else begin
                        state <= S_WAIT_AA;
                    end
                end

                S_CMD: begin
                    cmd_byte     <= rx_data;
                    checksum_acc <= checksum_acc + rx_data;
                    state        <= S_DIV;
                end

                S_DIV: begin
                    div_byte     <= rx_data;
                    checksum_acc <= checksum_acc + rx_data;
                    state        <= S_MODE;
                end

                S_MODE: begin
                    mode_byte    <= rx_data;
                    checksum_acc <= checksum_acc + rx_data;
                    state        <= S_P1;
                end

                S_P1: begin
                    p1_byte      <= rx_data;
                    checksum_acc <= checksum_acc + rx_data;
                    state        <= S_P2;
                end

                S_P2: begin
                    p2_byte      <= rx_data;
                    checksum_acc <= checksum_acc + rx_data;
                    state        <= S_CKS;
                end

                S_CKS: begin
                    if (checksum_acc == rx_data) begin
                        sample_div_cfg   <= div_byte;
                        trigger_mode_cfg <= mode_byte;
                        trigger_param1   <= p1_byte;
                        trigger_param2   <= p2_byte;

                        case (cmd_byte)
                            8'h01: cmd_start        <= 1'b1;
                            8'h02: cmd_stop         <= 1'b1;
                            8'h03: cmd_force_upload <= 1'b1;
                            default: begin
                                cmd_start        <= 1'b0;
                                cmd_stop         <= 1'b0;
                                cmd_force_upload <= 1'b0;
                            end
                        endcase
                    end

                    state <= S_WAIT_AA;
                end

                default: begin
                    state <= S_WAIT_AA;
                end
            endcase
        end
    end
end

endmodule