library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity blinky is
	generic(clock_freq: integer := 50e6);

	port(
        clk_i: in std_logic;
		led_o: out std_logic
		);
end entity;

architecture behavioral of blinky is
	signal output : std_logic := '0';
	signal counter : integer range 0 to clock_freq := 0;	 
begin
	led_o <= output;	
	
	process(clk_i)
	begin
		if (rising_edge(clk_i)) then
			if (counter = clock_freq-1) then
				counter <= 0;
				output <= not output;
			else
				counter <= counter + 1;
			end if;
		end if;
	end process;	
			
end;

