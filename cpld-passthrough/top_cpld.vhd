library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_cpld is
	port(
        clk_i: in std_logic;
		led_o: out std_logic;
		fpga_conf_done: in std_logic;
		fpga_data0: out std_logic;
		fpga_nconfig: out std_logic;
		fpga_dclk: out std_logic;

		fake_conf_done: out std_logic;
		fake_data0: in std_logic;
		fake_nconfig: in std_logic;
		fake_dclk: in std_logic
		);
end entity;
	
architecture behavioral of top_cpld is
begin
	blink: entity work.blinky generic map(clock_freq=>80e6) port map(clk_i=>clk_i, led_o=>led_o);

	fpga_data0 <= fake_data0;
	fpga_nconfig <= fake_nconfig;
	fpga_dclk <= fake_dclk;
	fake_conf_done <= '0' when fpga_conf_done = '0' else 'Z';
	
end;	