LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY register_file_tb IS
END ENTITY;

ARCHITECTURE sim OF register_file_tb IS

    CONSTANT XLEN : INTEGER := 32;
    CONSTANT REG_NB : INTEGER := 32;

    -- DUT ports
    SIGNAL clock : STD_LOGIC := '0';
    SIGNAL nRST : STD_LOGIC := '0';

    SIGNAL we : STD_LOGIC := '0';
    SIGNAL wa : INTEGER RANGE 0 TO REG_NB - 1 := 0;
    SIGNAL wd : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0) := (OTHERS => '0');

    SIGNAL ra1 : INTEGER RANGE 0 TO REG_NB - 1 := 0;
    SIGNAL rd1 : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);

    SIGNAL ra2 : INTEGER RANGE 0 TO REG_NB - 1 := 0;
    SIGNAL rd2 : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);

BEGIN

    -----------------------------------------------------------------------
    -- DUT instance
    -----------------------------------------------------------------------
    UUT : ENTITY work.register_file(rtl)
        GENERIC MAP(
            XLEN => XLEN,
            REG_NB => REG_NB
        )
        PORT MAP(
            clock => clock,
            nRST => nRST,
            we => we,
            wa => wa,
            wd => wd,
            ra1 => ra1,
            rd1 => rd1,
            ra2 => ra2,
            rd2 => rd2
        );

    -----------------------------------------------------------------------
    -- clock generation (10 ns period)
    -----------------------------------------------------------------------
    clock <= NOT clock AFTER 5 ns;

    -----------------------------------------------------------------------
    -- stimulus
    -----------------------------------------------------------------------
    PROCESS
    BEGIN
        -- hold reset
        nRST <= '0';
        WAIT FOR 20 ns;
        nRST <= '1';
        WAIT FOR 10 ns;

        -- write some values
        FOR i IN 1 TO 5 LOOP
            wa <= i;
            wd <= STD_LOGIC_VECTOR(to_unsigned(i * 16#10#, XLEN));
            we <= '1';
            WAIT UNTIL rising_edge(clock);
        END LOOP;
        we <= '0';

        -- read them back
        FOR i IN 0 TO 5 LOOP
            ra1 <= i;
            ra2 <= (i + 1) MOD REG_NB;
            WAIT FOR 10 ns;
            REPORT "ra1=" & INTEGER'image(i) &
                " rd1=" & INTEGER'image(to_integer(unsigned(rd1))) &
                " | ra2=" & INTEGER'image((i + 1) MOD REG_NB) &
                " rd2=" & INTEGER'image(to_integer(unsigned(rd2)));
        END LOOP;

        WAIT;
    END PROCESS;

END ARCHITECTURE;