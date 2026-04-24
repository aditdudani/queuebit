# XDC Constraints for QueueBit Dispatcher
# Target: ZedBoard (xc7z020clg484-1)
# Purpose: Define clock timing, I/O standards, and basic placement hints

# Primary clock constraint
# Assuming 100 MHz reference clock from ZedBoard
create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]

# Set clock as the primary clock group
set_clock_groups -asynchronous -group [get_clocks clk]

# I/O Standards for clock port (LVCMOS33 standard on ZedBoard)
# Uncomment if clock is a primary I/O port (not coming from processor)
# set_property IOSTANDARD LVCMOS33 [get_ports clk]
# set_property LOC A9 [get_ports clk]

# Optional: Reset signal (typically async, no timing constraint needed)
# set_property ASYNC_REG TRUE [get_cells [get_cells -hier -filter {NAME =~ *rst*}]]

# Timing exception: None currently
# (Dispatcher is fully synchronous with no timing-critical paths across clock domains)

# Area/timing trade-off notes:
# - Default placement is fine for d=11 and d=23
# - If timing closure fails at >120 MHz, try relaxing clock period to 8.333ns (120 MHz)
