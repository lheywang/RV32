# Creating clocks (50 MHz for core, 60 MHz from the ULPI)
create_clock -name clk_in   -period 20.000 [get_ports clk50]
create_clock -name clk_ulpi -period 16.667 [get_ports clk60_iso0]

# Inform quartus that the main clocks and ULPI clocks are asynchronous
set_clock_groups -asynchronous -group [get_clocks clk_in] -group [get_clocks clk_ulpi]

# Adding uncertainty to the clocks
set_clock_uncertainty -setup    -from [get_clocks clk_in]       0.05
set_clock_uncertainty -hold     -from [get_clocks clk_in]       0.05
set_clock_uncertainty -setup    -from [get_clocks clk_ulpi]     0.05
set_clock_uncertainty -hold     -from [get_clocks clk_ulpi]     0.05

# Derivate clocks from the PLLs
derive_pll_clocks

# Derivate the clock uncertaities
derive_clock_uncertainty

