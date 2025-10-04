LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE work.common.ALL;
USE work.records.ALL;

ENTITY core_controller IS
    GENERIC (
        -- Size generic values :
        XLEN : INTEGER := 32; -- Number of bits stored by the register. 
        REG_NB : INTEGER := 32; -- Number of registers in the processor.
        CSR_NB : INTEGER := 9; -- Number of used CSR registers. WARNING : This part is not fully spec compliant, in the 
        -- meaning that the address of the register is not correct. There's logically some "space"
        -- between them, that we ignore. We reuse the same register_file as generic regs, and the
        -- data is thus joined under the same structure. The controller handle that difference.

        -- Handler exceptions : 
        INT_ADDR : INTEGER := 0; -- Address of the interrupt handler to jump.
        EXP_ADDR : INTEGER := 0 -- Address of the exception handler to jump.
    );
    PORT (
        -- General inputs : 
        clock : IN STD_LOGIC; -- Global core clock.
        clock_en : IN STD_LOGIC;
        nRST : IN STD_LOGIC; -- System reset

        -- Decoder signals : 
        dec_rs1 : IN STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0); -- Register selection 1
        dec_rs2 : IN STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0); -- Register selection 2
        dec_rd : IN STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0); -- Register selection for write
        dec_imm : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0); -- Immediate value, already signed extended
        dec_opcode : IN instructions; -- Opcode, custom type
        dec_illegal : IN STD_LOGIC; -- Illegal instruction exception handler
        dec_reset : OUT STD_LOGIC; -- Decoder reset force. Used to flush the buffer when jumping.

        -- Memory signals : 
        mem_addr : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := (OTHERS => '0'); -- Memory address
        mem_byteen : OUT STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '1'); -- Memory byte selection
        mem_we : OUT STD_LOGIC := '0'; -- Memory write order (1 = write)
        mem_req : OUT STD_LOGIC := '0';
        mem_addrerr : IN STD_LOGIC; -- Incorrect memory address.

        -- Program counter signals : 
        pc_value : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0); -- Readback of the PC value
        pc_overflow : IN STD_LOGIC; -- Overflow status of the PC.
        pc_enable : OUT STD_LOGIC := '1'; -- Enable of the PC counter
        pc_wren : OUT STD_LOGIC := '0'; -- Load a new value on the program counter
        pc_loadvalue : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := (OTHERS => '0'); -- Value to be loaded on the program counter

        -- Regs selection : 
        reg_we : OUT STD_LOGIC := '0'; -- Write enable of the register file
        reg_wa : OUT INTEGER RANGE 0 TO (REG_NB - 1) := 0; -- Written register.
        reg_ra1 : OUT INTEGER RANGE 0 TO (REG_NB - 1) := 0; -- Output register 1.
        reg_ra2 : OUT INTEGER RANGE 0 TO (REG_NB - 1) := 0; -- Output register 2.
        reg_rs1_in : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0); -- Register rs1 input signal
        reg_rs2_out : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := (OTHERS => '0'); -- Forced output for an argument

        -- CSR regs controls
        csr_we : OUT STD_LOGIC := '0'; -- CSR write enable of the register file
        csr_wa : OUT csr_register := r_MTVAL; -- Written CSR register address
        csr_ra1 : OUT csr_register := r_MTVAL; -- Readen CSR register address 
        -- There's no CSR RA2 because we'll never need the second output port
        csr_mie : IN STD_LOGIC; -- Mie bit status
        csr_mip : IN STD_LOGIC; -- MIP bit status

        -- Regs muxes
        arg1_sel : OUT STD_LOGIC := '0'; -- Choose between the output of the CSR register file or the RS1 output of the register file
        arg2_sel : OUT STD_LOGIC := '0'; -- Choose between the output of the controller or the RS2 output of the register file

        -- Alu controls
        alu_cmd : OUT commands := c_ADD; -- ALU controls signals
        alu_status : IN alu_feedback; -- Alu feedback signals for jumps and other statuses.

        -- Instruction fetch register clear signal
        if_aclr : OUT STD_LOGIC := '0'; -- ACLR for the two M9K memories IP (ROM and RAM).

        -- Generics inputs :
        if_err : IN STD_LOGIC;
        ctl_exception : IN STD_LOGIC; -- Generic exception handler
        ctl_halt : IN STD_LOGIC;

        -- Generics outputs :
        excep_occured : OUT STD_LOGIC := '0'; -- Generic flag to signal an exception occured (LED ?)
        core_halt : OUT STD_LOGIC := '0' -- Generic output if core is halted.
    );
END ENTITY;

ARCHITECTURE behavioral OF core_controller IS

    -- Custom type definition
    TYPE FSM_states IS (
        T0,
        T1_0, T1_1,
        T2_0, T2_1, T2_2,
        T4_0, T4_1, T4_2, T4_3, T4_4
    );

    -- Static logic for making jumps really jumps
    SIGNAL r1_flush_needed : STD_LOGIC;

    -- PC Value registration
    SIGNAL r01_pc_value : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL r02_pc_value : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL r03_pc_value : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL r04_pc_value : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL r05_pc_value : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

    -- registered signals for stage 1
    SIGNAL r1_dec_rs1 : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    SIGNAL r1_dec_rs2 : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    SIGNAL r1_dec_rd : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    SIGNAL r1_dec_imm : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL r1_dec_opcode : instructions;

    SIGNAL r1_mem_addrerr : STD_LOGIC;
    SIGNAL r1_dec_illegal : STD_LOGIC;
    SIGNAL r1_pc_overflow : STD_LOGIC;
    SIGNAL r1_if_err : STD_LOGIC;
    SIGNAL r1_ctl_exception : STD_LOGIC;
    SIGNAL r1_ctl_halt : STD_LOGIC;
    SIGNAL r1_csr_mie : STD_LOGIC;
    SIGNAL r1_csr_mip : STD_LOGIC;

    SIGNAL r1_pc_value : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

    -- Combinational output signals.
    SIGNAL cycles_count : FSM_states; -- Show how many cycles will be needed for this instruction.
    SIGNAL is_immediate : STD_LOGIC;
    SIGNAL is_req_data1 : STD_LOGIC;
    SIGNAL is_req_data2 : STD_LOGIC;
    SIGNAL is_req_store : STD_LOGIC;
    SIGNAL is_req_alu : STD_LOGIC;
    SIGNAL is_req_csr : STD_LOGIC;
    SIGNAL is_req_mem : STD_LOGIC;
    SIGNAL alu_opcode : commands;
    SIGNAL irq_err : STD_LOGIC;
    SIGNAL csr_reg : csr_register;

    -- Registered signals for stage 2 (r1 + new signals!)
    SIGNAL r2_dec_rs1 : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    SIGNAL r2_dec_rs2 : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    SIGNAL r2_dec_rd : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    SIGNAL r2_dec_imm : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL r2_dec_opcode : instructions;
    SIGNAL r2_mem_addrerr : STD_LOGIC;
    SIGNAL r2_dec_illegal : STD_LOGIC;
    SIGNAL r2_pc_value : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL r2_pc_overflow : STD_LOGIC;
    SIGNAL r2_if_err : STD_LOGIC;
    SIGNAL r2_ctl_exception : STD_LOGIC;
    SIGNAL r2_ctl_halt : STD_LOGIC;
    SIGNAL r2_cycles_count : FSM_states;
    SIGNAL r2_is_immediate : STD_LOGIC;
    SIGNAL r2_is_req_data1 : STD_LOGIC;
    SIGNAL r2_is_req_data2 : STD_LOGIC;
    SIGNAL r2_is_req_store : STD_LOGIC;
    SIGNAL r2_is_req_alu : STD_LOGIC;
    SIGNAL r2_is_req_csr : STD_LOGIC;
    SIGNAL r2_is_req_mem : STD_LOGIC;
    SIGNAL r2_alu_opcode : commands;
    SIGNAL r2_reg_csr : csr_register;

    -- Registered signals for later stages.
    -- Since theses only concern the instructions that require more than one cycle,
    -- all of the data may not be needed.
    SIGNAL r3_dec_opcode : instructions;
    SIGNAL r4_dec_opcode : instructions;
    SIGNAL r5_dec_opcode : instructions;
    SIGNAL r6_dec_opcode : instructions;

    SIGNAL r3_reg_rs1_in : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL r3_pc_value : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL r3_dec_imm : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL r3_reg_csr : csr_register;

    SIGNAL r3_cycles_count : FSM_states;

BEGIN

    --=========================================================================
    -- Due to the decoder latency, we need to register 3 mores times the
    -- program counter value.
    -- Otherwise, an offset would occur when jumping.
    --=========================================================================
    P0 : PROCESS (clock, nRST)
    BEGIN
        IF (nRST = '0') THEN

            r01_pc_value <= (OTHERS => '0');
            r02_pc_value <= (OTHERS => '0');
            r03_pc_value <= (OTHERS => '0');
            r04_pc_value <= (OTHERS => '0');
            r05_pc_value <= (OTHERS => '0');

        ELSIF rising_edge(clock) AND (clock_en = '1') THEN

            r01_pc_value <= pc_value;
            r02_pc_value <= r01_pc_value;
            r03_pc_value <= r02_pc_value;
            r04_pc_value <= r03_pc_value;
            r05_pc_value <= r04_pc_value;

        END IF;

    END PROCESS;

    --=========================================================================
    -- Registering the signals on each cycle. This ensure stability
    -- and higher performance (way higher clock frequency is possible)
    -- May be flushed if a branch is taken to prevent the execution of
    -- unwanted instructions.
    --=========================================================================
    P1 : PROCESS (clock, nRST, r1_flush_needed)
    BEGIN
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

            r1_csr_mip <= '0';
            r1_csr_mie <= '0';

        ELSIF rising_edge(clock) AND (clock_en = '1') THEN
            r1_dec_rs1 <= dec_rs1;
            r1_dec_rs2 <= dec_rs2;
            r1_dec_rd <= dec_rd;
            r1_dec_imm <= dec_imm;
            r1_dec_opcode <= dec_opcode;

            -- r1_pc_value         <=  pc_value;
            r1_pc_value <= r04_pc_value;

            r1_dec_illegal <= dec_illegal;
            r1_mem_addrerr <= mem_addrerr;
            r1_pc_overflow <= pc_overflow;
            r1_if_err <= if_err;
            r1_ctl_exception <= ctl_exception;
            r1_ctl_halt <= ctl_halt;

            r1_csr_mip <= csr_mip;
            r1_csr_mie <= csr_mie;

        END IF;

    END PROCESS;

    --=========================================================================
    -- Analyzing status, and creating requirement signals for the specified instruction.
    -- This will be used on the second combinational part, for the more advanced IOs.
    --
    -- We're forced to make the process sensitive to a bunch of signals to ensure
    -- it WILL react to any new instructions.
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
            (r1_if_err = '1') OR (r1_ctl_exception = '1') OR (r1_ctl_halt = '1') OR
            (r1_csr_mip = '1') THEN

            -- Check if we're already interrupting, and if we have the right to do it...
            IF (irq_err = '0') AND (r1_csr_mie = '1') THEN

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
        ELSIF (r2_cycles_count = T0) OR (r2_cycles_count = T1_1) OR (r2_cycles_count = T2_2) OR
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
                        WHEN i_ADDI | i_LUI =>
                            alu_opcode <= c_ADD;
                        WHEN i_SLTI =>
                            alu_opcode <= c_SLT;
                        WHEN i_SLTIU =>
                            alu_opcode <= c_SLTU;
                        WHEN i_XORI =>
                            alu_opcode <= c_XOR;
                        WHEN i_ANDI =>
                            alu_opcode <= c_AND;
                        WHEN i_SLLI =>
                            alu_opcode <= c_SLL;
                        WHEN i_SRLI =>
                            alu_opcode <= c_SRL;
                        WHEN i_SRAI =>
                            alu_opcode <= c_SRA;
                        WHEN i_ORI | i_AUIPC => -- Rd = imm | 0x00 result in imm for i_AUIPC
                            alu_opcode <= c_OR;
                            -- useless case, already covered, but otherwise design won't compile
                        WHEN OTHERS =>
                            alu_opcode <= c_NONE;
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
                        WHEN i_ADD =>
                            alu_opcode <= c_ADD;
                        WHEN i_SUB =>
                            alu_opcode <= c_SUB;
                        WHEN i_SLT =>
                            alu_opcode <= c_SLT;
                        WHEN i_SLTU =>
                            alu_opcode <= c_SLTU;
                        WHEN i_XOR =>
                            alu_opcode <= c_XOR;
                        WHEN i_AND =>
                            alu_opcode <= c_AND;
                        WHEN i_SLL =>
                            alu_opcode <= c_SLL;
                        WHEN i_SRL =>
                            alu_opcode <= c_SRL;
                        WHEN i_SRA =>
                            alu_opcode <= c_SRA;
                        WHEN i_OR =>
                            alu_opcode <= c_OR;
                            -- useless case, already covered, but otherwise design won't compile
                        WHEN OTHERS =>
                            alu_opcode <= c_NONE;
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
                        WHEN X"300" =>
                            csr_reg <= r_MSTATUS;
                        WHEN X"301" =>
                            csr_reg <= r_MISA;
                        WHEN X"304" =>
                            csr_reg <= r_MIE;
                        WHEN X"305" =>
                            csr_reg <= r_MTVEC;
                        WHEN X"340" =>
                            csr_reg <= r_MSCRATCH;
                        WHEN X"341" =>
                            csr_reg <= r_MEPC;
                        WHEN X"342" =>
                            csr_reg <= r_MCAUSE;
                        WHEN X"343" =>
                            csr_reg <= r_MTVAL;
                        WHEN X"344" =>
                            csr_reg <= r_MIP;
                        WHEN OTHERS =>
                            csr_reg <= r_MTVAL;
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

                    cycles_count <= T2_0;

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
                WHEN i_JAL | i_JALR | i_ECALL | i_EBREAK |
                    i_MRET =>

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

                    -- If we took an special handler route, unlock the future interrupts.
                    IF (r1_dec_opcode = i_MRET) THEN
                        irq_err <= '0';
                    END IF;

            END CASE;

            -- Update the case to the next cycle, and selectively disable the program counter, if needed.
        ELSE

            CASE r2_cycles_count IS
                    -- T1_x
                WHEN T1_0 =>
                    cycles_count <= T1_1;

                    -- T2_x
                WHEN T2_0 =>
                    cycles_count <= T2_1;
                WHEN T2_1 =>
                    cycles_count <= T2_2;

                    -- T4_x
                WHEN T4_0 =>
                    cycles_count <= T4_1;
                WHEN T4_1 =>
                    cycles_count <= T4_2;
                WHEN T4_2 =>
                    cycles_count <= T4_3;
                WHEN T4_3 =>
                    cycles_count <= T4_4;

                    -- Default to make quartus happy (but, we'll never get here since the if ... else)
                WHEN OTHERS =>
                    cycles_count <= T0;

            END CASE;

        END IF;

    END PROCESS;

    --=========================================================================
    -- Registering the signals on each cycle. This ensure stability
    -- and higher performance (way higher clock frequency is possible)
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

            r2_is_immediate <= '0';
            r2_is_req_data1 <= '0';
            r2_is_req_data2 <= '0';
            r2_is_req_store <= '0';
            r2_is_req_alu <= '0';
            r2_is_req_csr <= '0';
            r2_is_req_mem <= '0';

            r2_alu_opcode <= c_NONE;
            r2_reg_csr <= r_MTVAL;

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

        END IF;

    END PROCESS;

    --=========================================================================
    -- Second combinational process, it output the control signals according the right
    -- parsed signals.
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

            CASE r2_cycles_count IS
                    -----------------------------------------------------------
                    -- STANDARDS INSTRUCTIONS
                    -----------------------------------------------------------
                WHEN T0 =>

                    -- Stop the program counter from loading value. This enable faster jumps
                    -- by saving one CPU cycle, since the pc_wren is set on the latest branch / jump cycle.
                    pc_wren <= '0';

                    -- Enabling memory output registers.
                    -- A reset for two cycles is required, otherwise the first reading would anyway be wrong.
                    -- Failing to do that insert a wrong instruction right after a jump.
                    if_aclr <= '0';

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
                    -- JUMPS / CSR instructions
                    -----------------------------------------------------------
                WHEN T1_0 =>

                    CASE r2_dec_opcode IS

                            -----------------------------------------------------------
                            -- Handle JUMPS instructions
                            -----------------------------------------------------------
                        WHEN i_JAL | i_JALR =>

                            -- This first section implement the rd = pc + 4.
                            -- We only need to copy the **next** program counter value, already incremented by four,
                            -- into RD. To do this, we simulate this instruction : 
                            --
                            -- ADDI, RD, R0, IMM, where R0 is ALWAYS 0 (hardwired).
                            --
                            reg_rs2_out <= r1_pc_value;
                            alu_cmd <= c_ADD;
                            arg2_sel <= '1';
                            arg1_sel <= '0';
                            reg_ra1 <= 0;
                            reg_we <= '1';
                            csr_we <= '0';
                            reg_wa <= to_integer(unsigned(r2_dec_rd));
                            reg_ra2 <= to_integer(unsigned(r2_dec_rs1));

                            -- Reset the decoder, since we're going to jump
                            dec_reset <= '0';
                            r1_flush_needed <= '1';
                            if_aclr <= '1';

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
                            csr_wa <= r_MTVAL;
                            csr_ra1 <= csr_reg;

                            -- The the meanwhile, read back the ra2 value for the next step
                            -- The value will be stored into the rs3_reg_rs1_in signal.
                            reg_ra2 <= to_integer(unsigned(r1_dec_rs1));
                            reg_ra1 <= 0;

                    END CASE;

                WHEN T1_1 =>

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

                            -- Re-enabling decoder operation.
                            dec_reset <= '1';
                            r1_flush_needed <= '0';

                        WHEN OTHERS =>

                            -- First, define global signals to store the future result into the CSR register file
                            csr_we <= '1';
                            reg_we <= '0';
                            csr_wa <= r2_reg_csr;
                            csr_ra1 <= r2_reg_csr;
                            reg_ra1 <= 0;
                            arg2_sel <= '1';

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
                    -- BRANCHES
                    -----------------------------------------------------------
                WHEN T2_0 =>

                WHEN T2_1 =>

                WHEN T2_2 =>

                    -----------------------------------------------------------
                    -- IRQ / ERR HANDLING
                    -----------------------------------------------------------
                WHEN T4_0 =>

                WHEN T4_1 =>

                WHEN T4_2 =>

                WHEN T4_3 =>

                WHEN T4_4 =>

            END CASE;

        END IF;

    END PROCESS;

    --=========================================================================
    -- Registering the signals for the Tx_1 stages
    --=========================================================================
    P10 : PROCESS (nRST, clock)
    BEGIN

        IF (nRST = '0') THEN

            r3_dec_opcode <= i_NOP;
            r3_reg_rs1_in <= (OTHERS => '0');
            r3_pc_value <= (OTHERS => '0');
            r3_dec_imm <= (OTHERS => '0');
            r3_reg_csr <= r_MTVAL;
            r3_cycles_count <= T0;

        ELSIF rising_edge(clock) AND (clock_en = '1') THEN

            r3_dec_opcode <= r2_dec_opcode;
            r3_pc_value <= r2_pc_value;
            r3_dec_imm <= r2_dec_imm;

            r3_reg_rs1_in <= reg_rs1_in;

            r3_reg_csr <= r2_reg_csr;

            r3_cycles_count <= r2_cycles_count;

        END IF;

    END PROCESS;

    --=========================================================================
    -- Register the signals for the Tx_2 stages
    --=========================================================================
    P11 : PROCESS (nRST, clock)
    BEGIN

        IF (nRST = '0') THEN

            r4_dec_opcode <= i_NOP;

        ELSIF rising_edge(clock) AND (clock_en = '1') THEN

            r4_dec_opcode <= r3_dec_opcode;

        END IF;

    END PROCESS;

    --=========================================================================
    -- Register the signals for the Tx_3 stages
    --=========================================================================
    P12 : PROCESS (nRST, clock)
    BEGIN

        IF (nRST = '0') THEN

            r5_dec_opcode <= i_NOP;

        ELSIF rising_edge(clock) AND (clock_en = '1') THEN

            r5_dec_opcode <= r4_dec_opcode;

        END IF;

    END PROCESS;

    --=========================================================================
    -- Register the signals for the Tx_4 stages
    --=========================================================================
    P13 : PROCESS (nRST, clock)
    BEGIN

        IF (nRST = '0') THEN

            r6_dec_opcode <= i_NOP;

        ELSIF rising_edge(clock) AND (clock_en = '1') THEN

            r6_dec_opcode <= r5_dec_opcode;

        END IF;

    END PROCESS;

    --=========================================================================
    -- END OF FILE
    --=========================================================================

END ARCHITECTURE;