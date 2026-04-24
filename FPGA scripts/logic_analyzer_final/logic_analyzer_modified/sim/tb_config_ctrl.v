`timescale 1ns/1ps

module tb_config_ctrl;

reg clk;
reg rst_n;
reg rx_done;
reg [7:0] rx_data;

wire cmd_start;
wire cmd_stop;
wire cmd_force_upload;
wire [7:0] sample_div_cfg;
wire [7:0] trigger_mode_cfg;
wire [7:0] trigger_param1;
wire [7:0] trigger_param2;
config_ctrl uut(
    .clk                (clk),
    .rst_n              (rst_n),
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

always #5 clk = ~clk;

task send_byte;
    input [7:0] data;
    begin
        @(posedge clk);
        rx_data = data;
        rx_done = 1'b1;
        @(posedge clk);
        rx_done = 1'b0;
    end
endtask
initial begin
    clk = 0;
    rst_n = 0;
    rx_done = 0;
    rx_data = 0;

    #100;
    rst_n = 1;
    #100;

    send_byte(8'hAA);
    send_byte(8'h55);
    send_byte(8'h01);
    send_byte(8'h03);
    send_byte(8'h00);
    send_byte(8'h00);
    send_byte(8'h00);
    send_byte(8'h03);

    #500;
    $stop;
end

endmodule