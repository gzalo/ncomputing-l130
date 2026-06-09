create_clock -name clk_i -period 12.500 [get_ports {clk_i}]

# clk_div and clk_en run at the real 80 MHz clock.
# Everything below only changes when clk_en pulses once every 8 input clocks.
set sequencer_regs [get_registers -nowarn {*state*}]
set sequencer_regs [add_to_collection $sequencer_regs [get_registers -nowarn {*wait_counter*}]]
set sequencer_regs [add_to_collection $sequencer_regs [get_registers -nowarn {*phase*}]]
set sequencer_regs [add_to_collection $sequencer_regs [get_registers -nowarn {*cmd_count*}]]
set sequencer_regs [add_to_collection $sequencer_regs [get_registers -nowarn {*bit_pos*}]]
set sequencer_regs [add_to_collection $sequencer_regs [get_registers -nowarn {*extra_count*}]]
set sequencer_regs [add_to_collection $sequencer_regs [get_registers -nowarn {*read_shift*}]]
set sequencer_regs [add_to_collection $sequencer_regs [get_registers -nowarn {*conf_done_sync*}]]
set sequencer_regs [add_to_collection $sequencer_regs [get_registers -nowarn {*fpga_data0_r*}]]
set sequencer_regs [add_to_collection $sequencer_regs [get_registers -nowarn {*fpga_nconfig_r*}]]
set sequencer_regs [add_to_collection $sequencer_regs [get_registers -nowarn {*fpga_dclk_r*}]]
set sequencer_regs [add_to_collection $sequencer_regs [get_registers -nowarn {*flash_sck_r*}]]
set sequencer_regs [add_to_collection $sequencer_regs [get_registers -nowarn {*flash_ncs_r*}]]

set_multicycle_path -setup 8 -from $sequencer_regs -to $sequencer_regs
set_multicycle_path -hold 7 -from $sequencer_regs -to $sequencer_regs
