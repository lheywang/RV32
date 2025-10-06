-- Recommended sim lenght : 1 us

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

ENTITY counter_tb IS
END ENTITY;

ARCHITECTURE behavioral OF counter_tb IS

    SIGNAL value_t : STD_LOGIC_VECTOR(63 DOWNTO 0) := (OTHERS => '0');
    SIGNAL valueH_t : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL valueL_t : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL clock_t : STD_LOGIC := '0';
    SIGNAL clock_en_t : STD_LOGIC := '0';
    SIGNAL nRST_t : STD_LOGIC := '0';
    SIGNAL enable_t : STD_LOGIC := '0';

BEGIN

    U0 : ENTITY work.clock(behavioral)
        PORT MAP(
            clk => clock_t,
            clk_en => clock_en_t,
            nRST => nRST_t
        );

    U1 : ENTITY work.counter32(rtl)
        GENERIC MAP(
            RESET_ADDR => 2147483392,
            INCREMENT => 65535
        )
        PORT MAP(
            valueL => valueL_t,
            valueH => valueH_t,
            clock => clock_t,
            clock_en => clock_en_t,
            nRST => nRST_t,
            enable => enable_t
        );

    P1 : PROCESS
    BEGIN
        clock_t <= NOT clock_t;
        WAIT FOR 5 ns;
    END PROCESS;

    P2 : PROCESS
    BEGIN
        nRST_t <= '0';
        WAIT FOR 14 ns;
        nRST_t <= '1';
        WAIT;
    END PROCESS;

    P3 : PROCESS
    BEGIN
        WAIT FOR 50 ns;
        enable_t <= '1';
        WAIT;
    END PROCESS;

    value_t <= valueH_t & valueL_t;

END ARCHITECTURE;