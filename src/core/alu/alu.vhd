LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE work.common.ALL;
USE work.records.ALL;

ENTITY alu IS
    GENERIC (
        --! @brief Configure the data width in the core. DOES NOT configure the instruction lenght, which is fixed to 32 bits.
        XLEN : INTEGER := 32
    );
    PORT (
        --------------------------------------------------------------------------------------------------------
        -- Data I/O
        --------------------------------------------------------------------------------------------------------
        --! @brief Argument 1 input for the ALU logic.
        arg1 : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        --! @brief Argument 2 input for the ALU logic.
        arg2 : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        --! @brief Output of the ALU logic.
        result : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := (OTHERS => 'Z');

        --------------------------------------------------------------------------------------------------------
        -- Controls
        --------------------------------------------------------------------------------------------------------
        --! @brief Command of the ALU, which operation need to be done.
        command : IN commands;

        --------------------------------------------------------------------------------------------------------
        -- Status
        --------------------------------------------------------------------------------------------------------
        --! @brief ALU status (zero, overflow...) output.
        status : OUT alu_feedback
    );
END ENTITY;

ARCHITECTURE behavioral OF alu IS

BEGIN

    --========================================================================================
    --! @brief Process that is executed on changed of the input arg, and trigger a new 
    --! calculation.
    --! Most of the operations are based on bare VHDL implementations.
    --========================================================================================
    P1 : PROCESS (arg1, arg2, command)

        VARIABLE tmp : signed(XLEN - 1 DOWNTO 0);
        VARIABLE res : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);

        VARIABLE v_ovf : STD_LOGIC := '0';

        VARIABLE highz_out : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := (OTHERS => 'Z');

    BEGIN

        res := (OTHERS => '0');
        v_ovf := '0';

        CASE command IS

            WHEN c_ADD =>
                tmp := signed(arg1) + signed(arg2);
                res := STD_LOGIC_VECTOR(tmp);
                -- signed overflow detection
                IF (arg1(XLEN - 1) = arg2(XLEN - 1)) AND (res(XLEN - 1) /= arg1(XLEN - 1)) THEN
                    v_ovf := '1';
                END IF;

            WHEN c_SUB =>
                tmp := signed(arg1) - signed(arg2);
                res := STD_LOGIC_VECTOR(tmp);
                -- signed overflow detection
                IF (arg1(XLEN - 1) /= arg2(XLEN - 1)) AND (res(XLEN - 1) /= arg1(XLEN - 1)) THEN
                    v_ovf := '1';
                END IF;

            WHEN c_SLL =>
                res := STD_LOGIC_VECTOR(shift_left(unsigned(arg1), to_integer(unsigned(arg2(4 DOWNTO 0)))));

            WHEN c_SRL =>
                res := STD_LOGIC_VECTOR(shift_right(unsigned(arg1), to_integer(unsigned(arg2(4 DOWNTO 0)))));

            WHEN c_SRA =>
                res := STD_LOGIC_VECTOR(shift_right(signed(arg1), to_integer(unsigned(arg2(4 DOWNTO 0)))));

            WHEN c_AND =>
                res := arg1 AND arg2;

            WHEN c_OR =>
                res := arg1 OR arg2;

            WHEN c_XOR =>
                res := arg1 XOR arg2;

            WHEN c_SLT =>
                IF signed(arg1) < signed(arg2) THEN
                    res := (OTHERS => '0');
                    res(0) := '1';
                ELSE
                    res := (OTHERS => '0');
                END IF;

            WHEN c_SLTU =>
                IF unsigned(arg1) < unsigned(arg2) THEN
                    res := (OTHERS => '0');
                    res(0) := '1';
                ELSE
                    res := (OTHERS => '0');
                END IF;

            WHEN OTHERS =>
                res := (OTHERS => '0');

        END CASE;

        -- outputs assignment
        result <= res;
        status.overflow <= v_ovf;

        IF (unsigned(res) = 0) AND (command /= c_None) THEN -- This make c_NONE be used for branchs evaluations.
            status.zero <= '1';
        ELSE
            status.zero <= '0';
        END IF;

        -- Jumps condition checks
        IF (unsigned(arg1) = unsigned(arg2)) THEN
            status.beq <= '1';
            status.bne <= '0';
        ELSE
            status.beq <= '0';
            status.bne <= '1';
        END IF;

        IF (unsigned(arg1) < unsigned(arg2)) THEN
            status.bltu <= '1';
            status.bgeu <= '0';
        ELSE
            status.bltu <= '0';
            status.bgeu <= '1';
        END IF;

        IF (signed(arg1) < signed(arg2)) THEN
            status.blt <= '1';
            status.bge <= '0';
        ELSE
            status.blt <= '0';
            status.bge <= '1';
        END IF;

    END PROCESS;

END ARCHITECTURE;