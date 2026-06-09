library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpld_flash_boot is
	port(
		clk_i          : in std_logic;

		fpga_conf_done : in std_logic;
		fpga_data0     : out std_logic;
		fpga_nconfig   : out std_logic;
		fpga_dclk      : out std_logic;

		fake_conf_done : out std_logic;
		fake_data0     : in std_logic;
		fake_nconfig   : in std_logic;
		fake_dclk      : in std_logic;

		flash_so       : in std_logic;
		flash_si       : out std_logic;
		flash_sck      : out std_logic;
		flash_ncs      : out std_logic;
		flash_nreset   : out std_logic;
		flash_nwp      : out std_logic
	);
end entity;

architecture behavioral of cpld_flash_boot is
	attribute chip_pin : string;
	attribute chip_pin of clk_i          : signal is "87";
	attribute chip_pin of fpga_conf_done : signal is "16";
	attribute chip_pin of fpga_dclk      : signal is "63";
	attribute chip_pin of fpga_nconfig   : signal is "67";
	attribute chip_pin of fpga_data0     : signal is "68";
	attribute chip_pin of fake_dclk      : signal is "57";
	attribute chip_pin of fake_conf_done : signal is "58";
	attribute chip_pin of fake_data0     : signal is "61";
	attribute chip_pin of fake_nconfig   : signal is "60";
	attribute chip_pin of flash_so       : signal is "21";
	attribute chip_pin of flash_si       : signal is "22";
	attribute chip_pin of flash_sck      : signal is "23";
	attribute chip_pin of flash_ncs      : signal is "24";
	attribute chip_pin of flash_nreset   : signal is "27";
	attribute chip_pin of flash_nwp      : signal is "28";

	attribute altera_attribute : string;

	constant ST_RESET_HOLD   : natural := 0;
	constant ST_RELEASE_WAIT : natural := 1;
	constant ST_CMD          : natural := 2;
	constant ST_READ         : natural := 3;
	constant ST_SEND_SETUP   : natural := 4;
	constant ST_SEND         : natural := 5;
	constant ST_EXTRA        : natural := 6;
	constant ST_DONE         : natural := 7;

	constant S_RESET_HOLD   : std_logic_vector(7 downto 0) := "00000001";
	constant S_RELEASE_WAIT : std_logic_vector(7 downto 0) := "00000010";
	constant S_CMD          : std_logic_vector(7 downto 0) := "00000100";
	constant S_READ         : std_logic_vector(7 downto 0) := "00001000";
	constant S_SEND_SETUP   : std_logic_vector(7 downto 0) := "00010000";
	constant S_SEND         : std_logic_vector(7 downto 0) := "00100000";
	constant S_EXTRA        : std_logic_vector(7 downto 0) := "01000000";
	constant S_DONE         : std_logic_vector(7 downto 0) := "10000000";

	signal clk_div        : unsigned(2 downto 0) := (others => '0');
	signal clk_en         : std_logic := '0';
	attribute altera_attribute of clk_en : signal is "-name GLOBAL_SIGNAL ON";

	signal state          : std_logic_vector(7 downto 0) := S_RESET_HOLD;
	signal wait_counter   : unsigned(18 downto 0) := (others => '0');
	signal phase          : std_logic := '0';
	signal cmd_count      : unsigned(5 downto 0) := (others => '0');
	signal bit_pos        : unsigned(2 downto 0) := (others => '0');
	signal extra_count    : unsigned(5 downto 0) := (others => '0');
	signal read_shift     : std_logic_vector(7 downto 0) := (others => '0');

	signal conf_done_meta : std_logic := '0';
	signal conf_done_sync : std_logic := '0';

	signal fpga_data0_r   : std_logic := '0';
	signal fpga_nconfig_r : std_logic := '0';
	signal fpga_dclk_r    : std_logic := '0';
	signal flash_sck_r    : std_logic := '0';
	signal flash_ncs_r    : std_logic := '1';
begin
	fpga_data0   <= fake_data0 when state(ST_DONE) = '1' else fpga_data0_r;
	fpga_nconfig <= fake_nconfig when state(ST_DONE) = '1' else fpga_nconfig_r;
	fpga_dclk    <= fake_dclk when state(ST_DONE) = '1' else fpga_dclk_r;
	fake_conf_done <= '0' when state(ST_DONE) = '1' and fpga_conf_done = '0' else 'Z';

	flash_si <= '1' when state(ST_CMD) = '1' and
		(cmd_count = "000100" or cmd_count = "000110" or cmd_count = "000111")
		else '0';
	flash_sck    <= flash_sck_r;
	flash_ncs    <= flash_ncs_r;
	flash_nreset <= '1';
	flash_nwp    <= '1';

	process(clk_i)
	begin
		if rising_edge(clk_i) then
			clk_div <= clk_div + 1;
			conf_done_meta <= fpga_conf_done;

			if clk_div = "111" then
				clk_en <= '1';
			else
				clk_en <= '0';
			end if;

			if clk_en = '1' then
				conf_done_sync <= conf_done_meta;

				if state(ST_RESET_HOLD) = '1' then
					fpga_nconfig_r <= '0';
					fpga_dclk_r <= '0';
					fpga_data0_r <= '0';
					flash_ncs_r <= '1';
					flash_sck_r <= '0';
					phase <= '0';

					if wait_counter(18) = '1' then
						wait_counter <= (others => '0');
						fpga_nconfig_r <= '1';
						state <= S_RELEASE_WAIT;
					else
						wait_counter <= wait_counter + 1;
					end if;

				elsif state(ST_RELEASE_WAIT) = '1' then
					if wait_counter(10) = '1' then
						wait_counter <= (others => '0');
						flash_ncs_r <= '0';
						cmd_count <= (others => '0');
						phase <= '0';
						state <= S_CMD;
					else
						wait_counter <= wait_counter + 1;
					end if;

				elsif state(ST_CMD) = '1' then
					phase <= not phase;

					if phase = '0' then
						flash_sck_r <= '1';
					else
						flash_sck_r <= '0';

						if cmd_count = "100111" then
							bit_pos <= "111";
							read_shift <= (others => '0');
							state <= S_READ;
						else
							cmd_count <= cmd_count + 1;
						end if;
					end if;

				elsif state(ST_READ) = '1' then
					phase <= not phase;

					if phase = '0' then
						flash_sck_r <= '1';
					else
						flash_sck_r <= '0';
						read_shift <= read_shift(6 downto 0) & flash_so;

						if bit_pos = "000" then
							state <= S_SEND_SETUP;
						else
							bit_pos <= bit_pos - 1;
						end if;
					end if;

				elsif state(ST_SEND_SETUP) = '1' then
					fpga_dclk_r <= '0';
					bit_pos <= (others => '0');
					phase <= '0';

					if conf_done_sync = '1' then
						fpga_data0_r <= '0';
						extra_count <= (others => '0');
						state <= S_EXTRA;
					else
						fpga_data0_r <= read_shift(0);
						state <= S_SEND;
					end if;

				elsif state(ST_SEND) = '1' then
					phase <= not phase;

					if phase = '0' then
						fpga_dclk_r <= '1';
					else
						fpga_dclk_r <= '0';

						if conf_done_sync = '1' then
							fpga_data0_r <= '0';
							extra_count <= (others => '0');
							state <= S_EXTRA;
						elsif bit_pos = "111" then
							read_shift <= (others => '0');
							bit_pos <= "111";
							state <= S_READ;
						else
							bit_pos <= bit_pos + 1;
							read_shift <= '0' & read_shift(7 downto 1);
							fpga_data0_r <= read_shift(1);
						end if;
					end if;

				elsif state(ST_EXTRA) = '1' then
					fpga_data0_r <= '0';
					phase <= not phase;

					if phase = '0' then
						fpga_dclk_r <= '1';
					else
						fpga_dclk_r <= '0';

						if extra_count = "111111" then
							flash_ncs_r <= '1';
							state <= S_DONE;
						else
							extra_count <= extra_count + 1;
						end if;
					end if;

				elsif state(ST_DONE) = '1' then
					fpga_nconfig_r <= '1';
					fpga_dclk_r <= '0';
					fpga_data0_r <= '0';
					flash_ncs_r <= '1';
					flash_sck_r <= '0';

				else
					state <= S_RESET_HOLD;
					wait_counter <= (others => '0');
					phase <= '0';
				end if;
			end if;
		end if;
	end process;
end architecture;
