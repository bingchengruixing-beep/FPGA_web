module upload_ctrl(
    input               clk,
    input               rst_n,
    input               upload_req,
    input       [7:0]   ram_rd_data,
    input               tx_busy,
    input               tx_done,

    output  reg [10:0]  ram_rd_addr,
    output  reg         tx_start,
    output  reg [7:0]   tx_data,
    output  reg         upload_done
);

// ============================================================
// 每一帧固定格式：
//   Byte0    : FRAME_HEAD1
//   Byte1    : FRAME_HEAD2
//   Byte2~2049 : 2048字节采样数据
//   Byte2050 : 校验和（对2048字节数据逐字节累加）
//
// 说明：
// 1) 这里不再依赖“仅首帧加帧头”的思路，而是每次收到 upload_req，
//    都重新发送完整帧头 + 数据 + 校验。
// 2) upload_req 做了锁存，即便请求脉冲比较窄，也不会丢。
// 3) 如需把帧头改成 AA 55，只需改下面两个 localparam。
// ============================================================
localparam [7:0] FRAME_HEAD1 = 8'h5A;
localparam [7:0] FRAME_HEAD2 = 8'hA5;

localparam S_IDLE        = 4'd0;
localparam S_HDR1_START  = 4'd1;
localparam S_HDR1_WAIT   = 4'd2;
localparam S_HDR2_START  = 4'd3;
localparam S_HDR2_WAIT   = 4'd4;
localparam S_RD_WAIT     = 4'd5;
localparam S_DATA_START  = 4'd6;
localparam S_DATA_WAIT   = 4'd7;
localparam S_CKS_START   = 4'd8;
localparam S_CKS_WAIT    = 4'd9;

reg [3:0] state;
reg [7:0] checksum_reg;
reg       upload_req_latch;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state            <= S_IDLE;
        ram_rd_addr      <= 11'd0;
        tx_start         <= 1'b0;
        tx_data          <= 8'd0;
        upload_done      <= 1'b0;
        checksum_reg     <= 8'd0;
        upload_req_latch <= 1'b0;
    end
    else begin
        tx_start    <= 1'b0;
        upload_done <= 1'b0;

        // 锁存上传请求，避免单拍脉冲被错过
        if (upload_req)
            upload_req_latch <= 1'b1;

        case (state)
            S_IDLE: begin
                ram_rd_addr  <= 11'd0;
                checksum_reg <= 8'd0;

                if (upload_req_latch) begin
                    upload_req_latch <= 1'b0;
                    state            <= S_HDR1_START;
                end
            end

            S_HDR1_START: begin
                if (!tx_busy) begin
                    tx_start <= 1'b1;
                    tx_data  <= FRAME_HEAD1;
                    state    <= S_HDR1_WAIT;
                end
            end

            S_HDR1_WAIT: begin
                if (tx_done) begin
                    state <= S_HDR2_START;
                end
            end

            S_HDR2_START: begin
                if (!tx_busy) begin
                    tx_start <= 1'b1;
                    tx_data  <= FRAME_HEAD2;
                    state    <= S_HDR2_WAIT;
                end
            end

            S_HDR2_WAIT: begin
                if (tx_done) begin
                    ram_rd_addr <= 11'd0;
                    state       <= S_RD_WAIT;
                end
            end

            // sample_ram 是同步读，这里留 1 拍给 rd_data 稳定
            S_RD_WAIT: begin
                state <= S_DATA_START;
            end

            S_DATA_START: begin
                if (!tx_busy) begin
                    tx_start <= 1'b1;
                    tx_data  <= ram_rd_data;
                    state    <= S_DATA_WAIT;
                end
            end

            S_DATA_WAIT: begin
                if (tx_done) begin
                    checksum_reg <= checksum_reg + ram_rd_data;

                    if (ram_rd_addr == 11'd2047) begin
                        state <= S_CKS_START;
                    end
                    else begin
                        ram_rd_addr <= ram_rd_addr + 1'b1;
                        state       <= S_RD_WAIT;
                    end
                end
            end

            S_CKS_START: begin
                if (!tx_busy) begin
                    tx_start <= 1'b1;
                    tx_data  <= checksum_reg;
                    state    <= S_CKS_WAIT;
                end
            end

            S_CKS_WAIT: begin
                if (tx_done) begin
                    upload_done <= 1'b1;
                    state       <= S_IDLE;
                end
            end

            default: begin
                state <= S_IDLE;
            end
        endcase
    end
end

endmodule
