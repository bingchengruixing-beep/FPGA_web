`timescale 1ns/1ps

module tb_trigger_ctrl;

reg clk;
reg rst_n;

reg [7:0] din_sync;
reg [7:0] rise_flag;
reg [7:0] fall_flag;

reg [1:0] trigger_type;
reg [2:0] trigger_ch;
reg edge_sel;
reg level_sel;
reg [7:0] pattern_value;
reg [7:0] pattern_mask;

wire trigger_hit;

trigger_ctrl uut(
    .clk            (clk),
    .rst_n          (rst_n),
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

always #5 clk = ~clk;
initial begin
    clk = 0;
    rst_n = 0;

    din_sync = 8'h00;
    rise_flag = 8'h00;
    fall_flag = 8'h00;

    trigger_type = 2'b00;
    trigger_ch = 3'd0;
    edge_sel = 1'b0;
    level_sel = 1'b0;
    pattern_value = 8'h00;
    pattern_mask = 8'h00;

    #100;
    rst_n = 1;
    #100;
        // ??3?????
    trigger_type   = 2'b10;
    pattern_value  = 8'b1010_0000;
    pattern_mask   = 8'b1111_0000;

    din_sync = 8'b1010_0011;
    #20;
    din_sync = 8'b0011_0011;

    #100;

    $stop;
end

endmodule