module trigger_ctrl(
    input               clk,
    input               rst_n,
    input       [7:0]   din_sync,
    input       [7:0]   rise_flag,
    input       [7:0]   fall_flag,

    input       [1:0]   trigger_type,   // 00:边沿 01:电平 10:模式
    input       [2:0]   trigger_ch,
    input               edge_sel,       // 0:上升沿 1:下降沿
    input               level_sel,      // 0:高电平 1:低电平
    input       [7:0]   pattern_value,
    input       [7:0]   pattern_mask,

    output  reg         trigger_hit
);

wire edge_hit;
wire level_hit;
wire pattern_hit;

// 边沿触发
assign edge_hit = (edge_sel == 1'b0) ? rise_flag[trigger_ch] :
                                     fall_flag[trigger_ch];

// 电平触发
assign level_hit = (level_sel == 1'b0) ? din_sync[trigger_ch] :
                                         ~din_sync[trigger_ch];

// 模式触发
assign pattern_hit = ((din_sync & pattern_mask) == (pattern_value & pattern_mask));

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        trigger_hit <= 1'b0;
    end
    else begin
        case (trigger_type)
            2'b00: trigger_hit <= edge_hit;     // 边沿触发
            2'b01: trigger_hit <= level_hit;    // 电平触发
            2'b10: trigger_hit <= pattern_hit;  // 模式触发
            default: trigger_hit <= 1'b0;
        endcase
    end
end

endmodule