module input_sync(
    input               clk,
    input               rst_n,
    input       [7:0]   din,
    output  reg [7:0]   din_sync
);

reg [7:0] din_ff1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        din_ff1   <= 8'd0;
        din_sync  <= 8'd0;
    end
    else begin
        din_ff1   <= din;
        din_sync  <= din_ff1;
    end
end

endmodule