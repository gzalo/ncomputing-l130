library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_fpga is
	port(
        clk_i: in std_logic;
		  led_2: out std_logic;
		  led_3: out std_logic
		);
end entity;
	
architecture behavioral of top_fpga is
begin
	blink: entity work.blinky generic map(clock_freq=>10e6) port map(clk_i=>clk_i, led_o=>led_2);
	blink2: entity work.blinky generic map(clock_freq=>15e6) port map(clk_i=>clk_i, led_o=>led_3);
end;	