library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- SPI Master controller for AT45DB041B flash memory
-- Operates in SPI Mode 0 (CPOL=0, CPHA=0)
entity spi_master is
    port(
        clk_i       : in  std_logic;
        reset_i     : in  std_logic;
        
        -- Command interface
        start_i     : in  std_logic;
        busy_o      : out std_logic;
        tx_data_i   : in  std_logic_vector(7 downto 0);
        rx_data_o   : out std_logic_vector(7 downto 0);
        rx_valid_o  : out std_logic;
        
        -- SPI interface
        sck_o       : out std_logic;
        mosi_o      : out std_logic;
        miso_i      : in  std_logic
    );
end entity;

architecture rtl of spi_master is
    -- SPI clock divider (80MHz / 16 = 5MHz SPI clock)
    constant CLK_DIV : integer := 8;
    
    type state_t is (IDLE, SHIFT);
    signal state : state_t := IDLE;
    
    signal bit_counter : integer range 0 to 7 := 0;
    signal clk_counter : integer range 0 to CLK_DIV-1 := 0;
    signal shift_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_reg      : std_logic_vector(7 downto 0) := (others => '0');
    signal sck_int     : std_logic := '0';
    
begin
    sck_o <= sck_int;
    mosi_o <= shift_reg(7);
    rx_data_o <= rx_reg;
    
    process(clk_i, reset_i)
    begin
        if reset_i = '1' then
            state <= IDLE;
            bit_counter <= 0;
            clk_counter <= 0;
            shift_reg <= (others => '0');
            rx_reg <= (others => '0');
            sck_int <= '0';
            busy_o <= '0';
            rx_valid_o <= '0';
            
        elsif rising_edge(clk_i) then
            rx_valid_o <= '0';
            
            case state is
                when IDLE =>
                    busy_o <= '0';
                    sck_int <= '0';
                    bit_counter <= 0;
                    clk_counter <= 0;
                    
                    if start_i = '1' then
                        shift_reg <= tx_data_i;
                        state <= SHIFT;
                        busy_o <= '1';
                    end if;
                    
                when SHIFT =>
                    if clk_counter = CLK_DIV-1 then
                        clk_counter <= 0;
                        sck_int <= not sck_int;
                        
                        if sck_int = '0' then
                            -- Rising edge of SCK - shift out data
                            null;
                        else
                            -- Falling edge of SCK - sample input and shift
                            rx_reg <= rx_reg(6 downto 0) & miso_i;
                            shift_reg <= shift_reg(6 downto 0) & '0';
                            
                            if bit_counter = 7 then
                                bit_counter <= 0;
                                state <= IDLE;
                                rx_valid_o <= '1';
                            else
                                bit_counter <= bit_counter + 1;
                            end if;
                        end if;
                    else
                        clk_counter <= clk_counter + 1;
                    end if;
            end case;
        end if;
    end process;
    
end architecture;
