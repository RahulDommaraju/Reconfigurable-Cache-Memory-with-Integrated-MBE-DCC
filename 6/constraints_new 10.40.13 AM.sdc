create_clock -name clk -period 10 [get_ports clk]

set_input_delay 1.0 -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay 1.0 -clock clk [all_outputs]

set_clock_uncertainty 0.1 [get_clocks clk]

set_false_path -from [get_ports rst]

set_load 0.05 [all_outputs]
