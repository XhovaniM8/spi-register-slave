# spi-register-slave

A small SPI slave in Verilog-2005 that gives an SPI master read and write access
to a bank of registers. It is written to be easy to read and to reuse: the SPI
logic and the register map are separate modules, and everything runs on one clock.

> This was an old project of mine (2021), I decided to just organize using Claude and push it for "historical" purposes. 

## Features

- SPI mode 0, MSB first, 16-bit frames with 7-bit addresses and 8-bit data
- Address and data widths are parameters of `spi_slave`
- Single clock domain, with `sclk` oversampled instead of used as a clock
- `miso` is high impedance while deselected, so the bus can be shared
- Self-checking testbench that runs on free tools

## Layout

```
rtl/spi_slave.v       SPI protocol, with a simple register bus on the other side
rtl/spi_regs.v        Example register map (replace this with your own)
rtl/baby_spi_top.v    Connects the two, and synchronizes reset and the switch
tb/                   Self-checking testbench
fpga/arty_s7/         Pinout and build script for the Digilent Arty S7-25
```

## Getting started

Simulation needs [Icarus Verilog](https://github.com/steveicarus/iverilog). Linting
needs [Verilator](https://www.veripool.org/verilator/), and `make wave` needs GTKWave.

```sh
make sim    # Run the testbench; exits non-zero on failure
make lint   # Run Verilator with -Wall
make wave   # Run the testbench and open the waveforms
```

To build the Arty S7-25 bitstream with Vivado:

```sh
vivado -mode batch -source fpga/arty_s7/build.tcl
```

The bitstream is written to `build/arty_s7/`. The design has been verified in
simulation, but the Vivado build has not been run and it has not been tested on a board.

## Protocol

Hold `cs_n` low for the whole frame. The master changes `mosi` on the falling edge of
`sclk` and samples `miso` on the rising edge, and `sclk` idles low.

```
bit     15   14 ... 8   7 ... 0
       +---+----------+---------+
       |R/W|  A[6:0]  | D[7:0]  |
       +---+----------+---------+
```

| R/W | Operation | D[7:0] |
| --- | --------- | ------ |
| 0 | Write | Sent by the master on `mosi` |
| 1 | Read | Sent by the slave on `miso` |

- A write takes effect on the last rising edge of `sclk`. If `cs_n` rises before then, nothing is written.
- `miso` reads as 0 during the first 8 bits of a frame and after the data byte.
- Clock cycles after the end of a frame are ignored. Raise `cs_n` before the next frame.

### Timing

`clk` must be at least 8 times the `sclk` frequency, so the 12 MHz clock on the Arty
S7-25 allows `sclk` up to 1.5 MHz. In simulation the design works down to about 5 times,
and the remaining margin covers board delays and master setup time.

Hold `cs_n` low for at least one `sclk` half period before the first rising edge of
`sclk`, and after the last falling edge.

## Registers

| Address | Name | Access | Reset | Description |
| ------- | ---- | ------ | ----- | ----------- |
| `0x00` | `ID` | R | `0xB5` | Fixed value for checking the connection |
| `0x01` | `VERSION` | R | `0x01` | Design version |
| `0x02` | `STATUS` | R | - | Bit 0 is the state of the `sw` input |
| `0x03` | `CONTROL` | R/W | `0x00` | Bits 1:0 drive `led[1:0]` |
| `0x04`-`0x07` | `SCRATCH0`-`SCRATCH3` | R/W | `0x00` | General-purpose storage |

Other addresses read as `0x00` and ignore writes.

## Using your own registers

Replace `spi_regs` with your own logic, or connect directly to the bus on `spi_slave`:

| Signal | Direction | Description |
| ------ | --------- | ----------- |
| `reg_addr` | Output | Register address, valid from the end of the address phase |
| `reg_wdata` | Output | Write data, valid while `reg_we` is high |
| `reg_we` | Output | One-`clk` write pulse |
| `reg_rdata` | Input | Read data, which must be valid by the next falling edge of `sclk` |

## License

[MIT](LICENSE)
