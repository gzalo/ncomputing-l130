library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gen_enable is
	generic(modulo: integer);
	port(clk_i: in std_logic;
	     en_o: out std_logic
		);
end entity;

architecture arc_gen_enable of gen_enable is
	signal valor : integer range 0 to modulo-1 := 0;	
begin
	en_o <= '1' when (valor = modulo-1) else '0';
	--Genero el pulso de enable antes de que vuelva a cero el contador

	process(clk_i)
	begin
		if (rising_edge(clk_i)) then
			if (valor = modulo - 1) then
				valor <= 0;
			else
				valor <= valor + 1;
			end if;
		end if;
	end process;
				
end;
