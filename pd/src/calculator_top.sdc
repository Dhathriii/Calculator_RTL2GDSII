# =============================================================
# calculator_top.sdc
# Basic Synopsys Design Constraints for synthesis / STA / OpenLane.
# Adjust CLOCK_PERIOD based on the timing your synthesis run
# actually achieves (start conservative, then tighten).
# =============================================================

set clk_name  clk
set clk_port_name clk
set clk_period 20.0    ;# 20 ns period = 50 MHz, generous starting point

create_clock -name $clk_name -period $clk_period [get_ports $clk_port_name]

# I/O delay budgets (fractions of the clock period)
set_input_delay  [expr {$clk_period * 0.2}] -clock $clk_name [remove_from_collection [all_inputs] [get_ports $clk_port_name]]
set_output_delay [expr {$clk_period * 0.2}] -clock $clk_name [all_outputs]

# Reset is asynchronous - don't constrain it as a data path
set_false_path -from [get_ports rst_n]
