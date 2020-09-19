set_time_format -unit ns -decimal_places 3

create_clock -name {FPGA_CLK2_50} -period 20 [get_ports {FPGA_CLK2_50}]

create_clock -name {CLK_3M5_CONT} -period 285.71428571429

derive_pll_clocks
derive_clock_uncertainty