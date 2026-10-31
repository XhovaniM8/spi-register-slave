`timescale 1ns / 1ps
// Example register map. See the register table in README.md.
//
// Unmapped addresses read as zero and ignore writes.

module spi_regs (
    input  wire       clk,
    input  wire       rst,

    input  wire [6:0] addr,
    input  wire [7:0] wdata,
    input  wire       we,
    output reg  [7:0] rdata,

    input  wire       sw,
    output wire [1:0] led
);

    localparam ID_VALUE      = 8'hB5;
    localparam VERSION_VALUE = 8'h01;

    localparam ADDR_ID       = 7'h00;
    localparam ADDR_VERSION  = 7'h01;
    localparam ADDR_STATUS   = 7'h02;
    localparam ADDR_CONTROL  = 7'h03;
    localparam ADDR_SCRATCH0 = 7'h04;
    localparam ADDR_SCRATCH1 = 7'h05;
    localparam ADDR_SCRATCH2 = 7'h06;
    localparam ADDR_SCRATCH3 = 7'h07;

    reg [1:0] control;
    reg [7:0] scratch0, scratch1, scratch2, scratch3;

    assign led = control;

    always @(posedge clk) begin
        if (rst) begin
            control  <= 2'b00;
            scratch0 <= 8'h00;
            scratch1 <= 8'h00;
            scratch2 <= 8'h00;
            scratch3 <= 8'h00;
        end else if (we) begin
            case (addr)
                ADDR_CONTROL:  control  <= wdata[1:0];
                ADDR_SCRATCH0: scratch0 <= wdata;
                ADDR_SCRATCH1: scratch1 <= wdata;
                ADDR_SCRATCH2: scratch2 <= wdata;
                ADDR_SCRATCH3: scratch3 <= wdata;
                default: ;
            endcase
        end
    end

    always @* begin
        case (addr)
            ADDR_ID:       rdata = ID_VALUE;
            ADDR_VERSION:  rdata = VERSION_VALUE;
            ADDR_STATUS:   rdata = {7'b0, sw};
            ADDR_CONTROL:  rdata = {6'b0, control};
            ADDR_SCRATCH0: rdata = scratch0;
            ADDR_SCRATCH1: rdata = scratch1;
            ADDR_SCRATCH2: rdata = scratch2;
            ADDR_SCRATCH3: rdata = scratch3;
            default:       rdata = 8'h00;
        endcase
    end

endmodule
