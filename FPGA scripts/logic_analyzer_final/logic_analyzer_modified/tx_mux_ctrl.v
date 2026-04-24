module tx_mux_ctrl(
    input               clk,
    input               rst_n,

    input               upload_tx_start,
    input       [7:0]   upload_tx_data,

    input               uart_dec_valid,
    input       [7:0]   uart_dec_byte,

    input               spi_dec_valid,
    input       [7:0]   spi_mosi_byte,
    input       [7:0]   spi_miso_byte,

    input               tx_busy,

    output  reg         tx_start,
    output  reg [7:0]   tx_data
);

localparam S_IDLE      = 3'd0;
localparam S_SPI_HEAD1 = 3'd1;
localparam S_SPI_HEAD2 = 3'd2;
localparam S_SPI_MOSI  = 3'd3;
localparam S_SPI_MISO  = 3'd4;

reg [2:0] state;

reg [7:0] spi_mosi_latch;
reg [7:0] spi_miso_latch;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state          <= S_IDLE;
        tx_start       <= 1'b0;
        tx_data        <= 8'd0;
        spi_mosi_latch <= 8'd0;
        spi_miso_latch <= 8'd0;
    end
    else begin
        tx_start <= 1'b0;

        case (state)
            S_IDLE: begin
                if (!tx_busy) begin
                    if (upload_tx_start) begin
                        tx_start <= 1'b1;
                        tx_data  <= upload_tx_data;
                    end
                    else if (uart_dec_valid) begin
                        tx_start <= 1'b1;
                        tx_data  <= uart_dec_byte;
                    end
						                     else if (spi_dec_valid) begin
                        spi_mosi_latch <= spi_mosi_byte;
                        spi_miso_latch <= spi_miso_byte;
                        state          <= S_SPI_HEAD1;
                    end
                end
            end

            S_SPI_HEAD1: begin
                if (!tx_busy) begin
                    tx_start <= 1'b1;
                    tx_data  <= 8'h53;
                    state    <= S_SPI_HEAD2;
                end
            end

            S_SPI_HEAD2: begin
                if (!tx_busy) begin
                    tx_start <= 1'b1;
                    tx_data  <= 8'h49;
                    state    <= S_SPI_MOSI;
                end
            end 
				            S_SPI_MOSI: begin
                if (!tx_busy) begin
                    tx_start <= 1'b1;
                    tx_data  <= spi_mosi_latch;
                    state    <= S_SPI_MISO;
                end
            end

            S_SPI_MISO: begin
                if (!tx_busy) begin
                    tx_start <= 1'b1;
                    tx_data  <= spi_miso_latch;
                    state    <= S_IDLE;
                end
            end

            default: begin
                state <= S_IDLE;
            end
        endcase
    end
end

endmodule
