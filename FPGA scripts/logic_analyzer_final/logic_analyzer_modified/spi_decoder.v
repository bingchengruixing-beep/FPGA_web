module spi_decoder(
    input               clk,
    input               rst_n,
    input               spi_sclk,
    input               spi_mosi,
    input               spi_miso,
    input               spi_cs_n,

    output  reg [7:0]   mosi_byte,
    output  reg [7:0]   miso_byte,
    output  reg         byte_valid
);

reg spi_sclk_dly;
reg [2:0] bit_cnt;
reg [7:0] mosi_shift;
reg [7:0] miso_shift;

wire sclk_rise;
assign sclk_rise = (~spi_sclk_dly) & spi_sclk;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        spi_sclk_dly <= 1'b0;
        bit_cnt      <= 3'd0;
        mosi_shift   <= 8'd0;
        miso_shift   <= 8'd0;
        mosi_byte    <= 8'd0;
        miso_byte    <= 8'd0;
        byte_valid   <= 1'b0;
    end
    else begin
        spi_sclk_dly <= spi_sclk;
        byte_valid   <= 1'b0;

        if (spi_cs_n == 1'b1) begin
            bit_cnt    <= 3'd0;
            mosi_shift <= 8'd0;
            miso_shift <= 8'd0;
        end
        else begin
            if (sclk_rise) begin
                mosi_shift <= {mosi_shift[6:0], spi_mosi};
                miso_shift <= {miso_shift[6:0], spi_miso};

                if (bit_cnt == 3'd7) begin
                    bit_cnt    <= 3'd0;
                    mosi_byte  <= {mosi_shift[6:0], spi_mosi};
                    miso_byte  <= {miso_shift[6:0], spi_miso};
                    byte_valid <= 1'b1;
                end
                else begin
                    bit_cnt <= bit_cnt + 1'b1;
                end
            end
        end
    end
end

endmodule