library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Testbench for SPI Master
entity tb_spi_master is
end entity;

architecture sim of tb_spi_master is
    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal start    : std_logic := '0';
    signal busy     : std_logic;
    signal tx_data  : std_logic_vector(7 downto 0) := x"A5";
    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;
    signal sck      : std_logic;
    signal mosi     : std_logic;
    signal miso     : std_logic := '0';
    
    constant CLK_PERIOD : time := 12.5 ns;  -- 80 MHz
    signal test_done : boolean := false;
    
begin
    -- Clock generation
    clk <= not clk after CLK_PERIOD/2 when not test_done;
    
    -- DUT
    dut: entity work.spi_master
        port map(
            clk_i       => clk,
            reset_i     => reset,
            start_i     => start,
            busy_o      => busy,
            tx_data_i   => tx_data,
            rx_data_o   => rx_data,
            rx_valid_o  => rx_valid,
            sck_o       => sck,
            mosi_o      => mosi,
            miso_i      => miso
        );
    
    -- Test process
    process
    begin
        -- Reset
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait for 100 ns;
        
        -- Test 1: Send 0xA5
        report "Test 1: Sending 0xA5";
        tx_data <= x"A5";
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';
        
        -- Wait for transaction to complete
        wait until rx_valid = '1';
        report "Transaction complete";
        wait for 100 ns;
        
        -- Test 2: Send 0x5A
        report "Test 2: Sending 0x5A";
        tx_data <= x"5A";
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';
        
        wait until rx_valid = '1';
        report "Transaction complete";
        wait for 100 ns;
        
        report "All tests passed!";
        test_done <= true;
        wait;
    end process;
    
    -- MISO simulation (echo back the data)
    process
    begin
        wait until rising_edge(sck);
        miso <= mosi;
    end process;
    
end architecture;
