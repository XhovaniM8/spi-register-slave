# Builds the Arty S7-25 bitstream. From the repository root:
#   vivado -mode batch -source fpga/arty_s7/build.tcl

set part   xc7s25csga324-1
set top    baby_spi_top
set outdir build/arty_s7

file mkdir $outdir

read_verilog [glob rtl/*.v]
read_xdc fpga/arty_s7/arty_s7.xdc

synth_design -top $top -part $part
opt_design
place_design
route_design

report_timing_summary -file $outdir/timing.rpt
report_utilization -file $outdir/utilization.rpt
write_bitstream -force $outdir/$top.bit
