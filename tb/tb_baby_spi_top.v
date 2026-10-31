`timescale 1ns / 1ps
// Self-checking testbench. Prints PASS or FAIL and exits non-zero on failure.

module tb_baby_spi_top;

    localparam CLK_PERIOD = 10;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg sclk = 1'b0;
    reg cs_n = 1'b1;
    reg mosi = 1'b0;
    reg sw = 1'b0;

    wire       miso;
    wire [1:0] led;

    integer errors = 0;
    integer checks = 0;
    integer half_period = 4 * CLK_PERIOD;

    baby_spi_top dut (
        .clk      (clk),
        .rst      (rst),
        .spi_sclk (sclk),
        .spi_cs_n (cs_n),
        .spi_mosi (mosi),
        .spi_miso (miso),
        .sw   (sw),
        .led      (led)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    task check(input [255:0] name, input [7:0] actual, input [7:0] expected);
        begin
            checks = checks + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display("FAIL %0s: got 0x%02x, expected 0x%02x (t=%0t)", name, actual, expected, $time);
            end
        end
    endtask

    task select;
        begin
            cs_n = 1'b0;
            #(half_period);
        end
    endtask

    task deselect;
        begin
            #(half_period);
            cs_n = 1'b1;
            #(half_period * 2);
        end
    endtask

    // Runs one sclk cycle the way a mode 0 master does: drive on the falling edge,
    // sample on the rising edge.
    task clock_bit(input tx, output rx);
        begin
            mosi = tx;
            #(half_period);
            sclk = 1'b1;
            rx = miso;
            #(half_period);
            sclk = 1'b0;
        end
    endtask

    task transfer(input [7:0] tx, output [7:0] rx);
        integer i;
        begin
            for (i = 7; i >= 0; i = i - 1)
                clock_bit(tx[i], rx[i]);
        end
    endtask

    task reg_write(input [6:0] addr, input [7:0] data);
        reg [7:0] ignored;
        begin
            select;
            transfer({1'b0, addr}, ignored);
            transfer(data, ignored);
            deselect;
        end
    endtask

    task reg_read(input [6:0] addr, output [7:0] data);
        reg [7:0] ignored;
        begin
            select;
            transfer({1'b1, addr}, ignored);
            transfer(8'h00, data);
            deselect;
        end
    endtask

    task run_tests;
        reg [7:0] data;
        reg [7:0] pattern;
        integer i;
        begin
            rst = 1'b1;
            #(CLK_PERIOD * 5);
            rst = 1'b0;
            #(CLK_PERIOD * 5);

            // Read-only identification registers
            reg_read(7'h00, data); check("id", data, 8'hB5);
            reg_read(7'h01, data); check("version", data, 8'h01);

            // Reset values
            reg_read(7'h03, data); check("control reset", data, 8'h00);
            reg_read(7'h04, data); check("scratch reset", data, 8'h00);

            // Each scratch register holds its own value
            for (i = 0; i < 4; i = i + 1)
                reg_write(7'h04 + i, 8'hA0 + i);
            for (i = 0; i < 4; i = i + 1) begin
                reg_read(7'h04 + i, data);
                check("scratch", data, 8'hA0 + i);
            end

            // Data patterns and their inverses survive a round trip
            for (i = 0; i < 256; i = i + 37) begin
                pattern = i;
                reg_write(7'h05, pattern);
                reg_read(7'h05, data);
                check("pattern", data, pattern);
                reg_write(7'h05, ~pattern);
                reg_read(7'h05, data);
                check("inverted pattern", data, ~pattern);
            end

            // Read-only and unmapped addresses ignore writes
            reg_write(7'h00, 8'hFF);
            reg_read(7'h00, data); check("id is read-only", data, 8'hB5);
            reg_write(7'h7F, 8'hFF);
            reg_read(7'h7F, data); check("unmapped reads zero", data, 8'h00);
            reg_read(7'h04, data); check("unmapped write has no effect", data, 8'hA0);

            // A read does not disturb the register
            reg_read(7'h06, data); check("read not destructive", data, 8'hA2);

            // A frame cut short does not write
            select;
            transfer({1'b0, 7'h04}, data);
            for (i = 0; i < 7; i = i + 1)
                clock_bit(1'b1, data[0]);
            deselect;
            reg_read(7'h04, data); check("aborted write", data, 8'hA0);

            // The next frame after an aborted one starts cleanly
            reg_write(7'h07, 8'h3C);
            reg_read(7'h07, data); check("write after abort", data, 8'h3C);

            // Extra clocks after a frame neither rewrite nor change the register
            select;
            transfer({1'b0, 7'h07}, data);
            transfer(8'h5A, data);
            transfer(8'hFF, data);
            transfer(8'hFF, data);
            // Long enough that a wrapping bit counter would decode this as a new frame
            transfer({1'b0, 7'h07}, data);
            transfer(8'hFF, data);
            deselect;
            reg_read(7'h07, data); check("extra clocks ignored", data, 8'h5A);

            // MISO stops at zero after the data byte of a long read
            select;
            transfer({1'b1, 7'h00}, data);
            transfer(8'h00, data);
            check("long read data", data, 8'hB5);
            transfer(8'h00, data);
            check("long read trailer", data, 8'h00);
            deselect;

            // Status follows the switch
            sw = 1'b1;
            #(CLK_PERIOD * 4);
            reg_read(7'h02, data); check("status high", data, 8'h01);
            sw = 1'b0;
            #(CLK_PERIOD * 4);
            reg_read(7'h02, data); check("status low", data, 8'h00);

            // Control drives the LEDs and reads back only implemented bits
            reg_write(7'h03, 8'hFE);
            check("led", {6'b0, led}, 8'h02);
            reg_read(7'h03, data); check("control readback", data, 8'h02);
            reg_write(7'h03, 8'h00);

            // MISO is only driven while selected
            #(CLK_PERIOD * 2);
            if (miso !== 1'bz) begin
                errors = errors + 1;
                $display("FAIL miso not released while deselected");
            end

            // Reset clears writable registers
            reg_write(7'h04, 8'h77);
            rst = 1'b1;
            #(CLK_PERIOD * 5);
            rst = 1'b0;
            #(CLK_PERIOD * 5);
            reg_read(7'h04, data); check("scratch cleared by reset", data, 8'h00);
        end
    endtask

    initial begin
        if ($test$plusargs("wave")) begin
            $dumpfile("build/tb_baby_spi_top.vcd");
            $dumpvars(0, tb_baby_spi_top);
        end

        // clk / 8 is the fastest supported sclk. The odd periods sweep the sclk
        // edges across clk so every synchronizer phase is exercised.
        half_period = 40; run_tests;
        half_period = 43; run_tests;
        half_period = 47; run_tests;
        half_period = 160; run_tests;

        if (errors == 0) begin
            $display("PASS: %0d checks", checks);
            $finish;
        end
        $fatal(1, "FAIL: %0d of %0d checks failed", errors, checks);
    end

    initial begin
        #100_000_000;
        $fatal(1, "FAIL: timed out");
    end

endmodule
