LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

ENTITY clock_tb IS
END ENTITY;

ARCHITECTURE behavioral OF clock_tb IS

    SIGNAL clk_t : STD_LOGIC := '0';
    SIGNAL nRST_t : STD_LOGIC := '0';
    SIGNAL clk_en_t : STD_LOGIC := '0';

BEGIN

    U1 : ENTITY work.clock(behavioral)
        GENERIC MAP(
            INPUT_FREQ => 200_000_000,
            OUTPUT_FREQ => 50_000_000,
            DUTY_CYCLE => 75
        )
        PORT MAP(
            clk => clk_t,
            nRST => nRST_t,
            clk_en => clk_en_t
        );

    P1 : PROCESS
    BEGIN
        WAIT FOR 2500 ps;
        clk_t <= NOT clk_t;
    END PROCESS;

    P2 : PROCESS
    BEGIN
        WAIT FOR 10 ns;
        nRST_t <= '1';
    END PROCESS;

END ARCHITECTURE;