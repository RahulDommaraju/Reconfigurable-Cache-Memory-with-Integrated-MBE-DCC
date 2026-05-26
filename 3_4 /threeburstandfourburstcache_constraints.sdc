# ####################################################################

#  Created by Genus(TM) Synthesis Solution 21.14-s082_1 on Tue May 12 22:41:07 IST 2026

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design ECC_Cache_System

create_clock -name "clk" -period 10.0 -waveform {0.0 5.0} [get_ports clk]
set_load -pin_load 0.05 [get_ports {data_out[8]}]
set_load -pin_load 0.05 [get_ports {data_out[9]}]
set_load -pin_load 0.05 [get_ports {data_out[10]}]
set_load -pin_load 0.05 [get_ports {data_out[11]}]
set_load -pin_load 0.05 [get_ports {data_out[12]}]
set_load -pin_load 0.05 [get_ports {data_out[13]}]
set_load -pin_load 0.05 [get_ports {data_out[14]}]
set_load -pin_load 0.05 [get_ports {data_out[15]}]
set_load -pin_load 0.05 [get_ports {data_out[16]}]
set_load -pin_load 0.05 [get_ports {data_out[17]}]
set_load -pin_load 0.05 [get_ports {data_out[18]}]
set_load -pin_load 0.05 [get_ports {data_out[19]}]
set_load -pin_load 0.05 [get_ports {data_out[20]}]
set_load -pin_load 0.05 [get_ports {data_out[21]}]
set_load -pin_load 0.05 [get_ports {data_out[22]}]
set_load -pin_load 0.05 [get_ports {data_out[23]}]
set_load -pin_load 0.05 [get_ports hit]
set_false_path -from [get_ports rst]
set_clock_gating_check -setup 0.0 
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {data_out[8]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {data_out[9]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {data_out[10]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {data_out[11]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {data_out[12]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {data_out[13]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {data_out[14]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {data_out[15]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {data_out[16]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {data_out[17]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {data_out[18]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {data_out[19]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {data_out[20]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {data_out[21]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {data_out[22]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {data_out[23]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports hit]
set_clock_uncertainty -setup 0.1 [get_clocks clk]
set_clock_uncertainty -hold 0.1 [get_clocks clk]
