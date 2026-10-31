# Digilent Arty S7-25 pinout for baby_spi_top. SPI uses the ChipKit SPI header.

# 12 MHz system clock
set_property -dict {PACKAGE_PIN F14 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 83.333 -name sys_clk_pin [get_ports clk]

# BTN0 is the reset, SW0 is the status input
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS33} [get_ports rst]
set_property -dict {PACKAGE_PIN H14 IOSTANDARD LVCMOS33} [get_ports sw]

# RGB LED 0: led[0] is red, led[1] is green
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVCMOS33} [get_ports {led[1]}]

# SPI
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS33} [get_ports spi_cs_n]
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports spi_mosi]
set_property -dict {PACKAGE_PIN K14 IOSTANDARD LVCMOS33} [get_ports spi_miso]
set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS33} [get_ports spi_sclk]

# These inputs are synchronized inside the design
set_false_path -from [get_ports {rst sw spi_cs_n spi_mosi spi_sclk}]
set_false_path -to [get_ports {led[*] spi_miso}]

# Configuration
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
