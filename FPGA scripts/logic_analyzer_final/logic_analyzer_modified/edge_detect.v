module edge_detect(
    input               clk,
    input               rst_n,
    input       [7:0]   din_sync,
    output  reg [7:0]   rise_flag,
    output  reg [7:0]   fall_flag
);

reg [7:0] din_sync_dly;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        din_sync_dly <= 8'd0;
        rise_flag    <= 8'd0;
        fall_flag    <= 8'd0;
    end
    else begin
        rise_flag    <= (~din_sync_dly) & din_sync;
        fall_flag    <= din_sync_dly & (~din_sync);
        din_sync_dly <= din_sync;
    end
end

endmodule