library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity clock_tb is
end entity;

architecture behavioral of clock_tb is

        signal clk_t : std_logic    := '0';
        signal nRST_t : std_logic   := '0';
        signal clk_en_t : std_logic := '0';

    begin

        U1 : entity work.clock(behavioral)
            generic map (
                INPUT_FREQ => 200_000_000,
                OUTPUT_FREQ => 50_000_000,
                DUTY_CYCLE => 75
            )
            port map (
                clk => clk_t,
                nRST => nRST_t,
                clk_en => clk_en_t
            );

        P1 : process
        begin
            wait for 2500 ps;
            clk_t <= not clk_t;
        end process;

        P2 : process
        begin
            wait for 10 ns;
            nRST_t <= '1';
        end process;

    end architecture;