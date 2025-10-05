-- Recommended sim lenght : 1 us

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

ENTITY pcounter_tb IS
END ENTITY;

ARCHITECTURE behavioral OF pcounter_tb IS

    SIGNAL address_t : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL address_in_t : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"deadbeef";
    SIGNAL clock_t : STD_LOGIC := '0';
    SIGNAL nRST_t : STD_LOGIC := '0';
    SIGNAL load_t : STD_LOGIC := '0';
    SIGNAL enable_t : STD_LOGIC := '0';
    SIGNAL nOVER_t : STD_LOGIC;

BEGIN

    U1 : ENTITY work.pcounter(behavioral)
        GENERIC MAP(
            XLEN => 32,
            RESET_ADDR => 255
        )
        PORT MAP(
            address => address_t,
            address_in => address_in_t,
            clock => clock_t,
            nRST => nRST_t,
            load => load_t,
            enable => enable_t,
            nOVER => nOVER_t
        );

    P1 : PROCESS
    BEGIN
        clock_t <= NOT clock_t;
        WAIT FOR 10 ns;
    END PROCESS;

    P2 : PROCESS
    BEGIN
        nRST_t <= '0';
        WAIT FOR 100 ns;
        nRST_t <= '1';
        WAIT FOR 900 ns;
    END PROCESS;

    P3 : PROCESS
    BEGIN
        WAIT FOR 110 ns;
        enable_t <= '1';
        WAIT FOR 90 ns;
        enable_t <= '0';
        load_t <= '1';

        WAIT FOR 60 ns;
        load_t <= '0';
        WAIT FOR 40 ns;
        enable_t <= '1';

        WAIT FOR 100 ns;
        address_in_t <= X"FFFFFFF0";
        load_t <= '1';

        WAIT FOR 20 ns;
        load_t <= '0';
        WAIT FOR 380 ns;
        load_t <= '1';

        WAIT FOR 60 ns;
        load_t <= '0';
        WAIT FOR 140 ns;
    END PROCESS;

END ARCHITECTURE;