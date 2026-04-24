module test_signal_gen(
    input               clk,
    input               rst_n,
    input               sample_en,
    output  reg [7:0]   test_din
);

reg [15:0] sample_cnt;
reg [7:0]  lfsr = 8'hFF;

// 预定义协议发送序列
wire [15:0] uart_seq = 16'b111111_1_01001111_0; // Idle(6) + Stop(1) + 0x4F(8) + Start(1)
wire [7:0]  spi_seq  = 8'h5A;                   // SPI 发送数据 0x5A

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sample_cnt <= 16'd0;
        lfsr       <= 8'hFF;
        test_din   <= 8'd0;
    end
    else if (sample_en) begin
        sample_cnt <= sample_cnt + 1'b1;
        lfsr       <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};

        // ==========================================
        // 1. UART 测试信号 (CH0)
        // ==========================================
        // 发送字符 'O' (0x4F)。每 32 个采样点为一个 Baud 宽度。
        // sample_cnt[8:5] 取值 0~15，自动遍历 uart_seq 的每一位。
        test_din[0] <= uart_seq[sample_cnt[8:5]];

        // ==========================================
        // 2. SPI 测试信号 (CH1:CS, CH2:SCK, CH3:MOSI)
        // ==========================================
        // 模拟 Mode 0 (CPOL=0, CPHA=0)。每 256 个采样点为一个完整的 SPI 帧。
        
        // CH1 (CS片选): 活跃期为低电平 (sample_cnt = 0~255)
        test_din[1] <= sample_cnt[8];
        
        // CH2 (SCK时钟): 仅在 CS 低电平时翻转，产生 8 个脉冲
        test_din[2] <= (~sample_cnt[8]) & sample_cnt[4];
        
        // CH3 (MOSI数据): MSB First，发送 0x5A。
        // ~sample_cnt[7:5] 实现 7 到 0 的倒序索引，完美在 SCK 下降沿切换数据
        test_din[3] <= spi_seq[~sample_cnt[7:5]];

        // ==========================================
        // 3. 并行总线测试信号 (CH4 ~ CH7)
        // ==========================================
        // 4 bit 递增计数器，每 16 个采样点加 1。
        // 供 DEC 解码器观察 0x0 -> 0xF 的阶梯波形。
        test_din[4] <= sample_cnt[4];
        test_din[5] <= sample_cnt[5];
        test_din[6] <= sample_cnt[6];
        test_din[7] <= sample_cnt[7];
    end
end

endmodule