library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_blinky is
end entity;

architecture behavioral of tb_blinky is
	signal clk_t: std_logic := '0';
	signal out_t: std_logic;
begin
	bloque: entity work.blinky generic map(clock_freq=>1e3) port map(clk_i=>clk_t, led_o=>out_t);
	-- f = 1 KHz
	clk_t <= not clk_t after 0.5 ms;
end;	
