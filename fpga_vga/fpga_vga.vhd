library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity fpga_vga is
	port(
        clk_i: in std_logic;
		  vga_r: out std_logic_vector(4 downto 0);
		  vga_g: out std_logic_vector(5 downto 0);
		  vga_b: out std_logic_vector(4 downto 0);
		  vga_hsync: out std_logic;
		  vga_vsync: out std_logic
		);
end entity;
	
architecture behavioral of fpga_vga is
	attribute chip_pin : string;
	attribute chip_pin of clk_i : signal is "28";
	attribute chip_pin of vga_r : signal is "217, 220, 221, 222, 223";
	attribute chip_pin of vga_g : signal is "224, 225, 226, 227, 228, 233";
	attribute chip_pin of vga_b : signal is "169, 170, 168, 167, 166";
	attribute chip_pin of vga_hsync : signal is "207";
	attribute chip_pin of vga_vsync : signal is "208";

	signal pixelClk: std_logic; --Reloj salida del PLL, 25MHz
	
	signal x, y: std_logic_vector(9 downto 0); --Posicion dentro de la pantalla (0-639, 0-479)
	signal visible: std_logic;	--1 si estamos en el area visible
	signal pixelProximo: std_logic; --Proximo pixel a mostrar
	
	signal salidaRom: std_logic;	--Salida de la memoria de caracteres
	signal caracter: std_logic_vector(3 downto 0); --Caracter a mostrar (0-15)
	signal posX, posY: std_logic_vector(4 downto 0); --Posicion dentro del caracter (0-31)
	signal texX, texY: std_logic_vector(4 downto 0); --Posicion del caracter (0-19, 0-14)
	signal centroPantalla: std_logic; --1 si estamos en el medio de la pantalla (fila 8, entre las columnas 6 y 13)
	
	signal enableCounter: std_logic;
	signal counter: unsigned(3 downto 0) := "0000";
	
begin
	pll: entity work.pll port map(clk_i, pixelClk);
	vga: entity work.vga_ctrl port map(pixelClk, vga_hsync, vga_vsync, x, y, visible);
	rom: entity work.char_rom port map(clk_i, caracter, posX, posY, salidaRom);
	gen: entity work.gen_enable generic map(416666) port map(pixelClk, enableCounter);
	
	--640x480 => 20x15 caracteres de 32x32
	
	posX <= x(4 downto 0); --Los bits mas bajos de la posicion
	posY <= y(4 downto 0);
	
	texX <= x(9 downto 5); --Los bits mas altos de la posicion
	texY <= y(9 downto 5); --Los bits mas altos de la posicion
	
	--Caracteres a mostrar
	caracter <=  "0001" 					when texX = "00110" else
				"0011"				  	 	when texX = "00111" else
				"0011" 					   when texX = "01000" else
				"0111" 						when texX = "01001" else
				"1100"  						when texX = "01010" else
				"1101" 					when texX = "01011" else
 				"1110" 					when texX = "01100" else
				std_logic_vector(counter) 	when texX = "01101" else
				"1111";
				
	process(pixelClk)
	begin
		if rising_edge(pixelClk) and enableCounter = '1' then
			counter <= counter + 1;
		end if;
	end process;
				
	centroPantalla <= '1' when texY = "01000" and unsigned(texX) >= 6 and unsigned(texX) <= 13 else '0';
	
	pixelProximo <= '0' when visible = '0' else
					 '0' when visible = '1' and salidaRom = '1' and centroPantalla = '1' else 
			         '1';
	
	process(pixelClk)
	begin
		if rising_edge(pixelClk) then
			if (pixelProximo = '1') then
				vga_r <= (others =>'1');
				vga_g <= (others =>'1');
				vga_b <= (others =>'1');
			else
				vga_r <= (others =>'0');
				vga_g <= (others =>'0');
				vga_b <= (others =>'0');
			end if;
		end if;
	end process;
	
end;	
