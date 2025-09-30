library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity clock is
    generic (
        INPUT_FREQ :    integer := 200_000_000;
        OUTPUT_FREQ :   integer := 100_000_000;
        DUTY_CYCLE :    integer := 50
    );
    port (
        clk :           in  std_logic;
        nRST :          in  std_logic;
        clk_en :        out std_logic
    );
end entity;

architecture behavioral of clock is

        -- Compute values about the specs of the counter
        constant  maxval : integer := (INPUT_FREQ / OUTPUT_FREQ) - 1;
        constant  threshold : integer := ((maxval * DUTY_CYCLE) / 100) + 1;

         -- Initialize the vector
        signal count : integer range 0 to maxval + 1;

    begin

        P1 : process(clk, nRST)
        begin

            if (nRST = '0') then
                count <= 0;
                clk_en <= '0';

            elsif rising_edge(clk) then
                
                if (count >= maxval) then
                    count <= 0;
                else
                    count <= count + 1;
                end if;

                 if (count < threshold) then
                    clk_en <= '1';
                else
                    clk_en <= '0';
                end if;
        
            end if;

        end process;

    end architecture;