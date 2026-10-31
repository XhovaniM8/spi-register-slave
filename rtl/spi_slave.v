`timescale 1ns / 1ps
// SPI mode 0 slave with a simple register-access frame.
//
// A frame is sent MSB first while cs_n is low:
//
//   | R/W | A[ADDR_WIDTH-1:0] | D[DATA_WIDTH-1:0] |
//
// R/W = 1 reads the addressed register: D is driven on miso by the slave.
// R/W = 0 writes the addressed register: D is taken from mosi, and reg_we
// pulses for one clk when the last data bit has been sampled. A frame that ends
// early does not write. Extra sclk cycles after the frame are ignored.
//
// All logic runs on clk; the SPI inputs are synchronized and sclk is only ever
// treated as data. clk must be at least 8x the sclk frequency.

module spi_slave #(
    parameter ADDR_WIDTH = 7,
    parameter DATA_WIDTH = 8
) (
    input  wire                  clk,
    input  wire                  rst,

    input  wire                  sclk,
    input  wire                  cs_n,
    input  wire                  mosi,
    output wire                  miso,

    output reg  [ADDR_WIDTH-1:0] reg_addr,
    output reg  [DATA_WIDTH-1:0] reg_wdata,
    output reg                   reg_we,
    input  wire [DATA_WIDTH-1:0] reg_rdata
);

    localparam HEADER_BITS = ADDR_WIDTH + 1;
    localparam FRAME_BITS  = HEADER_BITS + DATA_WIDTH;
    localparam CNT_WIDTH   = $clog2(FRAME_BITS + 1);

    localparam [CNT_WIDTH-1:0] HEADER_END = HEADER_BITS[CNT_WIDTH-1:0];
    localparam [CNT_WIDTH-1:0] FRAME_END  = FRAME_BITS[CNT_WIDTH-1:0];

    // [0] and [1] synchronize; sclk_sync[2] is the previous value for edge detection.
    reg [2:0] sclk_sync;
    reg [1:0] cs_n_sync;
    reg [1:0] mosi_sync;

    wire sclk_rise = sclk_sync[1] & ~sclk_sync[2];
    wire sclk_fall = ~sclk_sync[1] & sclk_sync[2];
    wire selected  = ~cs_n_sync[1];
    wire mosi_in   = mosi_sync[1];

    reg [CNT_WIDTH-1:0]  bit_cnt;
    reg [FRAME_BITS-1:0] rx_shift;
    reg [DATA_WIDTH-1:0] tx_shift;
    reg                  is_read;

    assign miso = tx_shift[DATA_WIDTH-1];

    always @(posedge clk) begin
        if (rst) begin
            sclk_sync <= 3'b000;
            cs_n_sync <= 2'b11;
            mosi_sync <= 2'b00;
        end else begin
            sclk_sync <= {sclk_sync[1:0], sclk};
            cs_n_sync <= {cs_n_sync[0], cs_n};
            mosi_sync <= {mosi_sync[0], mosi};
        end
    end

    always @(posedge clk) begin
        reg_we <= 1'b0;

        if (rst || !selected) begin
            bit_cnt  <= 0;
            rx_shift <= 0;
            tx_shift <= 0;
            is_read  <= 1'b0;
        end else begin
            if (sclk_rise && bit_cnt != FRAME_END) begin
                rx_shift <= {rx_shift[FRAME_BITS-2:0], mosi_in};
                bit_cnt  <= bit_cnt + 1'b1;

                if (bit_cnt == HEADER_END - 1'b1) begin
                    is_read  <= rx_shift[ADDR_WIDTH-1];
                    reg_addr <= {rx_shift[ADDR_WIDTH-2:0], mosi_in};
                end

                if (bit_cnt == FRAME_END - 1'b1 && !is_read) begin
                    reg_wdata <= {rx_shift[DATA_WIDTH-2:0], mosi_in};
                    reg_we    <= 1'b1;
                end
            end

            if (sclk_fall && is_read) begin
                if (bit_cnt == HEADER_END)
                    tx_shift <= reg_rdata;
                else
                    tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
            end
        end
    end

endmodule
