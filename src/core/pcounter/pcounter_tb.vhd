-- Recommended sim lenght : 1 us

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pcounter_tb is 
end entity;

architecture behavioral of pcounter_tb is

        signal address_t :      std_logic_vector(31 downto 0);
        signal address_in_t :   std_logic_vector(31 downto 0)           := X"deadbeef";
        signal clock_t :        std_logic                               := '0';
        signal nRST_t :         std_logic                               := '0';
        signal load_t :         std_logic                               := '0';
        signal enable_t :       std_logic                               := '0';
        signal nOVER_t :        std_logic;

    begin

        U1 : entity work.pcounter(behavioral)
            generic map (
                XLEN        =>  32,
                RESET_ADDR  =>  255
            )
            port map (
                address     =>  address_t,
                address_in  =>  address_in_t,
                clock       =>  clock_t,
                nRST        =>  nRST_t,
                load        =>  load_t,
                enable      =>  enable_t,
                nOVER       =>  nOVER_t
            );

        P1 : process
            begin
                clock_t <= not clock_t;
                wait for 10 ns;
            end process;

        P2 : process
            begin
                nRST_t <= '0';
                wait for 100 ns;
                nRST_t <= '1';
                wait for 900 ns;
            end process;

        P3 : process
            begin
                wait for 110 ns;
                enable_t <= '1';
                wait for 90 ns;
                enable_t <= '0';
                load_t <= '1';

                wait for 60 ns;
                load_t <= '0';
                wait for 40 ns;
                enable_t <= '1';

                wait for 100 ns;
                address_in_t <= X"FFFFFFF0";
                load_t <= '1';

                wait for 20 ns;
                load_t <= '0';
                wait for 380 ns;
                load_t <= '1';

                wait for 60 ns;
                load_t <= '0';
                wait for 140 ns;
            end process;

    end architecture;