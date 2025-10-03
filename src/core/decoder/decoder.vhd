LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE work.common.ALL;

ENTITY decoder IS
    GENERIC (
        XLEN : INTEGER := 32 -- Width of the data outputs. 
        -- Warning : This does not change the number of registers not i_instruction lenght
    );
    PORT (
        -- instruction input
        instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

        -- shift enable
        shift_en : IN STD_LOGIC;

        -- outputs
        -- buses
        rs1 : OUT STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0) := (OTHERS => '0');
        rs2 : OUT STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0) := (OTHERS => '0');
        rd : OUT STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0) := (OTHERS => '0');
        imm : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := (OTHERS => '0');
        opcode : OUT instructions;
        -- signals
        illegal : OUT STD_LOGIC;
        pause : OUT STD_LOGIC;

        -- Clocks
        clock : IN STD_LOGIC;
        clock_en : IN STD_LOGIC;
        nRST : IN STD_LOGIC
    );
END ENTITY;

ARCHITECTURE behavioral OF decoder IS

    -- Defining the different selected_decoders
    TYPE decocders_type IS (U, I, R, B, S, J, default_t, illegal_t, NOP);

    -- signals
    SIGNAL illegal_internal : STD_LOGIC := '0';
    SIGNAL illegal_internal2 : STD_LOGIC := '0';
    SIGNAL illegal_internal_out : STD_LOGIC := '0';

    -- Internal states
    SIGNAL selected_decoder : decocders_type := default_t;

    -- Latchs outputs
    SIGNAL rs1_internal : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL rs2_internal : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL rd_internal : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL imm_internal : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := (OTHERS => '0');

    -- Internal instruction bus, with the right endianess
    SIGNAL i_instruction : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL r_instruction : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');

    -- remove the first decoder cycle glitch
    SIGNAL first_flag : STD_LOGIC := '0';

BEGIN

    -- Register the input, to enable constant delays between decoders outputs
    P0 : PROCESS (clock, nRST)
    BEGIN
        IF (nRST = '0') THEN
            r_instruction <= (OTHERS => '0');
            first_flag <= '0';
            pause <= '1';

        ELSIF rising_edge(clock) AND (clock_en = '1') AND (shift_en = '1') THEN
            IF (first_flag = '1') THEN
                r_instruction <= instruction;
            ELSE
                first_flag <= '1';
            END IF;

        END IF;

    END PROCESS;

    -- Endianess correctors
    U1 : ENTITY work.endianess(rtl)
        GENERIC MAP(
            XLEN => 32
        )
        PORT MAP(
            datain => r_instruction,
            dataout => i_instruction
        );

    -- Combinantional decoder, select the wanted decoder
    -- Using this not synced to clock enable to split the logic in half, and reduce the critical path
    -- Before, we've got Fmax = ~100 MHz because of it's too long logic.
    -- After, quartus report Fmax = ~230 MHz, because of the middle registering process.
    P1 : PROCESS (nRST, i_instruction)
    BEGIN

        IF (nRST = '0') THEN
            illegal_internal <= '0';
            selected_decoder <= default_t;

        ELSE

            -- Select the opcode, and perform an instruction size check (last two bits must be "11").
            CASE i_instruction(6 DOWNTO 0) IS

                WHEN "0110111" => -- LUI
                    selected_decoder <= U;
                    illegal_internal <= '0';
                WHEN "0010111" => -- AUIPC
                    selected_decoder <= U;
                    illegal_internal <= '0';

                WHEN "0010011" => -- Immediates
                    selected_decoder <= I;
                    illegal_internal <= '0';
                WHEN "0001111" => -- FENCE
                    selected_decoder <= I;
                    illegal_internal <= '0';
                WHEN "1100111" => --(JALR)
                    selected_decoder <= I;
                    illegal_internal <= '0';
                WHEN "1110011" => -- Calls
                    selected_decoder <= I;
                    illegal_internal <= '0';
                WHEN "0000011" => -- Store
                    selected_decoder <= I;
                    illegal_internal <= '0';

                WHEN "0110011" => -- Register operations
                    selected_decoder <= R;
                    illegal_internal <= '0';

                WHEN "1100011" => -- Branchs
                    selected_decoder <= B;
                    illegal_internal <= '0';

                WHEN "0100011" => -- Loads
                    selected_decoder <= S;
                    illegal_internal <= '0';

                WHEN "1101111" => -- Jumps
                    selected_decoder <= J;
                    illegal_internal <= '0';

                WHEN "0000000" => -- All zero, seen as NOP
                    selected_decoder <= NOP;
                    illegal_internal <= '0';

                WHEN OTHERS =>
                    selected_decoder <= illegal_t;
                    illegal_internal <= '1';

            END CASE;
        END IF;

    END PROCESS;

    -- P2 : process(clock, nRST, clock_en)
    --     begin
    --         if (nRST = '0') then    
    --             r_selected_decoder <= default_t;

    --         elsif rising_edge(clock) and (clock_en = '1') then
    --             r_selected_decoder <= selected_decoder;

    --         end if;
    --     end process;

    -- Hardware selected_decoder selection logic
    -- This process is actually clocked, because we need synchronous outputs.
    P3 : PROCESS (clock, clock_en, nRST)
    BEGIN
        IF (nRST = '0') THEN
            rs1_internal <= (OTHERS => '0');
            rs2_internal <= (OTHERS => '0');
            imm_internal <= (OTHERS => '0');
            rd_internal <= (OTHERS => '0');
            opcode <= i_NOP;
            illegal_internal2 <= '0';

        ELSIF rising_edge(clock) AND (clock_en = '1') AND (shift_en = '1') THEN

            CASE selected_decoder IS

                    -- Register to register operation
                WHEN R =>
                    rd_internal <= i_instruction(11 DOWNTO 7);
                    rs1_internal <= i_instruction(19 DOWNTO 15);

                    rs2_internal <= i_instruction(24 DOWNTO 20);
                    imm_internal <= (OTHERS => '0');

                    -- i_instruction identification
                    CASE i_instruction(31 DOWNTO 25) IS

                        WHEN "0000000" => -- ADD SLL SLT XOR SRL OR AND

                            CASE i_instruction(14 DOWNTO 12) IS

                                WHEN "000" =>
                                    opcode <= i_ADD;
                                    illegal_internal2 <= '0';
                                WHEN "001" =>
                                    opcode <= i_SLL;
                                    illegal_internal2 <= '0';
                                WHEN "010" =>
                                    opcode <= i_SLT;
                                    illegal_internal2 <= '0';
                                WHEN "011" =>
                                    opcode <= i_SLTU;
                                    illegal_internal2 <= '0';
                                WHEN "100" =>
                                    opcode <= i_XOR;
                                    illegal_internal2 <= '0';
                                WHEN "101" =>
                                    opcode <= i_SRL;
                                    illegal_internal2 <= '0';
                                WHEN "110" =>
                                    opcode <= i_OR;
                                    illegal_internal2 <= '0';
                                WHEN "111" =>
                                    opcode <= i_AND;
                                    illegal_internal2 <= '0';
                                WHEN OTHERS =>
                                    opcode <= i_NOP;
                                    illegal_internal2 <= '1';

                            END CASE;

                        WHEN "0100000" => -- SUB SRA

                            CASE i_instruction(14 DOWNTO 12) IS

                                WHEN "000" =>
                                    opcode <= i_SUB;
                                    illegal_internal2 <= '0';
                                WHEN "101" =>
                                    opcode <= i_SRA;
                                    illegal_internal2 <= '0';
                                WHEN OTHERS =>
                                    opcode <= i_NOP;
                                    illegal_internal2 <= '1';

                            END CASE;

                        WHEN OTHERS =>
                            opcode <= i_NOP;
                            illegal_internal2 <= '1';

                    END CASE;

                    -- Immediate to register operation
                WHEN I =>
                    rd_internal <= i_instruction(11 DOWNTO 7);
                    rs1_internal <= i_instruction(19 DOWNTO 15);
                    rs2_internal <= (OTHERS => '0');
                    imm_internal <= (OTHERS => i_instruction(31));
                    imm_internal(11 DOWNTO 0) <= i_instruction(31 DOWNTO 20);

                    -- i_instruction identification
                    CASE i_instruction(6 DOWNTO 2) IS

                        WHEN "00100" =>

                            CASE i_instruction(14 DOWNTO 12) IS

                                WHEN "000" =>
                                    opcode <= i_ADDI;
                                    illegal_internal2 <= '0';
                                WHEN "001" =>
                                    opcode <= i_SLLI;
                                    illegal_internal2 <= '0';
                                WHEN "010" =>
                                    opcode <= i_SLTI;
                                    illegal_internal2 <= '0';
                                WHEN "011" =>
                                    opcode <= i_SLTIU;
                                    illegal_internal2 <= '0';
                                WHEN "100" =>
                                    opcode <= i_XORI;
                                    illegal_internal2 <= '0';
                                WHEN "110" =>
                                    opcode <= i_ORI;
                                    illegal_internal2 <= '0';
                                WHEN "101" =>
                                    IF (i_instruction(30) = '1') THEN
                                        opcode <= i_SRAI;
                                        illegal_internal2 <= '0';
                                    ELSE
                                        opcode <= i_SRLI;
                                        illegal_internal2 <= '0';
                                    END IF;

                                WHEN "111" =>
                                    opcode <= i_ANDI;
                                    illegal_internal2 <= '0';
                                WHEN OTHERS =>
                                    opcode <= i_NOP;
                                    illegal_internal2 <= '0';

                            END CASE;

                        WHEN "00011" =>
                            opcode <= i_FENCE;
                            illegal_internal2 <= '0';

                        WHEN "00000" =>

                            CASE i_instruction(14 DOWNTO 12) IS

                                WHEN "000" =>
                                    opcode <= i_LB;
                                    illegal_internal2 <= '0';
                                WHEN "001" =>
                                    opcode <= i_LH;
                                    illegal_internal2 <= '0';
                                WHEN "010" =>
                                    opcode <= i_LW;
                                    illegal_internal2 <= '0';
                                WHEN "100" =>
                                    opcode <= i_LBU;
                                    illegal_internal2 <= '0';
                                WHEN "101" =>
                                    opcode <= i_LHU;
                                    illegal_internal2 <= '0';
                                WHEN OTHERS =>
                                    opcode <= i_NOP;
                                    illegal_internal2 <= '1';

                            END CASE;

                        WHEN "11001" =>
                            IF (i_instruction(14 DOWNTO 12) = "000") THEN
                                opcode <= i_JALR;
                                illegal_internal2 <= '0';
                            ELSE
                                opcode <= i_NOP;
                                illegal_internal2 <= '1';
                            END IF;

                        WHEN "11100" =>

                            CASE i_instruction(14 DOWNTO 12) IS

                                WHEN "001" =>
                                    opcode <= i_CSRRW;
                                    illegal_internal2 <= '0';
                                WHEN "010" =>
                                    opcode <= i_CSRRS;
                                    illegal_internal2 <= '0';
                                WHEN "011" =>
                                    opcode <= i_CSRRC;
                                    illegal_internal2 <= '0';
                                WHEN "101" =>
                                    opcode <= i_CSRRWI;
                                    illegal_internal2 <= '0';
                                WHEN "110" =>
                                    opcode <= i_CSRRSI;
                                    illegal_internal2 <= '0';
                                WHEN "111" =>
                                    opcode <= i_CSRRCI;
                                    illegal_internal2 <= '0';
                                WHEN "000" =>

                                    CASE i_instruction(31 DOWNTO 20) IS

                                        WHEN X"000" =>
                                            opcode <= i_ECALL;
                                            illegal_internal2 <= '0';
                                        WHEN X"001" =>
                                            opcode <= i_EBREAK;
                                            illegal_internal2 <= '0';
                                        WHEN X"302" =>
                                            opcode <= i_MRET;
                                            illegal_internal2 <= '0';
                                        WHEN OTHERS =>
                                            opcode <= i_NOP;
                                            illegal_internal2 <= '1';

                                    END CASE;

                                WHEN OTHERS =>
                                    opcode <= i_NOP;
                                    illegal_internal2 <= '1';

                            END CASE;

                        WHEN OTHERS =>
                            opcode <= i_NOP;
                            illegal_internal2 <= '1';

                    END CASE;
                    -- Memory operation
                WHEN S =>
                    rd_internal <= (OTHERS => '0');
                    rs1_internal <= i_instruction(19 DOWNTO 15);
                    rs2_internal <= i_instruction(24 DOWNTO 20);
                    imm_internal <= (OTHERS => i_instruction(31));
                    imm_internal(11 DOWNTO 0) <= i_instruction(31 DOWNTO 25)
                    & i_instruction(11 DOWNTO 7);

                    -- i_instruction identification
                    CASE i_instruction(14 DOWNTO 12) IS

                        WHEN "000" =>
                            opcode <= i_SB;
                            illegal_internal2 <= '0';
                        WHEN "001" =>
                            opcode <= i_SH;
                            illegal_internal2 <= '0';
                        WHEN "010" =>
                            opcode <= i_SW;
                            illegal_internal2 <= '0';
                        WHEN OTHERS =>

                    END CASE;

                    -- Branches
                WHEN B =>
                    rd_internal <= (OTHERS => '0');
                    rs1_internal <= i_instruction(19 DOWNTO 15);
                    rs2_internal <= i_instruction(24 DOWNTO 20);
                    imm_internal <= (OTHERS => i_instruction(31));
                    imm_internal(11 DOWNTO 0) <= i_instruction(31)
                    & i_instruction(7)
                    & i_instruction(30 DOWNTO 25)
                    & i_instruction(11 DOWNTO 8);

                    -- i_instruction identification
                    CASE i_instruction(14 DOWNTO 12) IS

                        WHEN "000" =>
                            opcode <= i_BEQ;
                            illegal_internal2 <= '0';
                        WHEN "001" =>
                            opcode <= i_BNE;
                            illegal_internal2 <= '0';
                        WHEN "100" =>
                            opcode <= i_BLT;
                            illegal_internal2 <= '0';
                        WHEN "101" =>
                            opcode <= i_BGE;
                            illegal_internal2 <= '0';
                        WHEN "110" =>
                            opcode <= i_BLTU;
                            illegal_internal2 <= '0';
                        WHEN "111" =>
                            opcode <= i_BGEU;
                            illegal_internal2 <= '0';
                        WHEN OTHERS =>
                            opcode <= i_NOP;
                            illegal_internal2 <= '1';

                    END CASE;

                    -- Immediates values loading
                WHEN U =>
                    rd_internal <= i_instruction(11 DOWNTO 7);
                    rs1_internal <= (OTHERS => '0');
                    rs2_internal <= (OTHERS => '0');
                    imm_internal <= i_instruction(31 DOWNTO 12)
                        & "000000000000";

                    -- i_instruction identification
                    CASE i_instruction(6 DOWNTO 2) IS

                        WHEN "01101" =>
                            opcode <= i_LUI;
                            illegal_internal2 <= '0';
                        WHEN "00101" =>
                            opcode <= i_AUIPC;
                            illegal_internal2 <= '0';
                        WHEN OTHERS =>
                            opcode <= i_NOP;
                            illegal_internal2 <= '1';

                    END CASE;

                    -- Jumps
                WHEN J =>
                    rd_internal <= (OTHERS => '0');
                    rs1_internal <= i_instruction(19 DOWNTO 15);
                    rs2_internal <= i_instruction(24 DOWNTO 20);
                    imm_internal <= (OTHERS => i_instruction(31));
                    imm_internal(20 DOWNTO 1) <= i_instruction(31)
                    & i_instruction(19 DOWNTO 12)
                    & i_instruction(20)
                    & i_instruction(30 DOWNTO 21);
                    imm_internal(0) <= '0';

                    -- i_instruction identification
                    CASE i_instruction(6 DOWNTO 2) IS

                        WHEN "11011" =>
                            opcode <= i_JAL;
                            illegal_internal2 <= '0';
                        WHEN OTHERS =>
                            opcode <= i_NOP;
                            illegal_internal2 <= '1';

                    END CASE;

                WHEN NOP =>
                    rd_internal <= (OTHERS => '0');
                    rs1_internal <= (OTHERS => '0');
                    rs2_internal <= (OTHERS => '0');
                    imm_internal <= (OTHERS => '0');
                    opcode <= i_NOP;
                    illegal_internal2 <= '0';

                WHEN OTHERS =>
                    rd_internal <= (OTHERS => '0');
                    rs1_internal <= (OTHERS => '0');
                    rs2_internal <= (OTHERS => '0');
                    imm_internal <= (OTHERS => '0');
                    opcode <= i_NOP;
                    illegal_internal2 <= '1';

            END CASE;

        END IF;

    END PROCESS;

    -- Compute the illegal status
    illegal_internal_out <= illegal_internal OR illegal_internal2;

    -- Output signals, while encouting for illegal state.
    illegal <= illegal_internal_out;

    rs1 <= rs1_internal WHEN illegal_internal_out = '0' ELSE
        STD_LOGIC_VECTOR(to_unsigned(0, rs1'length));
    rs2 <= rs2_internal WHEN illegal_internal_out = '0' ELSE
        STD_LOGIC_VECTOR(to_unsigned(0, rs2'length));
    rd <= rd_internal WHEN illegal_internal_out = '0' ELSE
        STD_LOGIC_VECTOR(to_unsigned(0, rd'length));
    imm <= imm_internal WHEN illegal_internal_out = '0' ELSE
        STD_LOGIC_VECTOR(to_unsigned(0, imm'length));

END ARCHITECTURE;