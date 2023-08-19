library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_ctrl is
    port (
		pixel_clk: in std_logic;
		hsync: out std_logic;
		vsync: out std_logic;
		pixel_x: out std_logic_vector(9 downto 0);
		pixel_y: out std_logic_vector(9 downto 0);
		visible_region: out std_logic
	);
end vga_ctrl;

architecture behavioral of vga_ctrl is
	-- Pixeles por linea (800)
	constant hpixels: unsigned(9 downto 0) := "1100100000";
	-- Lineas totales (521)
	constant vlines: unsigned(9 downto 0) := "1000001001";
	
	constant hbp: unsigned(9 downto 0) := "0010010000";	 -- Back porch horizontal (144)
	constant hfp: unsigned(9 downto 0) := "1100010000";	 -- Front porch horizontal (784)
	constant vbp: unsigned(9 downto 0) := "0000011111";	 -- Back porch vertical (31)
	constant vfp: unsigned(9 downto 0) := "0111111111";	 -- Front porch vertical (511)
	constant hsc: unsigned(9 downto 0) := "0001100001";	 -- Pixeles de sincronismo
	constant vsc: unsigned(9 downto 0) := "0000000011";	 -- Lineas de sincronismo

	-- Contadores de línea y pixel
	signal hc, vc: unsigned(9 downto 0) := "0000000000";	
begin
    process(pixel_clk)
    begin
        if rising_edge(pixel_clk) then
				 if hc = hpixels then														
					  hc <= (others => '0');
					  if vc = vlines then															 
							vc <= (others => '0');
					  else
							vc <= vc + 1;
					  end if;
				 else
					  hc <= hc + 1;
				 end if;				  
        end if;
    end process;

    hsync <= '0' when hc < hsc else '1'; 
    vsync <= '0' when vc < vsc else '1';

    pixel_x <= std_logic_vector(hc - hbp);    
    pixel_y <= std_logic_vector(vc - vbp);
	
    visible_region <= '1' when (hc < hfp) and (hc >= hbp) and (vc < vfp) and (vc >= vbp) else '0';
	
end behavioral;
