module top(
    input           clk,
    input           rst_n,
    input   [7:0]   din,
    input           uart_rx,
    output          uart_tx
);

wire        rst_n_sys;

localparam  USE_INTERNAL_TEST_SIG = 1'b0;

wire [7:0]  din_src;
wire [7:0]  test_din;

// 下行命令接收
wire [7:0]  rx_data;
wire        rx_done;

wire        cmd_start;
wire        cmd_stop;
wire        cmd_force_upload;

wire [7:0]  sample_div_cfg;
wire [7:0]  trigger_mode_cfg;
wire [7:0]  trigger_param1;
wire [7:0]  trigger_param2;

// 采样与触发
wire        sample_en;
wire [7:0]  din_sync;
wire [7:0]  rise_flag;
wire [7:0]  fall_flag;

wire        trigger_enable;
wire [1:0]  trigger_type;
wire [2:0]  trigger_ch;
wire        edge_sel;
wire        level_sel;
wire [7:0]  pattern_value;
wire [7:0]  pattern_mask;
wire        trigger_hit;

// RAM 写口
wire        ram_wr_en;
wire [10:0] ram_wr_addr;
wire [7:0]  ram_wr_data;

// RAM 读口
wire [10:0] ram_rd_addr;
wire [7:0]  ram_rd_data;

// 采样完成
wire        capture_done_pulse;

// 上传控制
wire        upload_req;
wire        upload_done;
wire        capture_start_cmd;

// 串口发送
wire        tx_busy;
wire        tx_done;

wire [7:0]  mux_tx_data;
wire        mux_tx_start;

wire [7:0]  upload_tx_data;
wire        upload_tx_start;

// 这些解码通道当前先不用，避免干扰主上传链路
wire [7:0]  uart_dec_byte;
wire        uart_dec_valid;
wire [15:0] uart_baud_div;
wire        uart_rx_sig_dec;

wire [7:0]  spi_mosi_byte;
wire [7:0]  spi_miso_byte;
wire        spi_byte_valid;

wire        spi_sclk;
wire        spi_mosi;
wire        spi_miso;
wire        spi_cs_n;

// 当前阶段仍然先不使用外部复位按键
// 以后要接外部按键时，只需改成：assign rst_n_sys = rst_n;
assign rst_n_sys = 1'b1;

// 内部测试信号 / 外部输入 选择
assign din_src = USE_INTERNAL_TEST_SIG ? test_din : din;

// 上传请求：采样完成 或 强制上传
assign upload_req = capture_done_pulse | cmd_force_upload;

// 简单循环模式：第一次由上位机开始，之后每次上传完成自动开始下一轮采样
assign capture_start_cmd = cmd_start | upload_done;

// 触发模式解码
assign trigger_enable = (trigger_mode_cfg != 8'h00);

// Byte4 触发模式定义：
// 0x00 无触发立即采样
// 0x01 上升沿触发
// 0x02 下降沿触发
// 0x03 高电平触发
// 0x04 低电平触发
// 0x05 模式触发
assign trigger_type = (trigger_mode_cfg == 8'h05) ? 2'b10 :
                      ((trigger_mode_cfg == 8'h03) || (trigger_mode_cfg == 8'h04)) ? 2'b01 :
                      2'b00;

assign trigger_ch    = trigger_param1[2:0];
assign edge_sel      = (trigger_mode_cfg == 8'h02);
assign level_sel     = (trigger_mode_cfg == 8'h04);
assign pattern_value = trigger_param1;
assign pattern_mask  = trigger_param2;

// 当前先关闭内部 UART/SPI 解码输入，避免影响上传链路
assign uart_baud_div   = 16'd434;
assign uart_rx_sig_dec = 1'b0;

assign spi_sclk = 1'b0;
assign spi_mosi = 1'b0;
assign spi_miso = 1'b0;
assign spi_cs_n = 1'b1;

// 串口接收
uart_rx u_uart_rx(
    .clk        (clk),
    .rst_n      (rst_n_sys),
    .rx         (uart_rx),
    .rx_data    (rx_data),
    .rx_done    (rx_done)
);

// 命令解析与配置寄存器
config_ctrl u_config_ctrl(
    .clk                (clk),
    .rst_n              (rst_n_sys),
    .rx_done            (rx_done),
    .rx_data            (rx_data),
    .cmd_start          (cmd_start),
    .cmd_stop           (cmd_stop),
    .cmd_force_upload   (cmd_force_upload),
    .sample_div_cfg     (sample_div_cfg),
    .trigger_mode_cfg   (trigger_mode_cfg),
    .trigger_param1     (trigger_param1),
    .trigger_param2     (trigger_param2)
);

// 可配置采样时钟
clk_div u_clk_div(
    .clk            (clk),
    .rst_n          (rst_n_sys),
    .sample_div_cfg (sample_div_cfg),
    .sample_en      (sample_en)
);

// 内部测试信号发生器
test_signal_gen u_test_signal_gen(
    .clk        (clk),
    .rst_n      (rst_n_sys),
    .sample_en  (sample_en),
    .test_din   (test_din)
);

// 输入同步
input_sync u_input_sync(
    .clk        (clk),
    .rst_n      (rst_n_sys),
    .din        (din_src),
    .din_sync   (din_sync)
);

// 边沿检测
edge_detect u_edge_detect(
    .clk        (clk),
    .rst_n      (rst_n_sys),
    .din_sync   (din_sync),
    .rise_flag  (rise_flag),
    .fall_flag  (fall_flag)
);

// 触发判断
trigger_ctrl u_trigger_ctrl(
    .clk            (clk),
    .rst_n          (rst_n_sys),
    .din_sync       (din_sync),
    .rise_flag      (rise_flag),
    .fall_flag      (fall_flag),
    .trigger_type   (trigger_type),
    .trigger_ch     (trigger_ch),
    .edge_sel       (edge_sel),
    .level_sel      (level_sel),
    .pattern_value  (pattern_value),
    .pattern_mask   (pattern_mask),
    .trigger_hit    (trigger_hit)
);

// 采样控制：改成 capture_start_cmd，支持自动循环采样
capture_ctrl u_capture_ctrl(
    .clk                (clk),
    .rst_n              (rst_n_sys),
    .sample_en          (sample_en),
    .din_sync           (din_sync),
    .cmd_start          (capture_start_cmd),
    .cmd_stop           (cmd_stop),
    .trigger_enable     (trigger_enable),
    .trigger_hit        (trigger_hit),
    .ram_wr_en          (ram_wr_en),
    .ram_wr_addr        (ram_wr_addr),
    .ram_wr_data        (ram_wr_data),
    .capture_done_pulse (capture_done_pulse)
);

// 采样 RAM
sample_ram u_sample_ram(
    .clk        (clk),
    .wr_en      (ram_wr_en),
    .wr_addr    (ram_wr_addr),
    .wr_data    (ram_wr_data),
    .rd_addr    (ram_rd_addr),
    .rd_data    (ram_rd_data)
);

// 上传控制：严格按 5A A5 + 2048B + CheckSum
upload_ctrl u_upload_ctrl(
    .clk         (clk),
    .rst_n       (rst_n_sys),
    .upload_req  (upload_req),
    .ram_rd_data (ram_rd_data),
    .tx_busy     (tx_busy),
    .tx_done     (tx_done),
    .ram_rd_addr (ram_rd_addr),
    .tx_start    (upload_tx_start),
    .tx_data     (upload_tx_data),
    .upload_done (upload_done)
);

// 串口发送
uart_tx u_uart_tx(
    .clk        (clk),
    .rst_n      (rst_n_sys),
    .tx_start   (mux_tx_start),
    .tx_data    (mux_tx_data),
    .tx         (uart_tx),
    .tx_busy    (tx_busy),
    .tx_done    (tx_done)
);

// 保留实例，但当前不参与主上传发送
uart_decoder u_uart_decoder(
    .clk             (clk),
    .rst_n           (rst_n_sys),
    .uart_rx_sig     (uart_rx_sig_dec),
    .baud_div        (uart_baud_div),
    .uart_byte       (uart_dec_byte),
    .uart_byte_valid (uart_dec_valid)
);

spi_decoder u_spi_decoder(
    .clk        (clk),
    .rst_n      (rst_n_sys),
    .spi_sclk   (spi_sclk),
    .spi_mosi   (spi_mosi),
    .spi_miso   (spi_miso),
    .spi_cs_n   (spi_cs_n),
    .mosi_byte  (spi_mosi_byte),
    .miso_byte  (spi_miso_byte),
    .byte_valid (spi_byte_valid)
);

// 发送复用：当前只保留 upload_ctrl 的上传数据
tx_mux_ctrl u_tx_mux_ctrl(
    .clk            (clk),
    .rst_n          (rst_n_sys),

    .upload_tx_start(upload_tx_start),
    .upload_tx_data (upload_tx_data),

    .uart_dec_valid (1'b0),
    .uart_dec_byte  (8'd0),

    .spi_dec_valid  (1'b0),
    .spi_mosi_byte  (8'd0),
    .spi_miso_byte  (8'd0),

    .tx_busy        (tx_busy),

    .tx_start       (mux_tx_start),
    .tx_data        (mux_tx_data)
);

endmodule