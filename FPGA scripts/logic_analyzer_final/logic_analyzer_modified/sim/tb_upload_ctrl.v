`timescale 1ns/1ps

module tb_upload_ctrl;

reg clk;
reg rst_n;

reg upload_req;
reg [7:0] ram_rd_data;
reg tx_busy;
reg tx_done;

wire [10:0] ram_rd_addr;
wire tx_start;
wire [7:0] tx_data;
wire upload_done;

reg [3:0] busy_cnt;
integer tx_byte_cnt;
integer frame_cnt;

upload_ctrl uut(
    .clk        (clk),
    .rst_n      (rst_n),
    .upload_req (upload_req),
    .ram_rd_data(ram_rd_data),
    .tx_busy    (tx_busy),
    .tx_done    (tx_done),
    .ram_rd_addr(ram_rd_addr),
    .tx_start   (tx_start),
    .tx_data    (tx_data),
    .upload_done(upload_done)
);

always #5 clk = ~clk;

// 模拟同步 RAM：地址变化后，下一个周期输出该地址对应数据
always @(*) begin
    ram_rd_data = ram_rd_addr[7:0];
end

// 模拟 UART 发送握手
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_busy  <= 1'b0;
        tx_done  <= 1'b0;
        busy_cnt <= 4'd0;
    end
    else begin
        tx_done <= 1'b0;

        if (tx_start && !tx_busy) begin
            tx_busy  <= 1'b1;
            busy_cnt <= 4'd3;
        end
        else if (tx_busy) begin
            if (busy_cnt == 4'd0) begin
                tx_busy <= 1'b0;
                tx_done <= 1'b1;
            end
            else begin
                busy_cnt <= busy_cnt - 1'b1;
            end
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_byte_cnt <= 0;
        frame_cnt   <= 0;
    end
    else begin
        if (tx_start && !tx_busy) begin
            tx_byte_cnt <= tx_byte_cnt + 1;

            if (tx_byte_cnt == 0)
                $display("frame %0d, byte0 = %02h", frame_cnt, tx_data);
            if (tx_byte_cnt == 1)
                $display("frame %0d, byte1 = %02h", frame_cnt, tx_data);
        end

        if (upload_done) begin
            $display("frame %0d done, total bytes = %0d", frame_cnt, tx_byte_cnt);
            frame_cnt   <= frame_cnt + 1;
            tx_byte_cnt <= 0;
        end
    end
end

initial begin
    clk        = 1'b0;
    rst_n      = 1'b0;
    upload_req = 1'b0;
    tx_busy    = 1'b0;
    tx_done    = 1'b0;
    busy_cnt   = 4'd0;

    #100;
    rst_n = 1'b1;

    // 第1帧
    #100;
    upload_req = 1'b1;
    #10;
    upload_req = 1'b0;

    wait(upload_done);

    // 第2帧：再次请求，检查是否仍然先发帧头
    #100;
    upload_req = 1'b1;
    #10;
    upload_req = 1'b0;

    #250000;
    $stop;
end

endmodule
