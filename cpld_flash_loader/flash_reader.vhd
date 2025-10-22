library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Flash reader for AT45DB041B
-- Reads continuous array data starting from address 0
entity flash_reader is
    port(
        clk_i       : in  std_logic;
        reset_i     : in  std_logic;
        
        -- Control interface
        start_i     : in  std_logic;
        done_o      : out std_logic;
        
        -- Data output
        data_o      : out std_logic_vector(7 downto 0);
        data_valid_o: out std_logic;
        
        -- SPI master interface
        spi_tx_data_o   : out std_logic_vector(7 downto 0);
        spi_rx_data_i   : in  std_logic_vector(7 downto 0);
        spi_start_o     : out std_logic;
        spi_busy_i      : in  std_logic;
        spi_rx_valid_i  : in  std_logic;
        
        -- Flash chip select (active low)
        cs_n_o      : out std_logic
    );
end entity;

architecture rtl of flash_reader is
    -- AT45DB041B commands
    constant CMD_CONTINUOUS_READ : std_logic_vector(7 downto 0) := x"E8";
    
    type state_t is (IDLE, CS_ASSERT, SEND_CMD, SEND_ADDR1, SEND_ADDR2, 
                     SEND_ADDR3, SEND_DUMMY, READ_DATA, DONE);
    signal state : state_t := IDLE;
    signal next_state : state_t := IDLE;
    
    signal byte_count : unsigned(23 downto 0) := (others => '0');
    signal spi_start_reg : std_logic := '0';
    
begin
    cs_n_o <= '0' when (state /= IDLE and state /= DONE) else '1';
    spi_start_o <= spi_start_reg;
    
    process(clk_i, reset_i)
    begin
        if reset_i = '1' then
            state <= IDLE;
            next_state <= IDLE;
            done_o <= '0';
            data_valid_o <= '0';
            spi_start_reg <= '0';
            byte_count <= (others => '0');
            
        elsif rising_edge(clk_i) then
            -- Default outputs
            data_valid_o <= '0';
            done_o <= '0';
            
            case state is
                when IDLE =>
                    spi_start_reg <= '0';
                    byte_count <= (others => '0');
                    
                    if start_i = '1' then
                        state <= CS_ASSERT;
                        next_state <= SEND_CMD;
                    end if;
                    
                when CS_ASSERT =>
                    -- Wait one clock for CS to settle
                    state <= next_state;
                    
                when SEND_CMD =>
                    if spi_busy_i = '0' and spi_start_reg = '0' then
                        spi_tx_data_o <= CMD_CONTINUOUS_READ;
                        spi_start_reg <= '1';
                        next_state <= SEND_ADDR1;
                    elsif spi_rx_valid_i = '1' then
                        spi_start_reg <= '0';
                        state <= next_state;
                    else
                        spi_start_reg <= '0';
                    end if;
                    
                when SEND_ADDR1 =>
                    -- Address bits 23:16 (all zeros)
                    if spi_busy_i = '0' and spi_start_reg = '0' then
                        spi_tx_data_o <= x"00";
                        spi_start_reg <= '1';
                        next_state <= SEND_ADDR2;
                    elsif spi_rx_valid_i = '1' then
                        spi_start_reg <= '0';
                        state <= next_state;
                    else
                        spi_start_reg <= '0';
                    end if;
                    
                when SEND_ADDR2 =>
                    -- Address bits 15:8 (all zeros)
                    if spi_busy_i = '0' and spi_start_reg = '0' then
                        spi_tx_data_o <= x"00";
                        spi_start_reg <= '1';
                        next_state <= SEND_ADDR3;
                    elsif spi_rx_valid_i = '1' then
                        spi_start_reg <= '0';
                        state <= next_state;
                    else
                        spi_start_reg <= '0';
                    end if;
                    
                when SEND_ADDR3 =>
                    -- Address bits 7:0 (all zeros)
                    if spi_busy_i = '0' and spi_start_reg = '0' then
                        spi_tx_data_o <= x"00";
                        spi_start_reg <= '1';
                        next_state <= SEND_DUMMY;
                    elsif spi_rx_valid_i = '1' then
                        spi_start_reg <= '0';
                        state <= next_state;
                    else
                        spi_start_reg <= '0';
                    end if;
                    
                when SEND_DUMMY =>
                    -- Send dummy bytes (required by continuous read command)
                    if spi_busy_i = '0' and spi_start_reg = '0' then
                        spi_tx_data_o <= x"00";
                        spi_start_reg <= '1';
                        next_state <= READ_DATA;
                    elsif spi_rx_valid_i = '1' then
                        spi_start_reg <= '0';
                        state <= next_state;
                    else
                        spi_start_reg <= '0';
                    end if;
                    
                when READ_DATA =>
                    -- Continuously read data bytes
                    if spi_busy_i = '0' and spi_start_reg = '0' then
                        spi_tx_data_o <= x"00";  -- Dummy data for reading
                        spi_start_reg <= '1';
                    elsif spi_rx_valid_i = '1' then
                        data_o <= spi_rx_data_i;
                        data_valid_o <= '1';
                        byte_count <= byte_count + 1;
                        spi_start_reg <= '0';
                        
                        -- Continue reading indefinitely until external reset/stop
                        -- The FPGA will signal CONF_DONE when complete
                    else
                        spi_start_reg <= '0';
                    end if;
                    
                when DONE =>
                    done_o <= '1';
                    state <= IDLE;
            end case;
        end if;
    end process;
    
end architecture;
