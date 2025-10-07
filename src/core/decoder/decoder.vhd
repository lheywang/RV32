--! @file src/core/core.vhd
--! @brief The base file that assemble all of the components of the core. Does not include any form of memory.
--! @author l.heywang <leonard.heywang@proton.me>
--! @date 05-10-2025

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE work.common.ALL;

ENTITY decoder IS
    GENERIC (
        --! @brief Configure the data width in the core. DOES NOT configure the instruction lenght, which is fixed to 32 bits.
        XLEN : INTEGER := 32
    );
    PORT (
        --------------------------------------------------------------------------------------------------------
        -- Inputs
        --------------------------------------------------------------------------------------------------------
        --! @brief Instruction input, to be decoded.
        instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        --! @brief Address of the program counter. This is actually the NEXT address for this implementation.
        act_addr : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

        --------------------------------------------------------------------------------------------------------
        -- Outputs
        --------------------------------------------------------------------------------------------------------
        --! @brief Register selection 1 output.
        rs1 : OUT STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0) := (OTHERS => '0');
        --! @brief Register selection 1 output.
        rs2 : OUT STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0) := (OTHERS => '0');
        --! @brief Register selection 1 output.
        rd : OUT STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0) := (OTHERS => '0');
        --! @brief Register selection 1 output.
        imm : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := (OTHERS => '0');
        --! @brief Register selection 1 output.
        addr : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := (OTHERS => '0');
        --! @brief Register selection 1 output.
        opcode : OUT instructions;
        --! @brief Register selection 1 output.
        illegal : OUT STD_LOGIC;
        --! @brief Register selection 1 output.
        pause : OUT STD_LOGIC;

        --------------------------------------------------------------------------------------------------------
        -- Clocks & controls
        --------------------------------------------------------------------------------------------------------
        --! @brief clock input of the core. Must match the INPUT_FREQ generics within some tolerance.
        clock : IN STD_LOGIC;
        --! @brief clock enable from the core clock controller. Used to not create two clock domains from the master clock and the auxilliary clock.
        clock_en : IN STD_LOGIC;
        --! @brief reset input, active low. When held to '0', the system will remain in the reset state until set to '1'.
        nRST : IN STD_LOGIC
    );
END ENTITY;

ARCHITECTURE behavioral OF decoder IS

    --------------------------------------------------------------------------------------------------------
    -- Types definitions
    --------------------------------------------------------------------------------------------------------
    --! @brief Custom types to define a name for the different decoders to be used.
    TYPE decocders_type IS (U, I, R, B, S, J, default_t, illegal_t, NOP);

    --------------------------------------------------------------------------------------------------------
    -- Internal states
    --------------------------------------------------------------------------------------------------------
    --! @brief Illegal flag issued from the first process.
    SIGNAL illegal_internal : STD_LOGIC := '0';
    --! @brief Illegal flag issued from the second process.
    SIGNAL illegal_internal2 : STD_LOGIC := '0';
    --! @brief Output illegal state (used because we can't readback an output port). Generate by ORing both of the previous signals.
    SIGNAL illegal_internal_out : STD_LOGIC := '0';

    --------------------------------------------------------------------------------------------------------
    -- Internal states
    --------------------------------------------------------------------------------------------------------
    --! @brief Selected decoder issued by the first process. Depends on the custom type defined before.
    SIGNAL selected_decoder : decocders_type := default_t;
    --! @brief Registered selected decoder, 
    SIGNAL r_selected_decoder : decocders_type := default_t;

    --------------------------------------------------------------------------------------------------------
    -- Latchs outputs
    --------------------------------------------------------------------------------------------------------
    --! @brief RS1 output before getting assigned (to enable illegal zeroing).
    SIGNAL rs1_internal : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    --! @brief RS2 output before getting assigned (to enable illegal zeroing).
    SIGNAL rs2_internal : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    --! @brief RD output before getting assigned (to enable illegal zeroing).
    SIGNAL rd_internal : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    --! @brief Immediate output before getting assigned (to enable illegal zeroing).
    SIGNAL imm_internal : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := (OTHERS => '0');

    --------------------------------------------------------------------------------------------------------
    -- Internal instruction bus, with the right endianess
    --------------------------------------------------------------------------------------------------------
    --! @brief Registered instruction to be treated within the first process.
    SIGNAL i_instruction : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    --! @brief Registered instruction to be treated within the second process (copy of i1, one cycle later).
    SIGNAL i2_instruction : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    --! @brief Raw instruction, output of the endianess corrector.
    SIGNAL r_instruction : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');

    --------------------------------------------------------------------------------------------------------
    -- Internal address bus, for instruction corrections
    --------------------------------------------------------------------------------------------------------
    --! @brief First stage of the address registration.
    SIGNAL i0_addr : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := (OTHERS => '0');
    --! @brief Second stage of the address registration.
    SIGNAL i1_addr : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := (OTHERS => '0');

    --------------------------------------------------------------------------------------------------------
    -- remove the first decoder cycle glitch
    --------------------------------------------------------------------------------------------------------
    --! @brief Flag to prevent from the input register to getting the data. This prevent from a duplication of the first instruction.
    --! Memory is responding within a clock cycle, before the first cycle of the decoder. And memory won't output the next instruction
    --! before three cycle, which will effectively read the instruction twice.
    SIGNAL first_flag : STD_LOGIC := '0';
    --! @brief A pause is required for this instruction, because it WILL need more than a CPU cycle to be executed.
    SIGNAL req_pause : STD_LOGIC := '0';
    --! @brief Pause cycles that are required for the current instruction.
    SIGNAL pause_cycles : INTEGER RANGE 0 TO 3 := 0;
    --! @brief Paused flag, asserted when the logic acknowledged the pause_req status.
    SIGNAL paused : STD_LOGIC := '0';

    --------------------------------------------------------------------------------------------------------
    -- Evolution auth
    --------------------------------------------------------------------------------------------------------
    --! @brief Enable or disable the registration of new values, to prevent from skipping instructions.
    SIGNAL shift_auth : STD_LOGIC := '0';

BEGIN

    -- Endianess correctors
    U1 : ENTITY work.endianess(rtl)
        GENERIC MAP(
            XLEN => 32
        )
        PORT MAP(
            datain => instruction,
            dataout => r_instruction
        );

    --========================================================================================
    --! @brief this first process, P0 handles address registration for the output, as well as 
    --! instruction registering.
    --! @details
    --! This first process register inputs if the shift_auth bit is active. This enable the 
    --! clocking of a new ONLY enough
    --! stall cycles for the previous instruction has been elapsed.
    --========================================================================================
    P0 : PROCESS (clock, nRST)
    BEGIN
        IF (nRST = '0') THEN
            i_instruction <= (OTHERS => '0');
            first_flag <= '1';

            i0_addr <= (OTHERS => '0');
            i1_addr <= (OTHERS => '0');

        ELSIF rising_edge(clock) AND (clock_en = '1') AND (shift_auth = '1') THEN
            IF (first_flag <= '0') THEN
                i_instruction <= r_instruction;

                -- Registering the address synchronously with the decoder.
                -- This enable the output of a clean address bus that match with the actual execution code.
                i0_addr <= act_addr;
                i1_addr <= i0_addr;
                addr <= i1_addr;

            ELSE
                first_flag <= '0';
            END IF;

        END IF;

    END PROCESS;

    --========================================================================================
    --! @brief This second process, P2 will handle the decoder selection.
    --! @details
    --! This second process look to the 7 LSB of the instruction, and decide which decoder 
    --! shall be used for this instruction.
    --! A second role is to handle the number of stall cycles required for an instruction, 
    --! which won't enable the ability to
    --! react extremely fast ON the pipeline, and thus, remove complex logic on the core 
    --! controller (which would need 
    --! to stall 6 stages of pipeline).
    --! The only drawback is that we can't predict the output, so, instructions that could 
    --! take 2 or 3 cycles will ALWAYS take 3.
    --! On such a simple core, the performance loss is more than acceptable, but could be 
    --! quite big if we need higher performances.
    --========================================================================================
    P1 : PROCESS (nRST, clock)

        VARIABLE paused_cycles : INTEGER RANGE 0 TO 3 := 0;

    BEGIN

        IF (nRST = '0') THEN
            illegal_internal <= '0';
            selected_decoder <= NOP;
            req_pause <= '0';
            pause_cycles <= 0;
            paused_cycles := 0;
            paused <= '0';

        ELSIF rising_edge(clock) AND (clock_en = '1') THEN

            IF (req_pause = '0') AND (paused = '0') THEN

                -- Select the opcode, and perform an instruction size check (last two bits must be "11").
                CASE i_instruction(6 DOWNTO 0) IS

                    WHEN "0110111" => -- LUI
                        selected_decoder <= U;
                        illegal_internal <= '0';
                        req_pause <= '0';
                        pause_cycles <= 0;

                    WHEN "0010111" => -- AUIPC
                        selected_decoder <= U;
                        illegal_internal <= '0';
                        req_pause <= '0';
                        pause_cycles <= 0;

                    WHEN "0010011" => -- Immediates
                        selected_decoder <= I;
                        illegal_internal <= '0';
                        req_pause <= '0';
                        pause_cycles <= 0;

                    WHEN "0001111" => -- FENCE
                        selected_decoder <= I;
                        illegal_internal <= '0';
                        req_pause <= '0';
                        pause_cycles <= 0;

                    WHEN "1100111" => --(JALR)
                        selected_decoder <= I;
                        illegal_internal <= '0';
                        req_pause <= '1';
                        pause_cycles <= 1;

                    WHEN "1110011" => -- Calls
                        selected_decoder <= I;
                        illegal_internal <= '0';
                        req_pause <= '1';
                        pause_cycles <= 1;

                    WHEN "0000011" => -- Store
                        selected_decoder <= I;
                        illegal_internal <= '0';
                        req_pause <= '0';
                        pause_cycles <= 0;

                    WHEN "0110011" => -- Register operations
                        selected_decoder <= R;
                        illegal_internal <= '0';
                        req_pause <= '0';
                        pause_cycles <= 0;

                    WHEN "1100011" => -- Branchs
                        selected_decoder <= B;
                        illegal_internal <= '0';
                        req_pause <= '1';
                        pause_cycles <= 1;

                    WHEN "0100011" => -- Loads
                        selected_decoder <= S;
                        illegal_internal <= '0';
                        req_pause <= '0';
                        pause_cycles <= 0;

                    WHEN "1101111" => -- Jumps
                        selected_decoder <= J;
                        illegal_internal <= '0';
                        req_pause <= '1';
                        pause_cycles <= 1;

                    WHEN "0000000" => -- All zero, seen as NOP
                        selected_decoder <= NOP;
                        illegal_internal <= '0';
                        req_pause <= '0';
                        pause_cycles <= 0;

                    WHEN OTHERS =>
                        selected_decoder <= illegal_t;
                        illegal_internal <= '1';
                        req_pause <= '0';
                        pause_cycles <= 0;

                END CASE;

                -- Handle the pause system
            ELSE

                -- First pause request
                IF (req_pause = '1') THEN

                    -- Store the state
                    paused_cycles := pause_cycles - 1;

                    -- Enable to "skip" the paused status if the stall lenght is one cycle.
                    -- This step is, in fact already handled by the state we're here.
                    IF (pause_cycles /= 1) THEN
                        paused <= '1';
                    END IF;

                    -- ACK the pause request
                    pause_cycles <= 0;
                    req_pause <= '0';

                ELSIF (paused = '1') THEN

                    -- Check if we need to unlock the state, or continue to decrement the counter
                    IF (paused_cycles /= 0) THEN
                        paused_cycles := paused_cycles - 1;
                    END IF;

                    IF (paused_cycles = 0) THEN
                        paused <= '0';
                    END IF;

                END IF;

            END IF;

        END IF;

    END PROCESS;

    --========================================================================================
    --! @brief This third process cut the decoding process into two halves, each one with a 
    --! dedicated job
    --! by registering the outputs from the first process to feed them into the second stage.
    --! @details
    --! In fact, this process gave us extremely high performance gain (+125% Core frequency), 
    --! because the decoder is one of the elements that has a massive influcence on the 
    --! critical path.
    --========================================================================================
    P2 : PROCESS (clock, nRST, clock_en)
    BEGIN
        IF (nRST = '0') THEN

            i2_instruction <= (OTHERS => '0');

        ELSIF rising_edge(clock) AND (clock_en = '1') AND (shift_auth = '1') THEN

            i2_instruction <= i_instruction;

        END IF;
    END PROCESS;

    --========================================================================================
    --! @brief This last process produce the output of the decoder, to the core controller.
    --! @details
    --! With the selected decoder previously selected, we can directly jump into slicing the 
    --! instruction into smaller parts, and doing to SEXT operation on immediates.
    --! Some combinational selection occurs to choose the right opcode.
    --========================================================================================
    P3 : PROCESS (nRST, r_selected_decoder, i2_instruction)
    BEGIN
        IF (nRST = '0') THEN
            rs1_internal <= (OTHERS => '0');
            rs2_internal <= (OTHERS => '0');
            imm_internal <= (OTHERS => '0');
            rd_internal <= (OTHERS => '0');
            opcode <= i_NOP;
            illegal_internal2 <= '0';

        ELSE

            CASE selected_decoder IS

                    -- Register to register operation
                WHEN R =>
                    rd_internal <= i2_instruction(11 DOWNTO 7);
                    rs1_internal <= i2_instruction(19 DOWNTO 15);

                    rs2_internal <= i2_instruction(24 DOWNTO 20);
                    imm_internal <= (OTHERS => '0');

                    -- i_instruction identification
                    CASE i2_instruction(31 DOWNTO 25) IS

                        WHEN "0000000" => -- ADD SLL SLT XOR SRL OR AND

                            CASE i2_instruction(14 DOWNTO 12) IS

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

                            CASE i2_instruction(14 DOWNTO 12) IS

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
                    rd_internal <= i2_instruction(11 DOWNTO 7);
                    rs1_internal <= i2_instruction(19 DOWNTO 15);
                    rs2_internal <= (OTHERS => '0');
                    imm_internal <= (OTHERS => i2_instruction(31));
                    imm_internal(11 DOWNTO 0) <= i2_instruction(31 DOWNTO 20);

                    -- i_instruction identification
                    CASE i2_instruction(6 DOWNTO 2) IS

                        WHEN "00100" =>

                            CASE i2_instruction(14 DOWNTO 12) IS

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
                                    IF (i2_instruction(30) = '1') THEN
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

                            CASE i2_instruction(14 DOWNTO 12) IS

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
                            IF (i2_instruction(14 DOWNTO 12) = "000") THEN
                                opcode <= i_JALR;
                                illegal_internal2 <= '0';
                            ELSE
                                opcode <= i_NOP;
                                illegal_internal2 <= '1';
                            END IF;

                        WHEN "11100" =>

                            CASE i2_instruction(14 DOWNTO 12) IS

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

                                    CASE i2_instruction(31 DOWNTO 20) IS

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
                    rs1_internal <= i2_instruction(19 DOWNTO 15);
                    rs2_internal <= i2_instruction(24 DOWNTO 20);
                    imm_internal <= (OTHERS => i2_instruction(31));
                    imm_internal(11 DOWNTO 0) <= i2_instruction(31 DOWNTO 25)
                    & i2_instruction(11 DOWNTO 7);

                    -- i_instruction identification
                    CASE i2_instruction(14 DOWNTO 12) IS

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
                    rs1_internal <= i2_instruction(19 DOWNTO 15);
                    rs2_internal <= i2_instruction(24 DOWNTO 20);
                    imm_internal <= (OTHERS => i2_instruction(31));
                    imm_internal(12 DOWNTO 1) <= i2_instruction(31)
                    & i2_instruction(7)
                    & i2_instruction(30 DOWNTO 25)
                    & i2_instruction(11 DOWNTO 8);
                    imm_internal(0) <= '0';

                    -- i_instruction identification
                    CASE i2_instruction(14 DOWNTO 12) IS

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
                    rd_internal <= i2_instruction(11 DOWNTO 7);
                    rs1_internal <= (OTHERS => '0');
                    rs2_internal <= (OTHERS => '0');
                    imm_internal <= i2_instruction(31 DOWNTO 12)
                        & "000000000000";

                    -- i_instruction identification
                    CASE i2_instruction(6 DOWNTO 2) IS

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
                    rd_internal <= i2_instruction(11 DOWNTO 7);
                    rs1_internal <= (OTHERS => '0');
                    rs2_internal <= (OTHERS => '0');
                    imm_internal <= (OTHERS => i2_instruction(31));
                    imm_internal(20 DOWNTO 1) <= i2_instruction(31)
                    & i2_instruction(19 DOWNTO 12)
                    & i2_instruction(20)
                    & i2_instruction(30 DOWNTO 21);
                    imm_internal(0) <= '0';

                    -- i_instruction identification
                    CASE i2_instruction(6 DOWNTO 2) IS

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

    rs1 <= rs1_internal WHEN (illegal_internal_out = '0') ELSE
        STD_LOGIC_VECTOR(to_unsigned(0, rs1'length));
    rs2 <= rs2_internal WHEN (illegal_internal_out = '0') ELSE
        STD_LOGIC_VECTOR(to_unsigned(0, rs2'length));
    rd <= rd_internal WHEN (illegal_internal_out = '0') ELSE
        STD_LOGIC_VECTOR(to_unsigned(0, rd'length));
    imm <= imm_internal WHEN (illegal_internal_out = '0') ELSE
        STD_LOGIC_VECTOR(to_unsigned(0, imm'length));

    -- Output the pause combinational output
    shift_auth <= NOT (req_pause OR paused);
    pause <= shift_auth;

END ARCHITECTURE;