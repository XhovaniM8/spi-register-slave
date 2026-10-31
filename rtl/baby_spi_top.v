`timescale 1ns / 1ps
// Board-independent top level: the SPI slave connected to the example registers.

module baby_spi_top (
    input  wire       clk,
    input  wire       rst,

    input  wire       spi_sclk,
    input  wire       spi_cs_n,
    input  wire       spi_mosi,
    output wire       spi_miso,   // High impedance while deselected

    input  wire       sw,
    output wire [1:0] led
);

    // The initial value holds the design in reset for two clocks after configuration.
    /* verilator lint_off PROCASSINIT */
    reg [1:0] rst_sync = 2'b11;
    /* verilator lint_on PROCASSINIT */
    reg [1:0] sw_sync;

    wire       sys_rst = rst_sync[1];
    wire [6:0] reg_addr;
    wire [7:0] reg_wdata;
    wire [7:0] reg_rdata;
    wire       reg_we;
    wire       miso;

    always @(posedge clk) begin
        rst_sync    <= {rst_sync[0], rst};
        sw_sync <= {sw_sync[0], sw};
    end

    assign spi_miso = spi_cs_n ? 1'bz : miso;

    spi_slave #(
        .ADDR_WIDTH (7),
        .DATA_WIDTH (8)
    ) u_spi_slave (
        .clk       (clk),
        .rst       (sys_rst),
        .sclk      (spi_sclk),
        .cs_n      (spi_cs_n),
        .mosi      (spi_mosi),
        .miso      (miso),
        .reg_addr  (reg_addr),
        .reg_wdata (reg_wdata),
        .reg_we    (reg_we),
        .reg_rdata (reg_rdata)
    );

    spi_regs u_spi_regs (
        .clk    (clk),
        .rst    (sys_rst),
        .addr   (reg_addr),
        .wdata  (reg_wdata),
        .we     (reg_we),
        .rdata  (reg_rdata),
        .sw     (sw_sync[1]),
        .led    (led)
    );

endmodule
