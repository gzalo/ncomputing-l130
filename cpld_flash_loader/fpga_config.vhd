library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- FPGA Configuration Controller for Cyclone EP1C6
-- Implements Passive Serial (PS) configuration protocol
entity fpga_config is
    port(
        clk_i           : in  std_logic;
        reset_i         : in  std_logic;
        
        -- Control interface
        start_i         : in  std_logic;
        done_o          : out std_logic;
        error_o         : out std_logic;
        
        -- Data input (bitstream from flash)
        data_i          : in  std_logic_vector(7 downto 0);
        data_valid_i    : in  std_logic;
        data_req_o      : out std_logic;  -- Request more data
        
        -- FPGA configuration interface
        fpga_nconfig_o  : out std_logic;
        fpga_conf_done_i: in  std_logic;
        fpga_data0_o    : out std_logic;
        fpga_dclk_o     : out std_logic
    );
end entity;

architecture rtl of fpga_config is
    type state_t is (IDLE, ASSERT_NCONFIG, WAIT_RELEASE, 
                     CONFIGURE, STARTUP, DONE_STATE, ERROR_STATE);
    signal state : state_t := IDLE;
    
    signal bit_counter : integer range 0 to 7 := 0;
    signal data_reg    : std_logic_vector(7 downto 0) := (others => '0');
    signal dclk_int    : std_logic := '0';
    signal clk_div     : integer range 0 to 3 := 0;  -- Divide by 4 for DCLK
    signal wait_counter: integer range 0 to 10000 := 0;
    
    -- Startup counter for initialization sequence
    signal startup_counter : integer range 0 to 10000 := 0;
    
begin
    fpga_dclk_o <= dclk_int;
    fpga_data0_o <= data_reg(7);  -- MSB first
    
    process(clk_i, reset_i)
    begin
        if reset_i = '1' then
            state <= IDLE;
            fpga_nconfig_o <= '1';
            dclk_int <= '0';
            bit_counter <= 0;
            data_reg <= (others => '0');
            done_o <= '0';
            error_o <= '0';
            data_req_o <= '0';
            clk_div <= 0;
            wait_counter <= 0;
            startup_counter <= 0;
            
        elsif rising_edge(clk_i) then
            case state is
                when IDLE =>
                    fpga_nconfig_o <= '1';
                    dclk_int <= '0';
                    done_o <= '0';
                    error_o <= '0';
                    data_req_o <= '0';
                    startup_counter <= 0;
                    
                    if start_i = '1' then
                        state <= ASSERT_NCONFIG;
                        wait_counter <= 0;
                    end if;
                    
                when ASSERT_NCONFIG =>
                    -- Assert nCONFIG low to initiate configuration
                    fpga_nconfig_o <= '0';
                    wait_counter <= wait_counter + 1;
                    
                    -- Hold nCONFIG low for at least 500ns (40 clocks @ 80MHz)
                    -- Extended to be safe: 2us
                    if wait_counter >= 200 then
                        state <= WAIT_RELEASE;
                        wait_counter <= 0;
                    end if;
                    
                when WAIT_RELEASE =>
                    -- Release nCONFIG and wait for FPGA to be ready
                    -- Since we don't have access to nSTATUS, we wait a fixed time
                    -- The FPGA datasheet specifies max 200us for the FPGA to become ready
                    fpga_nconfig_o <= '1';
                    wait_counter <= wait_counter + 1;
                    
                    -- Wait 200us @ 80MHz = 16000 clocks (use 20000 for margin)
                    if wait_counter >= 20000 then
                        state <= CONFIGURE;
                        bit_counter <= 0;
                        data_req_o <= '1';
                        clk_div <= 0;
                        wait_counter <= 0;
                    end if;
                    
                when CONFIGURE =>
                    -- Send configuration data
                    data_req_o <= '0';
                    
                    -- Check if configuration is complete
                    if fpga_conf_done_i = '1' then
                        -- Configuration complete
                        state <= STARTUP;
                        startup_counter <= 0;
                    else
                        -- Clock divider for DCLK (80MHz / 4 = 20MHz)
                        if clk_div = 3 then
                            clk_div <= 0;
                            dclk_int <= not dclk_int;
                            
                            if dclk_int = '1' then
                                -- Falling edge of DCLK
                                if bit_counter = 7 then
                                    bit_counter <= 0;
                                    data_req_o <= '1';  -- Request next byte
                                else
                                    bit_counter <= bit_counter + 1;
                                    data_reg <= data_reg(6 downto 0) & '0';
                                end if;
                            end if;
                        else
                            clk_div <= clk_div + 1;
                        end if;
                        
                        -- Load new data when available
                        if data_valid_i = '1' then
                            data_reg <= data_i;
                            data_req_o <= '0';
                        end if;
                    end if;
                    
                when STARTUP =>
                    -- Send additional clocks for initialization
                    -- Cyclone requires ~100 clocks after CONF_DONE
                    if startup_counter < 200 then
                        startup_counter <= startup_counter + 1;
                        
                        if clk_div = 3 then
                            clk_div <= 0;
                            dclk_int <= not dclk_int;
                        else
                            clk_div <= clk_div + 1;
                        end if;
                    else
                        state <= DONE_STATE;
                        dclk_int <= '0';
                    end if;
                    
                when DONE_STATE =>
                    done_o <= '1';
                    dclk_int <= '0';
                    -- Stay in this state until reset
                    
                when ERROR_STATE =>
                    error_o <= '1';
                    dclk_int <= '0';
                    -- Stay in this state until reset
            end case;
        end if;
    end process;
    
end architecture;
