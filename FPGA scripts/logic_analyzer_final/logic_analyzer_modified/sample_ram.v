module sample_ram(
    input               clk,
    input               wr_en,
    input       [10:0]  wr_addr,
    input       [7:0]   wr_data,
    input       [10:0]  rd_addr,
    output  reg [7:0]   rd_data
);

reg [7:0] ram [0:2047];

always @(posedge clk) begin
    if (wr_en) begin
        ram[wr_addr] <= wr_data;
    end
end

always @(posedge clk) begin
    rd_data <= ram[rd_addr];
end

endmodule