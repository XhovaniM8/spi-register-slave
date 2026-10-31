RTL   := rtl/spi_slave.v rtl/spi_regs.v rtl/baby_spi_top.v
TB    := tb/tb_baby_spi_top.v
BUILD := build
SIM   := $(BUILD)/tb_baby_spi_top.vvp

.PHONY: sim wave lint clean

sim: $(SIM)
	vvp -N $(SIM)

wave: $(SIM)
	vvp -N $(SIM) +wave
	gtkwave $(BUILD)/tb_baby_spi_top.vcd

lint:
	verilator --lint-only -Wall --top-module baby_spi_top $(RTL)

$(SIM): $(RTL) $(TB)
	@mkdir -p $(BUILD)
	iverilog -g2012 -Wall -o $@ $(TB) $(RTL)

clean:
	rm -rf $(BUILD)
