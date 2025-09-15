-- recommended sim lenght : 1 us
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ram_tb is 
end entity;

architecture behavioral of ram_tb is

        signal clock_t :        std_logic                       := '0';
        signal nRST_t :         std_logic                       := '0';
        signal WR_t :           std_logic                       := '0';
        signal addr_t :         std_logic_vector(31 downto 0)   := (others => '0');
        signal datain_t :       std_logic_vector(31 downto 0)   := (others => '0');
        signal dataout_t :      std_logic_vector(31 downto 0)   := (others => '0');
        signal busy_t :         std_logic                       := '0';
        signal illegal_addr_t : std_logic                       := '0';
        signal byte_en_t :      std_logic_vector(3 downto 0)    := "0011";
        signal data_valid_t :   std_logic                       := '0';

    begin

        U1 : entity work.ram(behavioral)
        generic map (
            XLEN            => 32,
            RAM_ADDR        => 16#2000_0000#,
            RAM_SIZE        => 16#0001_FFFF#
        )
        port map (
            clock           => clock_t,
            nRST            => nRST_t,
            WR              => WR_t,
            addr            => addr_t,
            datain          => datain_t,
            dataout         => dataout_t,
            busy            => busy_t,
            illegal_addr    => illegal_addr_t,
            byte_en         => byte_en_t,
            data_valid      => data_valid_t
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

        -- Reads / writes
        P3 : process
        begin
            WR_t <= '1';
            wait for 200 ns;
            WR_t <= '0';
            wait for 200 ns;
        end process;

        -- addresses
        P4 : process
        begin
            addr_t <= X"2000_0000";
            wait for 40 ns;
            addr_t <= X"2001_FFFF";
            wait for 40 ns;
            addr_t <= X"2000_FFFF";
            wait for 40 ns;
            addr_t <= X"2000_FFFB";
            wait for 40 ns;     
            addr_t <= X"2004_FFFE";     -- illegal address
            wait for 40 ns;
        end process;
        
        -- data
        P5 : process
        begin
            datain_t <= X"dead_beef";
            wait for 40 ns;
            datain_t <= X"beef_dead";
            wait for 40 ns;
            datain_t <= X"babe_cafe";
            wait for 40 ns;
            datain_t <= X"cafe_babe";
            wait for 40 ns;     
            datain_t <= X"aaaa_bbbb";
            wait for 40 ns;
        end process;
    end architecture;
