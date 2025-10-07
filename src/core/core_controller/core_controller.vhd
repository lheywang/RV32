--! @file src/core/core.vhd
--! @brief The base file that assemble all of the components of the core. Does not include any form of memory.
--! @author l.heywang <leonard.heywang@proton.me>
--! @date 05-10-2025

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE work.common.ALL;
USE work.records.ALL;

ENTITY core_controller IS
    GENERIC (
        --! @brief Configure the data width in the core.
        XLEN : INTEGER := 32;
        --! @brief Configure the number of registers available. May be changed accordingly to configure for example the reduced instruction set.
        REG_NB : INTEGER := 32;

        --! @brief Configure the address to which the program jumps when an exception occurs.
        INT_ADDR : INTEGER := 0
    );
    PORT (
        --------------------------------------------------------------------------------------------------------
        -- Clocks & controls
        --------------------------------------------------------------------------------------------------------
        --! @brief clock input of the core. Must match the INPUT_FREQ generics within some tolerance.
        clock : IN STD_LOGIC;
        --! @brief clock enable from the core clock controller. Used to not create two clock domains from the master clock and the auxilliary clock.
        clock_en : IN STD_LOGIC;
        --! @brief reset input, active low. When held to '0', the system will remain in the reset state until set to '1'.
        nRST : IN STD_LOGIC;

        --------------------------------------------------------------------------------------------------------
        -- Decoder I/O signals
        --------------------------------------------------------------------------------------------------------
        --! @brief Decoder RS1 input
        dec_rs1 : IN STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
        --! @brief Decoder RS2 input
        dec_rs2 : IN STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
        --! @brief Decoder RD input
        dec_rd : IN STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
        --! @brief Decoder Immediate input
        dec_imm : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        --! @brief Decoder opcodes input
        dec_opcode : IN instructions;
        --! @brief Decoder illegal flag input
        dec_illegal : IN STD_LOGIC;
        --! @brief Decoder reset signal.
        dec_reset : OUT STD_LOGIC;

        --------------------------------------------------------------------------------------------------------
        -- memory I/O signals
        --------------------------------------------------------------------------------------------------------
        --! @brief Memory address output.
        mem_addr : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := (OTHERS => '0');
        --! @brief Memory byte enabling signals.
        mem_byteen : OUT STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '1');
        --! @brief Memory write enable signal.
        mem_we : OUT STD_LOGIC := '0';
        --! @brief Memory request signal. Asserted for 1 CPU cycle when data on the lines is valid.
        mem_req : OUT STD_LOGIC := '0';
        --! @brief Memory invalid address input flag. Asserted if nothing is available on the specified address.
        mem_addrerr : IN STD_LOGIC;

        --------------------------------------------------------------------------------------------------------
        -- Program counter I/O signals
        --------------------------------------------------------------------------------------------------------
        --! @brief Program counter load value.
        pc_value : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        --! @brief Program counter overflow input flag.
        pc_overflow : IN STD_LOGIC;
        --! @brief Program counter enable control.
        pc_enable : OUT STD_LOGIC := '1';
        --! @brief Program counter write enable control (used to load a new value on it).
        pc_wren : OUT STD_LOGIC := '0';
        --! @brief Program counter load value.
        pc_loadvalue : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := (OTHERS => '0');

        --------------------------------------------------------------------------------------------------------
        -- Register file I/O signals
        --------------------------------------------------------------------------------------------------------
        --! @brief Register write enable signal
        reg_we : OUT STD_LOGIC := '0';
        --! @brief Register write address
        reg_wa : OUT INTEGER RANGE 0 TO (REG_NB - 1) := 0;
        --! @brief Register read address for port 1
        reg_ra1 : OUT INTEGER RANGE 0 TO (REG_NB - 1) := 0;
        --! @brief Register read address for port 2
        reg_ra2 : OUT INTEGER RANGE 0 TO (REG_NB - 1) := 0;
        --! @brief Read back of the register file port 2 (used for jumping to relatives addresses).
        reg_rs1_in : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        --! @brief Immediate output of the core_controller.
        reg_rs2_out : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := (OTHERS => '0');

        --------------------------------------------------------------------------------------------------------
        -- CSR Register file I/O signals
        --------------------------------------------------------------------------------------------------------
        --! @brief CSR register file write enable.
        csr_we : OUT STD_LOGIC := '0';
        --! @brief CSR register file write address.
        csr_wa : OUT csr_register := r_MTVAL;
        --! @brief CSR register file read address.
        csr_ra1 : OUT csr_register := r_MTVAL;
        --! @brief CSR register master interrupt enable bit.
        csr_mie : IN STD_LOGIC;
        --! @brief CSR register master interrupt pending bit.
        csr_mip : IN STD_LOGIC;
        --! @brief CSR register raw read value
        csr_rs1_in : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

        --------------------------------------------------------------------------------------------------------
        -- ALU controls I/O signals
        --------------------------------------------------------------------------------------------------------
        --! @brief Argument selection for the input 1 of the ALU.
        arg1_sel : OUT STD_LOGIC := '0';
        --! @brief Argument selection for the input 2 of the ALU.
        arg2_sel : OUT STD_LOGIC := '0';
        --! @brief Command of the ALU, to choose the operation to be done.
        alu_cmd : OUT commands := c_ADD;
        --! @brief ALU readback status.
        alu_status : IN alu_feedback;

        --------------------------------------------------------------------------------------------------------
        -- Misc. I/O signals
        --------------------------------------------------------------------------------------------------------
        --! @brief Instruction fetch error flag input. Used to indicate ANY errors from the IF memory.
        if_err : IN STD_LOGIC;
        --! @brief CTL exception, used to indicate that the processor received an external exception request.
        ctl_exception : IN STD_LOGIC;
        --! @brief CTL halt, used to stop the execution, at any stages. May be usefull to debug the core status.
        ctl_halt : IN STD_LOGIC;
        --! @brief Instruction fetch async clear, used to empty the output buffer after a jump was taken.
        if_aclr : OUT STD_LOGIC := '0';

        --------------------------------------------------------------------------------------------------------
        -- Debug outputs I/O signals
        --------------------------------------------------------------------------------------------------------
        --! @brief Exception output, to indicate that an exception is currently handled. Usefull for debug.
        excep_occured : OUT STD_LOGIC := '0';
        --! @brief Halt output, to indicate that an halt is actually done.
        core_halt : OUT STD_LOGIC := '0'
    );
END ENTITY;

ARCHITECTURE behavioral OF core_controller IS

    --! @brief Defining FSM states.
    --! @details
    --! Define each status, for longer instruction cycles, such as jumps, branchs or so.
    --! Each state is named after the logic :
    --!     Tx_y, where
    --!     x is the total number of states
    --!     y is the actual state
    --! Thus, when x = y, the instructon is in it's last cycle.
    TYPE FSM_states IS (
        T0,
        T1_0, T1_1,
        -- T2_0, T2_1, T2_2,
        T4_0, T4_1, T4_2, T4_3, T4_4
    );

    --------------------------------------------------------------------------------------------------------
    -- First stage signals registration.
    --------------------------------------------------------------------------------------------------------
    --! @brief registered RS1 decoder input
    SIGNAL r1_dec_rs1 : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    --! @brief registered RS2 decoder input
    SIGNAL r1_dec_rs2 : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    --! @brief registered RD decoder input
    SIGNAL r1_dec_rd : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    --! @brief registered Immediate decoder input
    SIGNAL r1_dec_imm : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief registered opcode decoder input
    SIGNAL r1_dec_opcode : instructions;

    --! @brief registered memory error flag
    SIGNAL r1_mem_addrerr : STD_LOGIC;
    --! @brief registered decoder illegal flag
    SIGNAL r1_dec_illegal : STD_LOGIC;
    --! @brief registered program counter overflow
    SIGNAL r1_pc_overflow : STD_LOGIC;
    --! @brief registered instruction fetch error.
    SIGNAL r1_if_err : STD_LOGIC;
    --! @brief registered control exception.
    SIGNAL r1_ctl_exception : STD_LOGIC;
    --! @brief registerd control halt.
    SIGNAL r1_ctl_halt : STD_LOGIC;
    --! @brief registered MIE bit status.
    SIGNAL r1_csr_mie : STD_LOGIC;
    --! @brief registered MIP bit status
    SIGNAL r1_csr_mip : STD_LOGIC;
    --! @brief registered CSR in value
    SIGNAL r1_csr_rs1_in : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

    --! @brief registered program counter value.
    SIGNAL r1_pc_value : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

    --! @brief Signal to require a flush of the R1 registers, for example after a jump or a branch.
    SIGNAL r1_flush_needed : STD_LOGIC;

    --------------------------------------------------------------------------------------------------------
    -- First stage outputs
    --------------------------------------------------------------------------------------------------------
    --! @brief Cycles count, used to track the current and the next cycle to be executed.
    SIGNAL cycles_count : FSM_states;

    --! @brief First stage output to signal that the next instruction require an immediate value to be outputed.
    SIGNAL is_immediate : STD_LOGIC;

    --! @brief First stage output to signal that the next instruction require a value from the first port of the register file.
    SIGNAL is_req_data1 : STD_LOGIC;
    --! @brief First stage output to signal that the next instruction require a value from the second port of the register file.
    SIGNAL is_req_data2 : STD_LOGIC;
    --! @brief First stage output to signal that the next instruction require a value from the CSR registers.
    SIGNAL is_req_csr : STD_LOGIC;
    --! @brief First stage output to signal that the next instruction require to write a value on some registers.
    SIGNAL is_req_store : STD_LOGIC;

    --! @brief First stage output to signal that the next instruction require an access to the memory.
    SIGNAL is_req_mem : STD_LOGIC;

    --! @brief First stage output to signal that the next instruction require the usage of the ALU.
    SIGNAL is_req_alu : STD_LOGIC;

    --! @brief First stage output the require ALU opcode, if needed.
    SIGNAL alu_opcode : commands;

    --! @brief First stage output to signal that we're handling an error / interrupt, and thus, we shall not handle another one, at the risk of losing track of the program counter.
    SIGNAL irq_err : STD_LOGIC;
    --! @brief First stage output to select the right csr register.
    SIGNAL csr_reg : csr_register;

    --------------------------------------------------------------------------------------------------------
    -- Second stage registration bits.
    --------------------------------------------------------------------------------------------------------
    --! @brief Second registration stage of the RS1 decoder output.
    SIGNAL r2_dec_rs1 : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    --! @brief Second registration stage of the RS2 decoder output.
    SIGNAL r2_dec_rs2 : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    --! @brief Second registration stage of the RD decoder output.
    SIGNAL r2_dec_rd : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    --! @brief Second registration stage of immediate decoder output.
    SIGNAL r2_dec_imm : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Second registration stage of opcode deocder output.
    SIGNAL r2_dec_opcode : instructions;

    --! @brief Second registration stage of memory address error status flag.
    SIGNAL r2_mem_addrerr : STD_LOGIC;
    --! @brief Second registration stage of decoder illegal instruction error status flag.
    SIGNAL r2_dec_illegal : STD_LOGIC;
    --! @brief Second registration stage of program counter overflow error status flag.
    SIGNAL r2_pc_overflow : STD_LOGIC;
    --! @brief Second registration stage of instruction fetch error flag.
    SIGNAL r2_if_err : STD_LOGIC;

    --! @brief Second registration stage of program counter value.
    SIGNAL r2_pc_value : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

    --! @brief Second registration stage of control exception request flag.
    SIGNAL r2_ctl_exception : STD_LOGIC;
    --! @brief Second registration stage of halt request flag.
    SIGNAL r2_ctl_halt : STD_LOGIC;

    --! @brief Second registration stage of cycles counts status.
    SIGNAL r2_cycles_count : FSM_states;

    --! @brief Second registration stage of is_immediate flag, required for executing instruction.
    SIGNAL r2_is_immediate : STD_LOGIC;
    --! @brief Second registration stage of is_req_data1 flag, required for executing instruction.
    SIGNAL r2_is_req_data1 : STD_LOGIC;
    --! @brief Second registration stage of is_req_data2 flag, required for executing instruction.
    SIGNAL r2_is_req_data2 : STD_LOGIC;
    --! @brief Second registration stage of is_req_store flag, required for executing instruction.
    SIGNAL r2_is_req_store : STD_LOGIC;
    --! @brief Second registration stage of is_req_alu flag, required for executing instruction.
    SIGNAL r2_is_req_alu : STD_LOGIC;
    --! @brief Second registration stage of is_req_csr flag, required for executing instruction.
    SIGNAL r2_is_req_csr : STD_LOGIC;
    --! @brief Second registration stage of is_req_mem flag, required for executing instruction.
    SIGNAL r2_is_req_mem : STD_LOGIC;
    --! @brief Second registration stage of alu_opcode.
    SIGNAL r2_alu_opcode : commands;
    --! @brief Second registration stage of reg_csr.
    SIGNAL r2_reg_csr : csr_register;
    --! @brief registered CSR in value
    SIGNAL r2_csr_rs1_in : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

    --------------------------------------------------------------------------------------------------------
    -- Laters stages registration.
    --------------------------------------------------------------------------------------------------------
    --! @brief Third stage of the instruction registers.
    SIGNAL r3_dec_opcode : instructions;
    --! @brief Fourth stage of the instruction registers.
    SIGNAL r4_dec_opcode : instructions;
    --! @brief Fifth stage of the instruction registers.
    SIGNAL r5_dec_opcode : instructions;
    --! @brief Sixth stage of the instruction registers.
    SIGNAL r6_dec_opcode : instructions;

    --! @brief Third registration of the raw input from register file.
    SIGNAL r3_reg_rs1_in : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

    --! @brief Third registration of the program counter value.
    SIGNAL r3_pc_value : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

    --! @brief Third registration of the decoder immediate value.
    SIGNAL r3_dec_imm : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Third registration of the csr register selection.
    SIGNAL r3_reg_csr : csr_register;
    --! @brief Third registration of the cycles_count value.
    SIGNAL r3_cycles_count : FSM_states;

    --! @brief Register the alu status for the branch taking
    SIGNAL r3_alu_status : alu_feedback;

    --! @brief Register the interrupt pending bit
    SIGNAL r2_csr_mip : STD_LOGIC;

    --! @brief Register the interrupt pending bit a second time
    SIGNAL r3_csr_mip : STD_LOGIC;
    --! @brief Second registration stage of memory address error status flag.
    SIGNAL r3_mem_addrerr : STD_LOGIC;
    --! @brief Second registration stage of decoder illegal instruction error status flag.
    SIGNAL r3_dec_illegal : STD_LOGIC;
    --! @brief Second registration stage of program counter overflow error status flag.
    SIGNAL r3_pc_overflow : STD_LOGIC;
    --! @brief Second registration stage of instruction fetch error flag.
    SIGNAL r3_if_err : STD_LOGIC;
    --! @brief Second registration stage of control exception request flag.
    SIGNAL r3_ctl_exception : STD_LOGIC;
    --! @brief Second registration stage of halt request flag.
    SIGNAL r3_ctl_halt : STD_LOGIC;

BEGIN

    --========================================================================================
    --! @brief This first process register the input to be treated on the next process.
    --========================================================================================
    P1 : PROCESS (clock, nRST, r1_flush_needed)
    BEGIN

        IF (nRST = '0') THEN

            -- We don't want to interfer with trap handling 
            -- when the previous instruction was a jump.
            -- Thus, we exclude them from the reset (but, they're 
            -- affect by they're source reset, the csr register file).
            r1_csr_mip <= '0';
            r1_csr_mie <= '0';

        END IF;

        IF (nRST = '0') OR (r1_flush_needed = '1') THEN
            r1_dec_rs1 <= (OTHERS => '0');
            r1_dec_rs2 <= (OTHERS => '0');
            r1_dec_rd <= (OTHERS => '0');
            r1_dec_imm <= (OTHERS => '0');
            r1_dec_opcode <= i_NOP;

            r1_pc_value <= (OTHERS => '0');

            r1_dec_illegal <= '0';
            r1_mem_addrerr <= '0';
            r1_pc_overflow <= '0';
            r1_if_err <= '0';
            r1_ctl_exception <= '0';
            r1_ctl_halt <= '0';

            r1_csr_rs1_in <= (OTHERS => '0');

        ELSIF rising_edge(clock) AND (clock_en = '1') THEN
            r1_dec_rs1 <= dec_rs1;
            r1_dec_rs2 <= dec_rs2;
            r1_dec_rd <= dec_rd;
            r1_dec_imm <= dec_imm;
            r1_dec_opcode <= dec_opcode;

            r1_pc_value <= pc_value;

            r1_dec_illegal <= dec_illegal;
            r1_mem_addrerr <= mem_addrerr;
            r1_pc_overflow <= pc_overflow;
            r1_if_err <= if_err;
            r1_ctl_exception <= ctl_exception;
            r1_ctl_halt <= ctl_halt;

            r1_csr_mip <= csr_mip;
            r1_csr_mie <= csr_mie;

            r1_csr_rs1_in <= csr_rs1_in;

        END IF;

    END PROCESS;

    --=========================================================================
    --! @brief In this second process, we can analyze the inputs and select the
    --! the requirements signals depending on the opcode.
    --! We also compute the next cycle to be executed, depending on the actual
    --! state.
    --=========================================================================
    P2 : PROCESS (nRST, r1_dec_rs1, r1_dec_rs2, r1_dec_rd,
        r1_dec_imm, r1_dec_opcode, r1_pc_value, r1_dec_illegal,
        r1_mem_addrerr, r1_pc_overflow, r1_if_err, r1_ctl_exception,
        r1_ctl_halt, r1_csr_mip, r1_csr_mie, r2_cycles_count)

        VARIABLE tmp : STD_LOGIC_VECTOR(11 DOWNTO 0);

    BEGIN
        IF (nRST = '0') THEN
            cycles_count <= T0;
            is_immediate <= '0';
            is_req_data1 <= '0';
            is_req_data2 <= '0';
            is_req_store <= '0';
            is_req_alu <= '0';
            is_req_csr <= '0';
            is_req_mem <= '0';
            irq_err <= '0';
            csr_reg <= r_MTVAL;

        ELSIF (r1_dec_illegal = '1') OR (r1_mem_addrerr = '1') OR (r1_pc_overflow = '1') OR
            (r1_if_err = '1') OR (r1_ctl_exception = '1') OR (r1_csr_mip = '1') THEN
            -- Check if we're already interrupting, and if we have the right to do it...
            IF (irq_err = '0') THEN

                cycles_count <= T4_0;

                -- We don't really care about theses signals, since
                -- there's, in fact a single handler for all of theses cases.
                is_immediate <= '0';
                is_req_data1 <= '0';
                is_req_data2 <= '0';
                is_req_store <= '0';
                is_req_alu <= '0';
                is_req_csr <= '0';
                is_req_mem <= '0';

                -- Inhibit the next irq / err
                irq_err <= '1';

            END IF;

            -- Try to deduce the next cycle ONLY if we're on the last opcode cycle
        ELSIF (r2_cycles_count = T0) OR (r2_cycles_count = T1_1) OR -- (r2_cycles_count = T2_2) OR
            (r2_cycles_count = T4_4) THEN

            CASE r1_dec_opcode IS

                    ------------------------------------------------------------------
                WHEN i_NOP | i_FENCE =>

                    cycles_count <= T0;
                    is_immediate <= '0';
                    is_req_data1 <= '0';
                    is_req_data2 <= '0';
                    is_req_store <= '0';
                    is_req_alu <= '0';
                    is_req_csr <= '0';
                    is_req_mem <= '0';

                    alu_opcode <= c_NONE;
                    csr_reg <= r_MTVAL;

                    ------------------------------------------------------------------
                WHEN i_ADDI | i_SLTI | i_SLTIU | i_XORI |
                    i_ANDI | i_SLLI | i_SRLI | i_SRAI |
                    i_ORI | i_LUI | i_AUIPC =>

                    cycles_count <= T0;
                    is_immediate <= '1';
                    is_req_data1 <= '1';
                    is_req_data2 <= '0';
                    is_req_store <= '1';
                    is_req_alu <= '1';
                    is_req_csr <= '0';
                    is_req_mem <= '0';

                    csr_reg <= r_MTVAL;

                    CASE r1_dec_opcode IS
                        WHEN i_ADDI | i_LUI => alu_opcode <= c_ADD;
                        WHEN i_SLTI => alu_opcode <= c_SLT;
                        WHEN i_SLTIU => alu_opcode <= c_SLTU;
                        WHEN i_XORI => alu_opcode <= c_XOR;
                        WHEN i_ANDI => alu_opcode <= c_AND;
                        WHEN i_SLLI => alu_opcode <= c_SLL;
                        WHEN i_SRLI => alu_opcode <= c_SRL;
                        WHEN i_SRAI => alu_opcode <= c_SRA;
                        WHEN i_ORI | i_AUIPC => alu_opcode <= c_OR;
                        WHEN OTHERS => alu_opcode <= c_NONE;
                    END CASE;

                    ------------------------------------------------------------------
                WHEN i_ADD | i_SUB | i_SLL | i_SLT |
                    i_SLTU | i_XOR | i_SRL | i_SRA |
                    i_OR | i_AND =>

                    cycles_count <= T0;
                    is_immediate <= '0';
                    is_req_data1 <= '1';
                    is_req_data2 <= '1';
                    is_req_store <= '1';
                    is_req_alu <= '1';
                    is_req_csr <= '0';
                    is_req_mem <= '0';

                    csr_reg <= r_MTVAL;

                    CASE r1_dec_opcode IS
                        WHEN i_ADD => alu_opcode <= c_ADD;
                        WHEN i_SUB => alu_opcode <= c_SUB;
                        WHEN i_SLT => alu_opcode <= c_SLT;
                        WHEN i_SLTU => alu_opcode <= c_SLTU;
                        WHEN i_XOR => alu_opcode <= c_XOR;
                        WHEN i_AND => alu_opcode <= c_AND;
                        WHEN i_SLL => alu_opcode <= c_SLL;
                        WHEN i_SRL => alu_opcode <= c_SRL;
                        WHEN i_SRA => alu_opcode <= c_SRA;
                        WHEN i_OR => alu_opcode <= c_OR;
                        WHEN OTHERS => alu_opcode <= c_NONE;
                    END CASE;

                    ------------------------------------------------------------------
                WHEN i_CSRRW | i_CSRRS | i_CSRRC | i_CSRRWI |
                    i_CSRRSI | i_CSRRCI =>

                    cycles_count <= T1_0;

                    -- We don't really care about theses since we're on a 2 cycles instruction.
                    is_immediate <= '0';
                    is_req_data1 <= '0';
                    is_req_data2 <= '0';
                    is_req_store <= '0';
                    is_req_alu <= '0';
                    is_req_csr <= '0';
                    is_req_mem <= '0';
                    alu_opcode <= c_NONE;

                    tmp := r1_dec_imm(11 DOWNTO 0);
                    CASE tmp IS
                        WHEN X"300" => csr_reg <= r_MSTATUS;
                        WHEN X"F10" => csr_reg <= r_MISA;
                        WHEN X"304" => csr_reg <= r_MIE;
                        WHEN X"305" => csr_reg <= r_MTVEC;
                        WHEN X"340" => csr_reg <= r_MSCRATCH;
                        WHEN X"341" => csr_reg <= r_MEPC;
                        WHEN X"342" => csr_reg <= r_MCAUSE;
                        WHEN X"343" => csr_reg <= r_MTVAL;
                        WHEN X"344" => csr_reg <= r_MIP;
                        WHEN X"C00" => csr_reg <= r_CYCLE;
                        WHEN X"C80" => csr_reg <= r_CYCLEH;
                        WHEN X"C02" => csr_reg <= r_INSTR;
                        WHEN X"C82" => csr_reg <= r_INSTRH;
                        WHEN X"F11" => csr_reg <= r_MVENDORID;
                        WHEN X"F12" => csr_reg <= r_MARCHID;
                        WHEN X"F13" => csr_reg <= r_MIMPID;
                        WHEN X"F14" => csr_reg <= r_MHARTID;
                        WHEN OTHERS => csr_reg <= r_MTVAL;
                    END CASE;

                    ------------------------------------------------------------------
                WHEN i_SB | i_SH | i_SW | i_LB |
                    i_LH | i_LW | i_LBU | i_LHU =>

                    cycles_count <= T0;
                    is_immediate <= '0';
                    is_req_data1 <= '0';
                    is_req_data2 <= '1';
                    is_req_store <= '1';
                    is_req_alu <= '0';
                    is_req_csr <= '0';
                    is_req_mem <= '1';

                    alu_opcode <= c_NONE;
                    csr_reg <= r_MTVAL;

                    ------------------------------------------------------------------
                WHEN i_BEQ | i_BNE | i_BLT | i_BGE |
                    i_BLTU | i_BGEU =>

                    cycles_count <= T1_0;

                    -- We don't really care about theses since we're on a 3 cycles instruction.
                    is_immediate <= '0';
                    is_req_data1 <= '0';
                    is_req_data2 <= '0';
                    is_req_store <= '0';
                    is_req_alu <= '0';
                    is_req_csr <= '0';
                    is_req_mem <= '0';

                    alu_opcode <= c_NONE;
                    csr_reg <= r_MTVAL;

                    ------------------------------------------------------------------
                WHEN i_JAL | i_JALR | i_ECALL | i_EBREAK =>

                    cycles_count <= T1_0;

                    -- We don't really care about theses since we're on a 2 cycles instruction.
                    is_immediate <= '0';
                    is_req_data1 <= '0';
                    is_req_data2 <= '0';
                    is_req_store <= '0';
                    is_req_alu <= '0';
                    is_req_csr <= '0';
                    is_req_mem <= '0';

                    alu_opcode <= c_NONE;
                    csr_reg <= r_MTVAL;

                    ------------------------------------------------------------------
                WHEN i_MRET =>

                    -- We don't really care about theses since we're on a 2 cycles instruction.
                    is_immediate <= '0';
                    is_req_data1 <= '0';
                    is_req_data2 <= '0';
                    is_req_store <= '0';
                    is_req_alu <= '0';
                    is_req_csr <= '0';
                    is_req_mem <= '0';

                    alu_opcode <= c_NONE;
                    csr_reg <= r_MTVAL;

                    -- Reset from instruction.
                    irq_err <= '0';

            END CASE;

            -- Update the case to the next cycle, and selectively disable the program counter, if needed.
        ELSE

            CASE r2_cycles_count IS
                    -- T1_x
                WHEN T1_0 => cycles_count <= T1_1;
                    -- T4_x
                WHEN T4_0 => cycles_count <= T4_1;
                WHEN T4_1 => cycles_count <= T4_2;
                WHEN T4_2 => cycles_count <= T4_3;
                    -- WHEN T4_3 => cycles_count <= T4_4; -- We don't need that much cycle to handle the TRAP.

                    -- Default to make quartus happy (but, we'll never get here since the if ... else)
                WHEN OTHERS => cycles_count <= T0;

            END CASE;

        END IF;

    END PROCESS;

    --=========================================================================
    --! @brief In this third process, we register the output of the first 
    --! combinational stage, to fix them for the later stages.
    --! @details
    --! Splitting the control in two enable us to get higher clock frequencies,
    --! due to the critical path size reductions.
    --=========================================================================
    P3 : PROCESS (nRST, clock)
    BEGIN
        IF (nRST = '0') THEN

            r2_dec_rs1 <= (OTHERS => '0');
            r2_dec_rs2 <= (OTHERS => '0');
            r2_dec_rd <= (OTHERS => '0');
            r2_dec_imm <= (OTHERS => '0');
            r2_dec_opcode <= i_NOP;
            r2_dec_illegal <= '0';
            r2_mem_addrerr <= '0';
            r2_pc_value <= (OTHERS => '0');
            r2_pc_overflow <= '0';
            r2_if_err <= '0';
            r2_ctl_exception <= '0';
            r2_ctl_halt <= '0';
            r2_cycles_count <= T0;
            r2_csr_mip <= '0';

            r2_is_immediate <= '0';
            r2_is_req_data1 <= '0';
            r2_is_req_data2 <= '0';
            r2_is_req_store <= '0';
            r2_is_req_alu <= '0';
            r2_is_req_csr <= '0';
            r2_is_req_mem <= '0';

            r2_alu_opcode <= c_NONE;
            r2_reg_csr <= r_MTVAL;

            r2_csr_rs1_in <= (OTHERS => '0');

        ELSIF rising_edge(clock) AND (clock_en = '1') THEN

            r2_dec_rs1 <= r1_dec_rs1;
            r2_dec_rs2 <= r1_dec_rs2;
            r2_dec_rd <= r1_dec_rd;
            r2_dec_imm <= r1_dec_imm;
            r2_dec_opcode <= r1_dec_opcode;

            r2_dec_illegal <= r1_dec_illegal;
            r2_mem_addrerr <= r1_mem_addrerr;
            r2_pc_value <= r1_pc_value;
            r2_pc_overflow <= r1_pc_overflow;
            r2_if_err <= r1_if_err;
            r2_ctl_exception <= r1_ctl_exception;
            r2_ctl_halt <= r1_ctl_halt;

            r2_cycles_count <= cycles_count;
            r2_is_immediate <= is_immediate;
            r2_is_req_data1 <= is_req_data1;
            r2_is_req_data2 <= is_req_data2;
            r2_is_req_store <= is_req_store;
            r2_is_req_alu <= is_req_alu;
            r2_is_req_csr <= is_req_csr;
            r2_is_req_mem <= is_req_mem;

            r2_alu_opcode <= alu_opcode;
            r2_reg_csr <= csr_reg;

            r2_csr_mip <= r1_csr_mip;
            r2_csr_rs1_in <= r1_csr_rs1_in;

        END IF;

    END PROCESS;

    --=========================================================================
    --! @brief This fourth process generate the control signals, depending on
    --! the actual state and the actual opcode.
    --=========================================================================
    P4 : PROCESS (nRST, r2_dec_rs1, r2_dec_rs2, r2_dec_rd,
        r2_dec_imm, r2_dec_opcode, r2_pc_value, r2_dec_illegal,
        r2_mem_addrerr, r2_pc_overflow, r2_if_err, r2_alu_opcode,
        r2_ctl_exception, r2_ctl_halt, r2_cycles_count, r2_is_immediate,
        r2_is_req_data1, r2_is_req_data2, r2_is_req_store, r2_is_req_alu,
        r2_is_req_csr, r2_is_req_mem, r2_reg_csr)

    BEGIN

        IF (nRST = '0') THEN

            mem_addr <= (OTHERS => '0');
            mem_byteen <= (OTHERS => '1');
            mem_we <= '0';
            mem_req <= '0';
            pc_wren <= '0';
            pc_loadvalue <= (OTHERS => '0');
            reg_we <= '0';
            reg_wa <= 0;
            reg_ra1 <= 0;
            reg_ra2 <= 0;
            reg_rs2_out <= (OTHERS => '0');
            csr_we <= '0';
            csr_wa <= r_MTVAL;
            csr_ra1 <= r_MTVAL;
            arg1_sel <= '0';
            arg2_sel <= '0';
            alu_cmd <= c_NONE;
            excep_occured <= '0';
            core_halt <= '0';
            dec_reset <= '1'; -- by default, enable the decoder reset.
            r1_flush_needed <= '0'; -- Do not flush the r1 registers.
            if_aclr <= '0'; -- Do not clear the output buffers.

        ELSE

            -----------------------------------------------------------
            -- RESETTING THE FSM INTO IT'S DEFAULT STATE
            -----------------------------------------------------------

            -- Stop the program counter from loading value. This enable faster jumps
            -- by saving one CPU cycle, since the pc_wren is set on the latest branch / jump cycle.
            pc_wren <= '0';

            -- Stop the reset of the decoder
            dec_reset <= '1';

            -- Enabling memory output registers.
            -- A reset for two cycles is required, otherwise the first reading would anyway be wrong.
            -- Failing to do that insert a wrong instruction right after a jump.
            if_aclr <= '0';

            -- Preventing from flushing the internal registers of the FSM.
            r1_flush_needed <= '0';

            -- This won't effect the jumps instruction, since theses signals are affected once the processs
            -- has completed. Thus, when we need to overwrite them, they will.

            CASE r2_cycles_count IS

                    -----------------------------------------------------------
                    -- STANDARDS INSTRUCTIONS
                    -----------------------------------------------------------
                WHEN T0 =>

                    -- Apply the outputs depending on the previous computed requirements.
                    IF (r2_is_immediate = '1') THEN
                        arg2_sel <= '1';

                        -- Handle the AUIPC case
                        IF (r2_dec_opcode = i_AUIPC) THEN
                            reg_rs2_out <= STD_LOGIC_VECTOR(signed(r2_pc_value) + signed(r2_dec_imm)); -- Can't use the ALU because
                            -- both would require imm port.
                            -- Thus, we make the addition
                            -- internally.
                        ELSE
                            reg_rs2_out <= r2_dec_imm;
                        END IF;
                    ELSE
                        reg_rs2_out <= (OTHERS => '0');
                    END IF;

                    IF (r2_is_req_data1 = '1') THEN
                        arg1_sel <= '0';
                        reg_ra1 <= to_integer(unsigned(r2_dec_rs1));
                    ELSE
                        reg_ra1 <= 0;
                    END IF;

                    IF (r2_is_req_data2 = '1') THEN
                        arg2_sel <= '0';
                        reg_ra2 <= to_integer(unsigned(r2_dec_rs2));
                    ELSE
                        reg_ra2 <= 0;
                    END IF;

                    IF (r2_is_req_store = '1') THEN
                        mem_req <= '0';
                        reg_we <= '1';
                        csr_we <= '0';
                        reg_wa <= to_integer(unsigned(r2_dec_rd));
                    ELSE
                        reg_we <= '0';
                        reg_wa <= 0;
                    END IF;

                    IF (r2_is_req_alu = '1') THEN
                        alu_cmd <= r2_alu_opcode;
                    ELSE
                        alu_cmd <= c_NONE;
                    END IF;

                    IF (r2_is_req_mem = '1') THEN
                        mem_req <= '1';
                        mem_we <= '1'; -- Need to change that line
                        mem_addr <= (OTHERS => '0'); -- Need to change that line
                        mem_byteen <= (OTHERS => '1'); -- Need to change that line
                    ELSE
                        mem_req <= '0';
                        mem_we <= '0';
                        mem_addr <= (OTHERS => '0');
                        mem_byteen <= (OTHERS => '1');
                    END IF;

                    -----------------------------------------------------------
                    -- JUMPS / CSR / BRANCH instructions
                    -----------------------------------------------------------
                    -- Designer note : The JUMPS instruction could me optimized to fit into a single CPU cycle, 
                    -- but, since we'll anyway flush the pipeline and registered data, we don't really care.
                    -- There will always be a penalty for loading the new pipeline a new time (6 CPU cycles where
                    -- the opcode is NOP.)
                    -- Thus, that's not required for now !

                    -- Second designer note : The BRANCH instruction are assumed as never taken, thus, if possible :
                    -- Write your code as the if condition will evaluate to false. This give cleaner algorithms and,
                    -- betters performances since the core won't need to refill the whole pipeline, costing 6 CPU
                    -- cycles.

                WHEN T1_0 =>

                    -- REPORT "T1_0";

                    CASE r2_dec_opcode IS

                            -----------------------------------------------------------
                            -- Handle JUMPS instructions
                            -----------------------------------------------------------
                        WHEN i_JAL | i_JALR =>

                            -- This first section implement the rd = pc + 4.
                            --
                            -- ADDI, RD, R0, IMM, where R0 is ALWAYS 0 (hardwired).
                            --
                            reg_rs2_out <= STD_LOGIC_VECTOR(unsigned(r1_pc_value) + 4);
                            alu_cmd <= c_ADD;
                            arg2_sel <= '1';
                            arg1_sel <= '0';
                            reg_ra1 <= 0;
                            reg_we <= '1';
                            csr_we <= '0';
                            mem_req <= '0';
                            reg_wa <= to_integer(unsigned(r2_dec_rd));
                            reg_ra2 <= to_integer(unsigned(r2_dec_rs1));

                            -- Reset the decoder, since we're going to jump
                            dec_reset <= '0';
                            r1_flush_needed <= '1';
                            if_aclr <= '1';

                            -----------------------------------------------------------
                            -- BRANCHES
                            -----------------------------------------------------------
                        WHEN i_BEQ | i_BNE | i_BLT | i_BGE | i_BLTU | i_BGEU =>
                            -- Ensure we select both RS1 and RS2.
                            arg1_sel <= '0';
                            arg2_sel <= '0';

                            -- Disables writes
                            reg_we <= '0';
                            csr_we <= '0';
                            reg_wa <= 0;

                            -- Select registers
                            reg_ra1 <= to_integer(unsigned(r2_dec_rs1));
                            reg_ra2 <= to_integer(unsigned(r2_dec_rs2));

                            -- Configure ALU
                            alu_cmd <= c_NONE;

                            -- Disable unwanted logic
                            mem_req <= '0';

                            -----------------------------------------------------------
                            -- Handle CSRR instructions.
                            -----------------------------------------------------------
                        WHEN OTHERS =>

                            -- First, handle the copy of CSR into the RD register
                            -- To do this, we simulate this instruction : 
                            --
                            -- ADDI, RD, R0, IMM, where R0 is ALWAYS 0 (hardwired).
                            --
                            arg1_sel <= '1';
                            reg_rs2_out <= (OTHERS => '0'); -- Doing this enable the read-back of ra2 for step 2, ra2 which would be used by x0.
                            arg2_sel <= '1';
                            reg_we <= '1';
                            reg_wa <= to_integer(unsigned(r1_dec_rd));
                            alu_cmd <= c_ADD;
                            csr_ra1 <= csr_reg;
                            mem_req <= '0';

                            -- The the meanwhile, read back the ra2 value for the next step
                            -- The value will be stored into the rs3_reg_rs1_in signal.
                            reg_ra2 <= to_integer(unsigned(r1_dec_rs1));
                            reg_ra1 <= 0;

                    END CASE;

                WHEN T1_1 =>

                    -- REPORT "T1_1";

                    CASE r3_dec_opcode IS

                        WHEN i_JAL | i_JALR =>

                            -- Basically reset the global 
                            reg_rs2_out <= (OTHERS => '0');
                            alu_cmd <= c_NONE;
                            arg2_sel <= '0';
                            arg1_sel <= '0';
                            reg_ra1 <= 0;
                            reg_ra2 <= 0;
                            reg_we <= '0';
                            csr_we <= '0';
                            reg_wa <= 0;
                            mem_req <= '0';

                            -- This second section implement the proper jump logic for the PC value.
                            -- Thus, it depends from the called instruction.

                            IF (r3_dec_opcode = i_JAL) THEN

                                pc_loadvalue <= STD_LOGIC_VECTOR(signed(r3_pc_value) + signed(r3_dec_imm));

                            ELSIF (r3_dec_opcode = i_JALR) THEN

                                pc_loadvalue <= STD_LOGIC_VECTOR(signed(r3_reg_rs1_in) + signed(r3_dec_imm));

                            END IF;

                            -- Finally, ask the program counter to jump to the new address
                            -- Since the loading is done on the next cycle, we'll be computing the address next
                            pc_wren <= '1';

                            -- Resetting the decoder when we took a branch 
                            dec_reset <= '0';

                            -- Re-enabling decoder operation.
                            r1_flush_needed <= '0';

                            -----------------------------------------------------------
                            -- BRANCHES
                            -----------------------------------------------------------
                        WHEN i_BEQ | i_BNE | i_BLT | i_BGE | i_BLTU | i_BGEU =>

                            -- Clears
                            reg_ra1 <= 0;
                            reg_ra2 <= 0;

                            -- Deciding if we need to jump
                            IF ((r3_dec_opcode = i_BEQ) AND (r3_alu_status.beq = '1')) OR
                                ((r3_dec_opcode = i_BNE) AND (r3_alu_status.bne = '1')) OR
                                ((r3_dec_opcode = i_BLT) AND (r3_alu_status.blt = '1')) OR
                                ((r3_dec_opcode = i_BGE) AND (r3_alu_status.bge = '1')) OR
                                ((r3_dec_opcode = i_BLTU) AND (r3_alu_status.bltu = '1')) OR
                                ((r3_dec_opcode = i_BGEU) AND (r3_alu_status.bgeu = '1')) THEN

                                -- Taking the jump
                                pc_loadvalue <= STD_LOGIC_VECTOR(signed(r3_pc_value) + signed(r3_dec_imm));

                                -- Finally, ask the program counter to jump to the new address
                                -- Since the loading is done on the next cycle, we'll be computing the address next
                                pc_wren <= '1';

                                -- Reset the decoder to ensure no unwanted instructions are going to be executed :
                                dec_reset <= '0';

                                -- Ensure we flush the internal buffers of the core controller.
                                r1_flush_needed <= '1';

                            END IF;

                        WHEN OTHERS =>

                            -- First, define global signals to store the future result into the CSR register file
                            csr_we <= '1';
                            reg_we <= '0';
                            csr_wa <= r2_reg_csr;
                            csr_ra1 <= r2_reg_csr;
                            reg_ra1 <= 0;
                            arg2_sel <= '1';
                            mem_req <= '0';

                            -- Some logic is shared by the two static assignments
                            --
                            -- Note : the 5 bit immediate, to to parsing method used return the 5 bit immediate
                            -- into the RS1 target, thus why we assign it to the output.
                            IF (r3_dec_opcode = i_CSRRW) THEN
                                alu_cmd <= c_ADD;
                                arg1_sel <= '0';
                                reg_rs2_out <= reg_rs1_in;

                            ELSIF (r3_dec_opcode = i_CSRRWI) THEN
                                alu_cmd <= c_ADD;
                                arg1_sel <= '0';
                                reg_rs2_out <= (OTHERS => '0');
                                reg_rs2_out(4 DOWNTO 0) <= r2_dec_rs1;

                            ELSIF (r3_dec_opcode = i_CSRRS) THEN
                                alu_cmd <= c_OR;
                                arg1_sel <= '1';
                                reg_rs2_out <= reg_rs1_in;

                            ELSIF (r3_dec_opcode = i_CSRRSI) THEN
                                alu_cmd <= c_OR;
                                arg1_sel <= '1';
                                reg_rs2_out <= (OTHERS => '0');
                                reg_rs2_out(4 DOWNTO 0) <= r2_dec_rs1;

                            ELSIF (r3_dec_opcode = i_CSRRC) THEN
                                alu_cmd <= c_AND;
                                arg1_sel <= '1';
                                reg_rs2_out <= NOT reg_rs1_in;

                            ELSIF (r3_dec_opcode = i_CSRRCI) THEN
                                alu_cmd <= c_AND;
                                arg1_sel <= '1';
                                reg_rs2_out <= (OTHERS => '1');
                                reg_rs2_out(4 DOWNTO 0) <= NOT r2_dec_rs1;

                            END IF;

                    END CASE;

                    -----------------------------------------------------------
                    -- IRQ / ERR HANDLING
                    -----------------------------------------------------------
                WHEN T4_0 =>

                    -- First, write MEPC with the current PC value.
                    mem_req <= '0';

                    -- enable writes on the CSR register file, and select the correct one
                    csr_we <= '1';
                    reg_we <= '0';
                    csr_wa <= r_MEPC;
                    csr_ra1 <= r_MSTATUS; -- Read MSTATUS to mask the corrects bits.
                    reg_ra1 <= 0;
                    reg_ra2 <= 0;

                    -- output the CURRENT PC value to the immediate port
                    reg_rs2_out <= r3_pc_value;

                    -- Select the data path
                    arg2_sel <= '1';
                    arg1_sel <= '0';
                    alu_cmd <= c_ADD;

                WHEN T4_1 =>

                    -- First, update the MCAUSE value with the right one : 
                    csr_we <= '1';
                    reg_we <= '0';
                    csr_wa <= r_MCAUSE;
                    csr_ra1 <= r_MTVEC;
                    reg_ra1 <= 0;
                    reg_ra1 <= 0;

                    -- Configuring data path
                    arg2_sel <= '1';
                    arg1_sel <= '0';
                    alu_cmd <= c_ADD;

                    -- Output the right value, depending on some causes :
                    IF (r3_dec_illegal = '1') THEN
                        reg_rs2_out <= X"00000002";
                    ELSIF (r3_mem_addrerr = '1') THEN
                        reg_rs2_out <= X"00000010";
                    ELSIF (r3_pc_overflow = '1') THEN
                        reg_rs2_out <= X"00000011";
                    ELSIF (r3_if_err = '1') THEN
                        reg_rs2_out <= X"00000001";
                    ELSIF (r3_ctl_exception = '1') THEN
                        reg_rs2_out <= X"7FFFFFFF"; -- Custom one, externally induced.
                    ELSIF (r3_csr_mip = '1') THEN
                        reg_rs2_out <= X"80000008";
                    END IF;

                WHEN T4_2 =>
                    -- Updating MSTATUS to the new value
                    csr_we <= '1';
                    reg_we <= '0';
                    csr_wa <= r_MSTATUS;
                    csr_ra1 <= r_MTVAL; -- Read jump address
                    reg_ra1 <= 0;
                    reg_ra1 <= 0;

                    -- Configuring data path
                    arg2_sel <= '1';
                    arg1_sel <= '0';
                    alu_cmd <= c_ADD;

                    -- Updating the MIE / MPIE bits into the value
                    reg_rs2_out <= r2_csr_rs1_in; -- Copy MSTATUS
                    reg_rs2_out(7) <= r2_csr_rs1_in(3); -- MIE -> MPIE
                    reg_rs2_out(3) <= '0'; -- MIE ='0' (disable future traps)

                WHEN T4_3 =>
                    -- Jump to the MTVEC value
                    pc_loadvalue <= r2_csr_rs1_in;

                    -- Finally, ask the program counter to jump to the new address
                    -- Since the loading is done on the next cycle, we'll be computing the address next
                    pc_wren <= '1';

                    -- Resetting the decoder when we took a branch 
                    dec_reset <= '0';

                    -- Re-enabling decoder operation.
                    r1_flush_needed <= '0';

                WHEN T4_4 =>
                    REPORT "T4_4";

            END CASE;

        END IF;

    END PROCESS;

    --========================================================================================
    --! @brief Process for the third state registration.
    --========================================================================================
    P10 : PROCESS (nRST, clock)
    BEGIN

        IF (nRST = '0') THEN

            r3_dec_opcode <= i_NOP;
            r3_reg_rs1_in <= (OTHERS => '0');
            r3_pc_value <= (OTHERS => '0');
            r3_dec_imm <= (OTHERS => '0');
            r3_reg_csr <= r_MTVAL;
            r3_cycles_count <= T0;
            r3_alu_status <= (OTHERS => '0');

            r3_csr_mip <= '0';
            r3_mem_addrerr <= '0';
            r3_dec_illegal <= '0';
            r3_pc_overflow <= '0';
            r3_if_err <= '0';
            r3_ctl_exception <= '0';
            r3_ctl_halt <= '0';

        ELSIF rising_edge(clock) AND (clock_en = '1') THEN

            r3_dec_opcode <= r2_dec_opcode;
            r3_pc_value <= r2_pc_value;
            r3_dec_imm <= r2_dec_imm;
            r3_reg_rs1_in <= reg_rs1_in;
            r3_reg_csr <= r2_reg_csr;
            r3_cycles_count <= r2_cycles_count;
            r3_alu_status <= alu_status;

            r3_csr_mip <= r2_csr_mip;
            r3_mem_addrerr <= r2_mem_addrerr;
            r3_dec_illegal <= r2_dec_illegal;
            r3_pc_overflow <= r2_pc_overflow;
            r3_if_err <= r2_if_err;
            r3_ctl_exception <= r2_ctl_exception;
            r3_ctl_halt <= r2_ctl_halt;

        END IF;

    END PROCESS;

    --========================================================================================
    --! @brief Process for registration of the fourth stages.
    --========================================================================================
    P11 : PROCESS (nRST, clock)
    BEGIN

        IF (nRST = '0') THEN

            r4_dec_opcode <= i_NOP;

        ELSIF rising_edge(clock) AND (clock_en = '1') THEN

            r4_dec_opcode <= r3_dec_opcode;

        END IF;

    END PROCESS;

    --========================================================================================
    --! @brief Process for registration of the fifth stages.
    --========================================================================================
    P12 : PROCESS (nRST, clock)
    BEGIN

        IF (nRST = '0') THEN

            r5_dec_opcode <= i_NOP;

        ELSIF rising_edge(clock) AND (clock_en = '1') THEN

            r5_dec_opcode <= r4_dec_opcode;

        END IF;

    END PROCESS;

    --========================================================================================
    --! @brief Process for registration of the sixth stages.
    --========================================================================================
    P13 : PROCESS (nRST, clock)
    BEGIN

        IF (nRST = '0') THEN

            r6_dec_opcode <= i_NOP;

        ELSIF rising_edge(clock) AND (clock_en = '1') THEN

            r6_dec_opcode <= r5_dec_opcode;

        END IF;

    END PROCESS;

    --========================================================================================
    -- END OF FILE
    --========================================================================================

END ARCHITECTURE;