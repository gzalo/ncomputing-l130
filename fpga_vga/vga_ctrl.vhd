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
	-- 640x480 VGA timing: sync, back porch, visible area, front porch.
	constant hpixels: unsigned(9 downto 0) := to_unsigned(800, 10);
	constant vlines: unsigned(9 downto 0) := to_unsigned(525, 10);
	constant hpixels_last: unsigned(9 downto 0) := hpixels - 1;
	constant vlines_last: unsigned(9 downto 0) := vlines - 1;
	
	constant hsc: unsigned(9 downto 0) := to_unsigned(96, 10);
	constant hbp: unsigned(9 downto 0) := to_unsigned(144, 10);
	constant hfp: unsigned(9 downto 0) := to_unsigned(784, 10);
	constant vsc: unsigned(9 downto 0) := to_unsigned(2, 10);
	constant vbp: unsigned(9 downto 0) := to_unsigned(35, 10);
	constant vfp: unsigned(9 downto 0) := to_unsigned(515, 10);

	-- Contadores de línea y pixel
	signal hc, vc: unsigned(9 downto 0) := "0000000000";	
begin
    process(pixel_clk)
    begin
        if rising_edge(pixel_clk) then
				 if hc = hpixels_last then
					  hc <= (others => '0');
					  if vc = vlines_last then
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
