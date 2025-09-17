-- recommended sim lenght : 1 us
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rom_tb is 
end entity;

architecture behavioral of rom_tb is

        signal clock_t :        std_logic                       := '0';
        signal nRST_t :         std_logic                       := '0';
        signal addr1_t :        std_logic_vector(31 downto 0)   := (others => '0');
        signal addr2_t :        std_logic_vector(31 downto 0)   := (others => '0');
        signal dataout1_t :     std_logic_vector(31 downto 0)   ;
        signal dataout2_t :     std_logic_vector(31 downto 0)   ;
        signal busy1_t :        std_logic                       := '0';
        signal busy2_t :        std_logic                       := '0';
        signal illegal_addr_t : std_logic                       := '0';
        signal byte_en1_t :     std_logic_vector(3 downto 0)    := "0011";
        signal data_valid1_t :  std_logic                       := '0';
        signal data_valid2_t :  std_logic                       := '0';
        signal mem_req1_t :     std_logic                       := '0';
        signal mem_req2_t :     std_logic                       := '0';

    begin

        U1 : entity work.rom(behavioral)
        generic map (
            XLEN            => 32,
            ROM_ADDR        => 16#0000_0000#,
            ROM_SIZE        => 16#0002_FFFF#
        )
        port map (
            clk             => clock_t,
            nRST            => nRST_t,
            addr0           => addr1_t,
            addr1           => addr2_t,
            dataout0        => dataout1_t,
            dataout1        => dataout1_t,
            mem_busy0       => busy1_t,
            mem_busy1       => busy2_t,
            byte_en1        => byte_en1_t,
            data_valid0     => data_valid1_t,
            data_valid1     => data_valid2_t,
            mem_req0        => mem_req1_t,
            mem_req1        => mem_req2_t
        );

        -- clock
        P1 : process
        begin
            clock_t <= not clock_t;
            wait for 10 ns;
        end process;

        -- reset
        P2 : process
        begin
            nRST_t <= '0';
            wait for 15 ns;
            nRST_t <= '1';
            wait;
        end process;

        -- Program counter equivalent
        P3 : process
        begin
            addr1_t <= X"0000_0000";
            wait for 40 ns;
            addr1_t <= X"0000_0001";
            wait for 40 ns;
            addr1_t <= X"0000_0002";
            wait for 40 ns;
            addr1_t <= X"0000_0003";
            wait for 40 ns;     
            addr1_t <= X"0000_0004";
            wait for 40 ns;
        end process;
        
        -- Random reads
        P5 : process
        begin
            addr2_t <= X"0000_beef";
            wait for 40 ns;
            addr2_t <= X"0000_dead";
            wait for 40 ns;
            addr2_t <= X"0000_cafe";
            wait for 40 ns;
            addr2_t <= X"0000_babe";
            wait for 40 ns;     
            addr2_t <= X"0000_bbbb";
            wait for 40 ns;
        end process;

        P6 : process
        begin
            mem_req1_t <= '1';
            wait for 40 ns;
            mem_req2_t <= '1';
            wait for 40 ns;
            mem_req2_t <= '0';
            wait for 40 ns;
            mem_req2_t <= '1';
            wait for 40 ns;
            mem_req2_t <= '0';
            mem_req1_t <= '0';
            wait for 40 ns;
        end process;

    end architecture;
