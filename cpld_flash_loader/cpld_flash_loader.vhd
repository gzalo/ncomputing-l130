library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Top-level module for CPLD flash loader
-- Reads FPGA bitstream from AT45DB041B serial flash on startup
-- and configures the FPGA using Passive Serial mode
entity cpld_flash_loader is
    port(
        -- System clock (80 MHz)
        clk_i           : in  std_logic;
        
        -- LED for status indication
        led_o           : out std_logic;
        
        -- FPGA configuration interface (Passive Serial)
        fpga_conf_done  : in  std_logic;
        fpga_data0      : out std_logic;
        fpga_nconfig    : out std_logic;
        fpga_dclk       : out std_logic;
        
        -- Flash memory interface (SPI)
        flash_sck       : out std_logic;
        flash_si        : out std_logic;  -- MOSI
        flash_so        : in  std_logic;  -- MISO
        flash_cs_n      : out std_logic;
        flash_reset_n   : out std_logic;
        flash_wp_n      : out std_logic
    );
end entity;

architecture behavioral of cpld_flash_loader is
    -- Pin assignments for EPM3128ATC100-10N
    attribute chip_pin : string;
    attribute chip_pin of clk_i         : signal is "87";  -- 80MHz clock
    attribute chip_pin of led_o         : signal is "1";   -- Status LED
    attribute chip_pin of fpga_data0    : signal is "68";  -- FPGA DATA0
    attribute chip_pin of fpga_dclk     : signal is "63";  -- FPGA DCLK
    attribute chip_pin of fpga_nconfig  : signal is "67";  -- FPGA nCONFIG
    attribute chip_pin of fpga_conf_done: signal is "16";  -- FPGA CONF_DONE
    attribute chip_pin of flash_sck     : signal is "23";  -- Flash SCK
    attribute chip_pin of flash_si      : signal is "22";  -- Flash SI (MOSI)
    attribute chip_pin of flash_so      : signal is "21";  -- Flash SO (MISO)
    attribute chip_pin of flash_cs_n    : signal is "24";  -- Flash CS#
    attribute chip_pin of flash_reset_n : signal is "27";  -- Flash RESET#
    attribute chip_pin of flash_wp_n    : signal is "28";  -- Flash WP#
    
    -- Internal signals
    signal reset            : std_logic := '1';
    signal reset_counter    : integer range 0 to 80000000 := 0;  -- ~1 second
    signal config_start     : std_logic := '0';
    signal config_done      : std_logic := '0';
    signal config_error     : std_logic := '0';
    
    -- Flash reader signals
    signal flash_data       : std_logic_vector(7 downto 0);
    signal flash_data_valid : std_logic;
    signal flash_start      : std_logic := '0';
    signal flash_done       : std_logic;
    
    -- SPI master signals
    signal spi_tx_data      : std_logic_vector(7 downto 0);
    signal spi_rx_data      : std_logic_vector(7 downto 0);
    signal spi_start        : std_logic;
    signal spi_busy         : std_logic;
    signal spi_rx_valid     : std_logic;
    signal spi_mosi         : std_logic;
    signal spi_sck          : std_logic;
    
    -- FPGA config signals
    signal data_req         : std_logic;
    
    -- LED control
    signal led_state        : std_logic := '0';
    
    type main_state_t is (RESET_STATE, START_CONFIG, CONFIGURING, DONE_STATE, ERROR_STATE);
    signal main_state : main_state_t := RESET_STATE;
    
begin
    -- Flash control signals (always enabled)
    flash_reset_n <= '1';  -- Not in reset
    flash_wp_n <= '1';     -- Write protect disabled (not needed for reading)
    
    -- Route SPI signals
    flash_sck <= spi_sck;
    flash_si <= spi_mosi;
    
    -- LED blinker for visual feedback
    blink: entity work.blinky 
        generic map(clock_freq => 80e6) 
        port map(clk_i => clk_i, led_o => led_state);
    
    -- LED shows different patterns based on state
    led_o <= led_state when main_state = CONFIGURING else
             '1' when main_state = DONE_STATE else
             '0' when main_state = ERROR_STATE else
             not led_state;
    
    -- SPI Master
    spi_master_inst: entity work.spi_master
        port map(
            clk_i       => clk_i,
            reset_i     => reset,
            start_i     => spi_start,
            busy_o      => spi_busy,
            tx_data_i   => spi_tx_data,
            rx_data_o   => spi_rx_data,
            rx_valid_o  => spi_rx_valid,
            sck_o       => spi_sck,
            mosi_o      => spi_mosi,
            miso_i      => flash_so
        );
    
    -- Flash Reader
    flash_reader_inst: entity work.flash_reader
        port map(
            clk_i           => clk_i,
            reset_i         => reset,
            start_i         => flash_start,
            done_o          => flash_done,
            data_o          => flash_data,
            data_valid_o    => flash_data_valid,
            spi_tx_data_o   => spi_tx_data,
            spi_rx_data_i   => spi_rx_data,
            spi_start_o     => spi_start,
            spi_busy_i      => spi_busy,
            spi_rx_valid_i  => spi_rx_valid,
            cs_n_o          => flash_cs_n
        );
    
    -- FPGA Configuration Controller
    fpga_config_inst: entity work.fpga_config
        port map(
            clk_i           => clk_i,
            reset_i         => reset,
            start_i         => config_start,
            done_o          => config_done,
            error_o         => config_error,
            data_i          => flash_data,
            data_valid_i    => flash_data_valid,
            data_req_o      => data_req,
            fpga_nconfig_o  => fpga_nconfig,
            fpga_conf_done_i=> fpga_conf_done,
            fpga_data0_o    => fpga_data0,
            fpga_dclk_o     => fpga_dclk
        );
    
    -- Main state machine
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            -- Power-on reset for ~10ms
            if reset = '1' then
                if reset_counter < 800000 then  -- 10ms @ 80MHz
                    reset_counter <= reset_counter + 1;
                else
                    reset <= '0';
                    reset_counter <= 0;
                end if;
            end if;
            
            -- Main control logic
            case main_state is
                when RESET_STATE =>
                    flash_start <= '0';
                    config_start <= '0';
                    
                    if reset = '0' then
                        main_state <= START_CONFIG;
                    end if;
                    
                when START_CONFIG =>
                    -- Start both flash reader and FPGA config
                    flash_start <= '1';
                    config_start <= '1';
                    main_state <= CONFIGURING;
                    
                when CONFIGURING =>
                    flash_start <= '0';
                    config_start <= '0';
                    
                    if config_done = '1' then
                        main_state <= DONE_STATE;
                    elsif config_error = '1' then
                        main_state <= ERROR_STATE;
                    end if;
                    
                when DONE_STATE =>
                    -- Configuration successful
                    -- Stay here indefinitely
                    null;
                    
                when ERROR_STATE =>
                    -- Configuration failed
                    -- Stay here indefinitely (LED will be off)
                    null;
            end case;
        end if;
    end process;
    
end architecture;
