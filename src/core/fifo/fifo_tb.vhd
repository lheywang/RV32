library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_tb is
end entity;

architecture behavioral of fifo_tb is

    signal clk_t :          std_logic                       := '0';
    signal clk_en_t :       std_logic                       := '0';
    signal nRST_t :         std_logic                       := '0';
    
    signal din_t :          std_logic_vector(31 downto 0)   := (others => '0');
    
    signal wr_en_t :        std_logic                       := '0';
    signal rd_en_t:         std_logic                       := '0';
    
    signal dout_t :         std_logic_vector(31 downto 0)   := (others => '0');
    signal empty_t :        std_logic                       := '0';
    signal full_t :         std_logic                       := '0';

begin

    U1 : entity work.clock(behavioral)
        port map (
            clk         => clk_t,
            nRST        => nRST_t,
            clk_en      => clk_en_t
        );

    U2 : entity work.fifo(rtl)
        generic map (
            XLEN        => 32,
            DEPTH       => 8
        )
        port map (
            clk         => clk_t,
            clk_en      => clk_en_t,
            nRST        => nRST_t,
            wr_en       => wr_en_t,
            din         => din_t,
            rd_en       => rd_en_t,
            dout        => dout_t
        );

    -- clock
    P1 : process
    begin
        wait for 5 ns;
        clk_t <= not clk_t;
    end process;

    -- nRST
    P2 : process
    begin
        nRST_t  <= '0';
        wait for 15 ns;
        nRST_t  <= '1';
        wait;
    end process;

    P3 : process
    begin
        wait for 15 ns;
        din_t <= X"AAAAAAAA";
        wait for 30 ns;
        din_t <= X"BBBBBBBB";
        wait for 20 ns;
        din_t <= X"CCCCCCCC";
        wait for 20 ns;
        din_t <= X"DDDDDDDD";
        wait for 20 ns;
        din_t <= X"EEEEEEEE";
        wait for 20 ns;
        din_t <= X"FFFFFFFF";
        wait for 20 ns;
        din_t <= X"AAAAAAAA";
        wait for 20 ns;
        din_t <= X"99999999";
        wait for 20 ns;
        -- din_t <= X"11111111";
        wait for 20 ns;
        din_t <= X"22222222";
        wait for 20 ns;
        din_t <= X"33333333";
        wait for 20 ns;
        din_t <= X"44444444";
        wait;
    end process;

    P4 : process
    begin 
        wr_en_t <= '0';
        rd_en_t <= '0';
        wait for 15 ns;
        wr_en_t <= '1';
        rd_en_t <= '1';  
        wait for 130 ns;
        rd_en_t <= '0';
        -- wr_en_t <= '0';
        wait for 20 ns;
        rd_en_t <= '1';
        wr_en_t <= '0';
        wait for 20 ns;
        wr_en_t <= '1';
        wait for 100 ns;
    end process;


end behavioral ;