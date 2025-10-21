# Creating the timing netlist, and ensuring it's complete
create_timing_netlist
read_sdc
update_timing_netlist

# Set the filter here
set filter "divider|*"

# Providing reports into an HTML file
report_clocks -file reports/clocks.html
report_timing -file reports/timing.html -npath 50
report_net_timing -file reports/delay.html -nworst_delay 20 $filter
report_net_timing -file reports/fanout.html -nworst_fanout 20 $filter