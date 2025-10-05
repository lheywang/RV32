-- recommended sim lenght : 5 us

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE work.common.ALL;

ENTITY alu_tb IS
END ENTITY;

ARCHITECTURE behavioral OF alu_tb IS

    SIGNAL arg1_t : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL arg2_t : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL result_t : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL command_t : commands := c_NONE;
    SIGNAL outen_t : STD_LOGIC := '0';
    SIGNAL overflow_t : STD_LOGIC := '0';
    SIGNAL beq_t : STD_LOGIC := '0';
    SIGNAL bne_t : STD_LOGIC := '0';
    SIGNAL blt_t : STD_LOGIC := '0';
    SIGNAL bge_t : STD_LOGIC := '0';
    SIGNAL bltu_t : STD_LOGIC := '0';
    SIGNAL bgeu_t : STD_LOGIC := '0';

BEGIN

    U1 : ENTITY work.alu(behavioral)
        GENERIC MAP(
            XLEN => 32
        )
        PORT MAP(
            arg1 => arg1_t,
            arg2 => arg2_t,
            result => result_t,
            command => command_t,
            outen => outen_t,
            overflow => overflow_t,
            beq => beq_t,
            bne => bne_t,
            bge => bge_t,
            blt => blt_t,
            bltu => bltu_t,
            bgeu => bgeu_t
        );

    -- Instructions cycles
    P1 : PROCESS
    BEGIN
        command_t <= c_ADD;
        WAIT FOR 140 ns;
        command_t <= c_SUB;
        WAIT FOR 140 ns;
        command_t <= c_AND;
        WAIT FOR 140 ns;
        command_t <= c_OR;
        WAIT FOR 140 ns;
        command_t <= c_XOR;
        WAIT FOR 140 ns;
        command_t <= c_SLL;
        WAIT FOR 140 ns;
        command_t <= c_SRL;
        WAIT FOR 140 ns;
        command_t <= c_SRA;
        WAIT FOR 140 ns;
        command_t <= c_SLT;
        WAIT FOR 140 ns;
        command_t <= c_SLTU;
        WAIT FOR 140 ns;
        command_t <= c_NONE;
        WAIT FOR 140 ns;
    END PROCESS;

    -- Input controls
    P2 : PROCESS
    BEGIN
        -- Standard operations
        arg1_t <= STD_LOGIC_VECTOR(to_signed(12, arg1_t'length));
        arg2_t <= STD_LOGIC_VECTOR(to_signed(5, arg2_t'length));
        WAIT FOR 20 ns;
        arg1_t <= STD_LOGIC_VECTOR(to_signed(-10, arg1_t'length));
        arg2_t <= STD_LOGIC_VECTOR(to_signed(-5, arg2_t'length));
        WAIT FOR 20 ns;
        -- Zero crossing
        arg1_t <= STD_LOGIC_VECTOR(to_signed(3, arg1_t'length));
        arg2_t <= STD_LOGIC_VECTOR(to_signed(-5, arg2_t'length));
        WAIT FOR 20 ns;
        arg1_t <= STD_LOGIC_VECTOR(to_signed(-3, arg1_t'length));
        arg2_t <= STD_LOGIC_VECTOR(to_signed(-5, arg2_t'length));
        WAIT FOR 20 ns;
        -- Overflows
        arg1_t <= STD_LOGIC_VECTOR(to_signed(2147483640, arg1_t'length));
        arg2_t <= STD_LOGIC_VECTOR(to_signed(64, arg2_t'length));
        WAIT FOR 20 ns;
        arg1_t <= STD_LOGIC_VECTOR(to_signed(-64, arg1_t'length));
        arg2_t <= STD_LOGIC_VECTOR(to_signed(2147483640, arg2_t'length));
        WAIT FOR 20 ns;
        arg1_t <= STD_LOGIC_VECTOR(to_signed(128, arg1_t'length));
        arg2_t <= STD_LOGIC_VECTOR(to_signed(128, arg2_t'length));
        WAIT FOR 20 ns;

    END PROCESS;

    -- Output enable control
    P3 : PROCESS
    BEGIN
        outen_t <= '1';
        WAIT FOR 1540 ns;
        outen_t <= '0';
        WAIT FOR 1540 ns;
    END PROCESS;

END ARCHITECTURE;