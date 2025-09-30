library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.common.all;
use work.records.all;

entity core_controller is 
    generic (
        -- Size generic values :
        XLEN :      integer := 32;                                                                  -- Number of bits stored by the register. 
        REG_NB :    integer := 32;                                                                  -- Number of registers in the processor.
        CSR_NB :    integer := 9;                                                                   -- Number of used CSR registers. WARNING : This part is not fully spec compliant, in the 
                                                                                                    -- meaning that the address of the register is not correct. There's logically some "space"
                                                                                                    -- between them, that we ignore. We reuse the same register_file as generic regs, and the
                                                                                                    -- data is thus joined under the same structure. The controller handle that difference.

        -- Handler exceptions : 
        INT_ADDR :  integer := 0;                                                                   -- Address of the interrupt handler to jump.
        EXP_ADDR :  integer := 0                                                                    -- Address of the exception handler to jump.
    );
    port (
        -- General inputs : 
        clock :         in      std_logic;                                                          -- Global core clock.
        clock_en :      in      std_logic;
        nRST :          in      std_logic;                                                          -- System reset
        
        -- Decoder signals : 
        dec_rs1 :       in      std_logic_vector((XLEN / 8) downto 0);                              -- Register selection 1
        dec_rs2 :       in      std_logic_vector((XLEN / 8) downto 0);                              -- Register selection 2
        dec_rd :        in      std_logic_vector((XLEN / 8) downto 0);                              -- Register selection for write
        dec_imm :       in      std_logic_vector((XLEN - 1) downto 0);                              -- Immediate value, already signed extended
        dec_opcode :    in      instructions;                                                       -- Opcode, custom type
        dec_illegal :   in      std_logic;                                                          -- Illegal instruction exception handler
        dec_reset :     out     std_logic;                                                          -- Decoder reset force. Used to flush the buffer when jumping.

        -- Memory signals : 
        mem_addr :      out     std_logic_vector((XLEN - 1) downto 0)       := (others => '0');     -- Memory address
        mem_byteen :    out     std_logic_vector(3 downto 0)                := (others => '1');     -- Memory byte selection
        mem_we :        out     std_logic                                   := '0';                 -- Memory write order (1 = write)
        mem_req :       out     std_logic                                   := '0';
        mem_addrerr :   in      std_logic;                                                          -- Incorrect memory address.
        
        -- Program counter signals : 
        pc_value :      in      std_logic_vector((XLEN -1) downto 0);                               -- Readback of the PC value
        pc_overflow :   in      std_logic;                                                          -- Overflow status of the PC.
        pc_enable :     out     std_logic                                   := '1';                 -- Enable of the PC counter
        pc_wren :       out     std_logic                                   := '0';                 -- Load a new value on the program counter
        pc_loadvalue :  out     std_logic_vector((XLEN - 1) downto 0)       := (others => '0');     -- Value to be loaded on the program counter

        -- Regs selection : 
        reg_we :        out     std_logic                                   := '0';                 -- Write enable of the register file
        reg_wa :        out     integer range 0 to (REG_NB - 1)             := 0;                   -- Written register.
        reg_ra1 :       out     integer range 0 to (REG_NB - 1)             := 0;                   -- Output register 1.
        reg_ra2 :       out     integer range 0 to (REG_NB - 1)             := 0;                   -- Output register 2.
        reg_rs1_in :    in      std_logic_vector((XLEN - 1) downto 0);                              -- Register rs1 input signal
        reg_rs2_out :   out     std_logic_vector((XLEN - 1) downto 0)       := (others => '0');     -- Forced output for an argument

        -- CSR regs controls
        csr_we :        out     std_logic                                   := '0';                 -- CSR write enable of the register file
        csr_wa :        out     integer range 0 to (CSR_NB - 1)             := 0;                   -- Written CSR register address
        csr_ra1 :       out     integer range 0 to (CSR_NB - 1)             := 0;                   -- Readen CSR register address 
                                                                                                    -- There's no CSR RA2 because we'll never need the second output port
        csr_mie :       in      std_logic;                                                          -- Mie bit status

        -- Regs muxes
        arg1_sel :      out     std_logic                                   := '0';                 -- Choose between the output of the CSR register file or the RS1 output of the register file
        arg2_sel :      out     std_logic                                   := '0';                 -- Choose between the output of the controller or the RS2 output of the register file

        -- Alu controls
        alu_cmd :       out     commands                                    := c_ADD;               -- ALU controls signals
        alu_status :    in      alu_feedback;                                                       -- Alu feedback signals for jumps and other statuses.

        -- Instruction fetch register clear signal
        if_aclr :       out     std_logic                                   := '0';                 -- ACLR for the two M9K memories IP (ROM and RAM).

        -- Generics inputs :
        if_err :        in      std_logic;
        ctl_interrupt : in      std_logic;                                                          -- Interrupt flag
        ctl_exception : in      std_logic;                                                          -- Generic exception handler
        ctl_halt :      in      std_logic;

        -- Generics outputs :
        excep_occured : out     std_logic                                   := '0';                 -- Generic flag to signal an exception occured (LED ?)
        core_halt :     out     std_logic                                   := '0'                  -- Generic output if core is halted.
    );
end entity;

architecture behavioral of core_controller is

        -- Custom type definition
        type FSM_states is (
            T0,
            T1_0, T1_1,
            T2_0, T2_1, T2_2,
            T4_0, T4_1, T4_2, T4_3, T4_4
        );

        -- Static logic for making jumps really jumps
        signal r1_flush_needed :    std_logic;

        -- PC Value registration
        signal r01_pc_value :       std_logic_vector((XLEN - 1) downto 0);
        signal r02_pc_value :       std_logic_vector((XLEN - 1) downto 0);
        signal r03_pc_value :       std_logic_vector((XLEN - 1) downto 0);

        -- registered signals for stage 1
        signal r1_dec_rs1 :         std_logic_vector((XLEN / 8) downto 0);
        signal r1_dec_rs2 :         std_logic_vector((XLEN / 8) downto 0);
        signal r1_dec_rd :          std_logic_vector((XLEN / 8) downto 0);
        signal r1_dec_imm :         std_logic_vector((XLEN - 1) downto 0);
        signal r1_dec_opcode :      instructions;

        signal r1_mem_addrerr :     std_logic;
        signal r1_dec_illegal :     std_logic; 
        signal r1_pc_overflow :     std_logic;
        signal r1_if_err :          std_logic;
        signal r1_ctl_interrupt :   std_logic;
        signal r1_ctl_exception :   std_logic;
        signal r1_ctl_halt :        std_logic;
        signal r1_csr_mie :         std_logic;

        signal r1_pc_value :        std_logic_vector((XLEN - 1) downto 0);

        -- Combinational output signals.
        signal cycles_count :       FSM_states; -- Show how many cycles will be needed for this instruction.
        signal is_immediate :       std_logic;
        signal is_req_data1 :       std_logic;
        signal is_req_data2 :       std_logic;
        signal is_req_store :       std_logic;
        signal is_req_alu :         std_logic;
        signal is_req_csr :         std_logic;
        signal is_req_mem :         std_logic;
        signal alu_opcode :         commands;
        signal irq_err :            std_logic;

        -- Registered signals for stage 2 (r1 + new signals!)
        signal r2_dec_rs1 :         std_logic_vector((XLEN / 8) downto 0);
        signal r2_dec_rs2 :         std_logic_vector((XLEN / 8) downto 0);
        signal r2_dec_rd :          std_logic_vector((XLEN / 8) downto 0);
        signal r2_dec_imm :         std_logic_vector((XLEN - 1) downto 0);
        signal r2_dec_opcode :      instructions;
        signal r2_mem_addrerr :     std_logic;
        signal r2_dec_illegal :     std_logic;
        signal r2_pc_value :        std_logic_vector((XLEN - 1) downto 0);
        signal r2_pc_overflow :     std_logic;
        signal r2_if_err :          std_logic;
        signal r2_ctl_interrupt :   std_logic;
        signal r2_ctl_exception :   std_logic;
        signal r2_ctl_halt :        std_logic;
        signal r2_cycles_count :    FSM_states;
        signal r2_is_immediate :    std_logic;
        signal r2_is_req_data1 :    std_logic;
        signal r2_is_req_data2 :    std_logic;
        signal r2_is_req_store :    std_logic;
        signal r2_is_req_alu :      std_logic;
        signal r2_is_req_csr :      std_logic;
        signal r2_is_req_mem :      std_logic;
        signal r2_alu_opcode :      commands;

        -- Registered signals for later stages.
        -- Since theses only concern the instructions that require more than one cycle,
        -- all of the data may not be needed.
        signal r3_dec_opcode :      instructions;
        signal r4_dec_opcode :      instructions;
        signal r5_dec_opcode :      instructions;
        signal r6_dec_opcode :      instructions;

        signal r3_reg_rs1_in :      std_logic_vector((XLEN - 1) downto 0);
        signal r3_pc_value :        std_logic_vector((XLEN - 1) downto 0);
        signal r3_dec_imm :         std_logic_vector((XLEN - 1) downto 0);

    begin

        --=========================================================================
        -- Due to the decoder latency, we need to register 3 mores times the
        -- program counter value.
        -- Otherwise, an offset would occur when jumping.
        --=========================================================================
        P0 : process(clock, nRST)
        begin
            if (nRST = '0') then

                r01_pc_value        <= (others => '0');
                r02_pc_value        <=  (others => '0');
                r03_pc_value        <=  (others => '0');

            elsif rising_edge(clock) and (clock_en = '1') then

                r01_pc_value        <=  pc_value;
                r02_pc_value        <=  r01_pc_value;
                r03_pc_value        <=  r02_pc_value;

            end if;

        end process;

        --=========================================================================
        -- Registering the signals on each cycle. This ensure stability
        -- and higher performance (way higher clock frequency is possible)
        -- May be flushed if a branch is taken to prevent the execution of
        -- unwanted instructions.
        --=========================================================================
        P1 : process(clock, nRST, r1_flush_needed)
        begin
            if (nRST = '0') or (r1_flush_needed = '1') then
                r1_dec_rs1          <=  (others => '0');
                r1_dec_rs2          <=  (others => '0');
                r1_dec_rd           <=  (others => '0');
                r1_dec_imm          <=  (others => '0');
                r1_dec_opcode       <=  i_NOP;

                r1_pc_value         <=  (others => '0');

                r1_dec_illegal      <=  '0';
                r1_mem_addrerr      <=  '0';
                r1_pc_overflow      <=  '0';
                r1_if_err           <=  '0';
                r1_ctl_interrupt    <=  '0';
                r1_ctl_exception    <=  '0';
                r1_ctl_halt         <=  '0';

            elsif rising_edge(clock) and (clock_en = '1') then
                r1_dec_rs1          <=  dec_rs1;
                r1_dec_rs2          <=  dec_rs2;
                r1_dec_rd           <=  dec_rd;
                r1_dec_imm          <=  dec_imm;
                r1_dec_opcode       <=  dec_opcode;

                -- r1_pc_value         <=  pc_value;
                r1_pc_value         <=  r03_pc_value;

                r1_dec_illegal      <=  dec_illegal;
                r1_mem_addrerr      <=  mem_addrerr;
                r1_pc_overflow      <=  pc_overflow;
                r1_if_err           <=  if_err;
                r1_ctl_interrupt    <=  ctl_interrupt;
                r1_ctl_exception    <=  ctl_exception;
                r1_ctl_halt         <=  ctl_halt;

            end if;

        end process;

        --=========================================================================
        -- Analyzing status, and creating requirement signals for the specified instruction.
        -- This will be used on the second combinational part, for the more advanced IOs.
        --
        -- We're forced to make the process sensitive to a bunch of signals to ensure
        -- it WILL react to any new instructions.
        --=========================================================================
        P2 : process(   nRST,               r1_dec_rs1,         r1_dec_rs2,         r1_dec_rd,          
                        r1_dec_imm,         r1_dec_opcode,      r1_pc_value,        r1_dec_illegal,     
                        r1_mem_addrerr,     r1_pc_overflow,     r1_if_err,          r1_ctl_interrupt,   
                        r1_ctl_exception,   r1_ctl_halt)     
            begin
                if  (nRST = '0') then
                    cycles_count    <= T0;
                    is_immediate    <= '0';
                    is_req_data1    <= '0';
                    is_req_data2    <= '0';
                    is_req_store    <= '0';
                    is_req_alu      <= '0';
                    is_req_csr      <= '0';
                    is_req_mem      <= '0';
                    irq_err         <= '0';

                elsif   (r1_dec_illegal = '1')  or (r1_mem_addrerr = '1')   or (r1_pc_overflow = '1')   or
                        (r1_if_err = '1')       or (r1_ctl_interrupt = '1') or (r1_ctl_exception = '1') or
                        (r1_ctl_halt = '1')     then

                    -- Check if we're already interrupting, and if we have the right to do it...
                    if (irq_err = '0') and (r1_csr_mie = '1') then

                        cycles_count    <= T4_0;

                        -- We don't really care about theses signals, since
                        -- there's, in fact a single handler for all of theses cases.
                        is_immediate    <= '0';
                        is_req_data1    <= '0';
                        is_req_data2    <= '0';
                        is_req_store    <= '0';
                        is_req_alu      <= '0';
                        is_req_csr      <= '0';
                        is_req_mem      <= '0';

                        -- Inhibit the next irq / err
                        irq_err         <= '1';   
                    
                    end if;

                -- Try to deduce the next cycle ONLY if we're on the last opcode cycle
                elsif   (r2_cycles_count = T0)   or (r2_cycles_count = T1_1)  or (r2_cycles_count = T2_2)   or
                        (r2_cycles_count = T4_4) then

                    case r1_dec_opcode is

                        ------------------------------------------------------------------
                        when    i_NOP       |   i_FENCE =>
                                
                            cycles_count    <= T0;
                            is_immediate    <= '0';
                            is_req_data1    <= '0';
                            is_req_data2    <= '0';
                            is_req_store    <= '0';
                            is_req_alu      <= '0';
                            is_req_csr      <= '0';
                            is_req_mem      <= '0';

                            alu_opcode      <= c_NONE;

                        ------------------------------------------------------------------
                        when    i_ADDI      |   i_SLTI  |   i_SLTIU     |   i_XORI      |
                                i_ANDI      |   i_SLLI  |   i_SRLI      |   i_SRAI      |
                                i_ORI       |   i_LUI   |   i_AUIPC     =>

                            cycles_count    <= T0;
                            is_immediate    <= '1';
                            is_req_data1    <= '1';
                            is_req_data2    <= '0';
                            is_req_store    <= '1';
                            is_req_alu      <= '1';
                            is_req_csr      <= '0';
                            is_req_mem      <= '0';

                            case r1_dec_opcode is
                                when i_ADDI | i_LUI=>
                                    alu_opcode <= c_ADD;
                                when i_SLTI =>
                                    alu_opcode <= c_SLT;
                                when i_SLTIU =>
                                    alu_opcode <= c_SLTU;
                                when i_XORI =>
                                    alu_opcode <= c_XOR;
                                when i_ANDI =>
                                    alu_opcode <= c_AND;
                                when i_SLLI =>
                                    alu_opcode <= c_SLL;
                                when i_SRLI =>
                                    alu_opcode <= c_SRL;
                                when i_SRAI =>
                                    alu_opcode <= c_SRA;
                                when i_ORI | i_AUIPC => -- Rd = imm | 0x00 result in imm for i_AUIPC
                                    alu_opcode <= c_OR;
                                -- useless case, already covered, but otherwise design won't compile
                                when others =>
                                    alu_opcode <= c_NONE;
                            end case;

                        ------------------------------------------------------------------
                        when    i_CSRRWI    | i_CSRRSI  |   i_CSRRCI =>

                            cycles_count    <= T0;
                            is_immediate    <= '1';
                            is_req_data1    <= '1';
                            is_req_data2    <= '0';
                            is_req_store    <= '1';
                            is_req_alu      <= '1';
                            is_req_csr      <= '0';
                            is_req_mem      <= '0';

                            case r1_dec_opcode is
                                when i_CSRRWI =>
                                    alu_opcode <= c_ADD;
                                when i_CSRRSI =>
                                    alu_opcode <= c_OR;
                                when i_CSRRCI =>
                                    alu_opcode <= c_AND;
                                -- useless case, already covered, but otherwise design won't compile
                                when others =>
                                    alu_opcode <= c_NONE;
                            end case;

                        ------------------------------------------------------------------
                        when    i_ADD       |   i_SUB   |   i_SLL       |   i_SLT       |
                                i_SLTU      |   i_XOR   |   i_SRL       |   i_SRA       |
                                i_OR        |   i_AND   =>

                            cycles_count    <= T0;
                            is_immediate    <= '0';
                            is_req_data1    <= '1';
                            is_req_data2    <= '1';
                            is_req_store    <= '1';
                            is_req_alu      <= '1';
                            is_req_csr      <= '0';
                            is_req_mem      <= '0';   

                            case r1_dec_opcode is
                                when i_ADD =>
                                    alu_opcode <= c_ADD;
                                when i_SUB =>
                                    alu_opcode <= c_SUB;
                                when i_SLT =>
                                    alu_opcode <= c_SLT;
                                when i_SLTU =>
                                    alu_opcode <= c_SLTU;
                                when i_XOR =>
                                    alu_opcode <= c_XOR;
                                when i_AND =>
                                    alu_opcode <= c_AND;
                                when i_SLL =>
                                    alu_opcode <= c_SLL;
                                when i_SRL =>
                                    alu_opcode <= c_SRL;
                                when i_SRA =>
                                    alu_opcode <= c_SRA;
                                when i_OR =>
                                    alu_opcode <= c_OR;
                                -- useless case, already covered, but otherwise design won't compile
                                when others =>
                                    alu_opcode <= c_NONE;
                            end case;

                        ------------------------------------------------------------------
                        when     i_CSRRW    |   i_CSRRS |   i_CSRRC =>
                            
                            cycles_count    <= T1_0;
                            is_immediate    <= '0';
                            is_req_data1    <= '1';
                            is_req_data2    <= '1';
                            is_req_store    <= '1';
                            is_req_alu      <= '1';
                            is_req_csr      <= '1';
                            is_req_mem      <= '0'; 
                            
                            case r1_dec_opcode is
                                when i_CSRRW =>
                                    alu_opcode <= c_ADD;
                                when i_CSRRS =>
                                    alu_opcode <= C_OR;
                                when i_CSRRC =>
                                    alu_opcode <= C_AND;
                                -- useless case, already covered, but otherwise design won't compile
                                when others =>
                                    alu_opcode <= c_NONE;
                            end case;

                        ------------------------------------------------------------------
                        when    i_SB        |   i_SH    |   i_SW        |   i_LB        |
                                i_LH        |   i_LW    |   i_LBU       |   i_LHU       =>
                                                            
                            cycles_count    <= T0;
                            is_immediate    <= '0';
                            is_req_data1    <= '0';
                            is_req_data2    <= '1';
                            is_req_store    <= '1';
                            is_req_alu      <= '0';
                            is_req_csr      <= '0';
                            is_req_mem      <= '1';
                            
                            alu_opcode      <= c_NONE;

                        ------------------------------------------------------------------
                        when    i_BEQ       |   i_BNE   |   i_BLT       |   i_BGE       |
                                i_BLTu      |   i_BGEU  =>
                        
                            cycles_count    <= T2_0;
                            is_immediate    <= '0';
                            is_req_data1    <= '1';
                            is_req_data2    <= '1';
                            is_req_store    <= '0';
                            is_req_alu      <= '0';
                            is_req_csr      <= '0';
                            is_req_mem      <= '0';
                            
                            alu_opcode      <= c_NONE;

                        ------------------------------------------------------------------
                        when    i_JAL       |   i_JALR      |   i_ECALL |   i_EBREAK    |   
                                i_MRET  =>

                            cycles_count    <= T1_0;
                            is_immediate    <= '1';
                            is_req_data1    <= '1';
                            is_req_data2    <= '0';
                            is_req_store    <= '0';
                            is_req_alu      <= '0';
                            is_req_csr      <= '1';
                            is_req_mem      <= '0'; 

                            alu_opcode      <= c_NONE;

                            -- If we took an special handler route, unlock the future interrupts.
                            if (r1_dec_opcode = i_MRET) then
                                irq_err <= '0';
                            end if;

                    end case;

                -- Update the case to the next cycle
                else 
                    
                    case r2_cycles_count is
                        -- T1_x
                        when T1_0 =>
                            cycles_count <= T1_1;

                        -- T2_x
                        when T2_0 =>
                            cycles_count <= T2_1;
                        when T2_1 =>
                            cycles_count <= T2_2;

                        -- T4_x
                        when T4_0 =>
                            cycles_count <= T4_1;
                        when T4_1 =>
                            cycles_count <= T4_2;
                        when T4_2 =>
                            cycles_count <= T4_3;
                        when T4_3 =>
                            cycles_count <= T4_4;

                        -- Default to make quartus happy (but, we'll never get here since the if ... else)
                        when others =>
                            cycles_count <= T0;

                    end case;
                    
                end if;
                
            end process;

        --=========================================================================
        -- Registering the signals on each cycle. This ensure stability
        -- and higher performance (way higher clock frequency is possible)
        --=========================================================================
        P3 : process(nRST, clock)
        begin
            if (nRST = '0') then

                r2_dec_rs1          <= (others => '0');
                r2_dec_rs2          <= (others => '0');
                r2_dec_rd           <= (others => '0');
                r2_dec_imm          <= (others => '0');
                r2_dec_opcode       <= i_NOP;
                r2_dec_illegal      <= '0';
                r2_mem_addrerr      <= '0';
                r2_pc_value         <= (others => '0');
                r2_pc_overflow      <= '0';
                r2_if_err           <= '0';
                r2_ctl_interrupt    <= '0';
                r2_ctl_exception    <= '0';
                r2_ctl_halt         <= '0';
                r2_cycles_count      <= T0;

                r2_is_immediate     <= '0';
                r2_is_req_data1     <= '0';
                r2_is_req_data2     <= '0';
                r2_is_req_store     <= '0';
                r2_is_req_alu       <= '0';
                r2_is_req_csr       <= '0';
                r2_is_req_mem       <= '0';

                r2_alu_opcode       <= c_NONE;

            elsif rising_edge(clock) and (clock_en = '1') then

                r2_dec_rs1          <= r1_dec_rs1;
                r2_dec_rs2          <= r1_dec_rs2;
                r2_dec_rd           <= r1_dec_rd;
                r2_dec_imm          <= r1_dec_imm;
                r2_dec_opcode       <= r1_dec_opcode;
                r2_dec_illegal      <= r1_dec_illegal;
                r2_mem_addrerr      <= r1_mem_addrerr;
                r2_pc_value         <= r1_pc_value;
                r2_pc_overflow      <= r1_pc_overflow;
                r2_if_err           <= r1_if_err;
                r2_ctl_interrupt    <= r1_ctl_interrupt;
                r2_ctl_exception    <= r1_ctl_exception;
                r2_ctl_halt         <= r1_ctl_halt;

                r2_cycles_count     <= cycles_count;
                r2_is_immediate     <= is_immediate;
                r2_is_req_data1     <= is_req_data1;
                r2_is_req_data2     <= is_req_data2;
                r2_is_req_store     <= is_req_store;
                r2_is_req_alu       <= is_req_alu;
                r2_is_req_csr       <= is_req_csr;
                r2_is_req_mem       <= is_req_mem;

                r2_alu_opcode       <= alu_opcode;

            end if;

        end process;

        --=========================================================================
        -- Second combinational process, it output the control signals according the right
        -- parsed signals.
        --=========================================================================
        P4 : process(   nRST,               r2_dec_rs1,         r2_dec_rs2,         r2_dec_rd,          
                        r2_dec_imm,         r2_dec_opcode,      r2_pc_value,        r2_dec_illegal,     
                        r2_mem_addrerr,     r2_pc_overflow,     r2_if_err,          r2_ctl_interrupt,   
                        r2_ctl_exception,   r2_ctl_halt,        r2_cycles_count,    r2_is_immediate,
                        r2_is_req_data1,    r2_is_req_data2,    r2_is_req_store,    r2_is_req_alu,
                        r2_is_req_csr,      r2_is_req_mem,      r2_alu_opcode)

            begin

                if (nRST = '0') then

                    mem_addr        <= (others => '0');
                    mem_byteen      <= (others => '1');
                    mem_we          <= '0';
                    mem_req         <= '0';
                    pc_enable       <= '1';
                    pc_wren         <= '0';
                    pc_loadvalue    <= (others => '0');
                    reg_we          <= '0';
                    reg_wa          <= 0;
                    reg_ra1         <= 0;
                    reg_ra2         <= 0;
                    reg_rs2_out     <= (others => '0');
                    csr_we          <= '0';
                    csr_wa          <= 0;
                    csr_ra1         <= 0;
                    arg1_sel        <= '0';
                    arg2_sel        <= '0';
                    alu_cmd         <= c_NONE;
                    excep_occured   <= '0';
                    core_halt       <= '0';
                    dec_reset       <= '1'; -- by default, enable the decoder reset.
                    r1_flush_needed <= '0'; -- Do not flush the r1 registers.
                    if_aclr         <= '0'; -- Do not clear the output buffers.

                else
                    
                    case r2_cycles_count is
                        -----------------------------------------------------------
                        -- STANDARDS INSTRUCTIONS
                        -----------------------------------------------------------
                        when T0 =>

                            -- Stop the program counter from loading value. This enable faster jumps
                            -- by saving one CPU cycle, since the pc_wren is set on the latest branch / jump cycle.
                            pc_wren     <= '0';

                            -- Enabling memory output registers.
                            -- A reset for two cycles is required, otherwise the first reading would anyway be wrong.
                            -- Failing to do that insert a wrong instruction right after a jump.
                            if_aclr     <= '0';

                            -- Apply the outputs depending on the previous computed requirements.
                            if (r2_is_immediate = '1') then
                                arg2_sel        <= '1';
                                
                                -- Handle the AUIPC case
                                if (r2_dec_opcode = i_AUIPC) then
                                    reg_rs2_out <= std_logic_vector(signed(r2_pc_value) + signed(r2_dec_imm));  -- Can't use the ALU because
                                                                                                                -- both would require imm port.
                                                                                                                -- Thus, we make the addition
                                                                                                                -- internally.
                                else
                                    reg_rs2_out <= r2_dec_imm;
                                end if;
                            else
                                reg_rs2_out     <= (others => '0');
                            end if;

                            if (r2_is_req_data1 = '1') then
                                arg1_sel        <= '0';
                                reg_ra1         <= to_integer(unsigned(r2_dec_rs1));
                            else
                                reg_ra1         <= 0;
                            end if;

                            if (r2_is_req_data2 = '1') then
                                arg2_sel        <= '0';
                                reg_ra2         <= to_integer(unsigned(r2_dec_rs2));
                            else
                                reg_ra2         <= 0;
                            end if;

                            if (r2_is_req_store = '1') then
                                mem_req         <= '0';
                                reg_we          <= '1';
                                reg_wa          <= to_integer(unsigned(r2_dec_rd));
                            else
                                reg_we          <= '0';
                                reg_wa          <= 0;
                            end if;

                            if (r2_is_req_alu = '1') then
                                alu_cmd         <= r2_alu_opcode;
                            else
                                alu_cmd         <= c_NONE;
                            end if;

                            if (r2_is_req_csr = '1') then
                                arg1_sel        <= '1';
                                csr_ra1         <= 0;                   -- Need to change that line
                            else
                                csr_ra1         <= 0;
                            end if;

                            if (r2_is_req_mem = '1') then
                                mem_req         <= '1';
                                mem_we          <= '1';                 -- Need to change that line
                                mem_addr        <= (others => '0');     -- Need to change that line
                                mem_byteen      <= (others => '1');     -- Need to change that line
                            else
                                mem_req         <= '0';
                                mem_we          <= '0';
                                mem_addr        <= (others => '0');
                                mem_byteen      <= (others => '1');
                            end if;

                        -----------------------------------------------------------
                        -- JUMPS / CSR instructions
                        -----------------------------------------------------------
                        when T1_0 =>

                            -- First, stop the program counter. We won't need it until the next cycle.
                            pc_enable <= '0';

                            case r2_dec_opcode is

                                -----------------------------------------------------------
                                -- Handle JUMPS instructions
                                -----------------------------------------------------------
                                when i_JAL | i_JALR =>

                                    -- This first section implement the rd = pc + 4.
                                    -- We only need to copy the **next** program counter value, already incremented by four,
                                    -- into RD. To do this, we simulate this instruction : 
                                    --
                                    -- ADDI, RD, R0, IMM, where R0 is ALWAYS 0 (hardwired).
                                    --
                                    reg_rs2_out <= r1_pc_value;
                                    alu_cmd     <= c_ADD;
                                    arg2_sel    <= '1';
                                    arg1_sel    <= '0';
                                    reg_ra1     <= 0;
                                    reg_we      <= '1';
                                    reg_wa      <= to_integer(unsigned(r2_dec_rd));
                                    reg_ra2     <= to_integer(unsigned(r2_dec_rs1));

                                    -- Reset the decoder, since we're going to jump
                                    dec_reset       <= '0';
                                    r1_flush_needed <= '1';
                                    if_aclr         <= '1';
                                
                                -----------------------------------------------------------
                                -- Handle CSRR instructions.
                                -----------------------------------------------------------
                                when others =>
                                    
                            end case;

                        when T1_1 =>

                            -- Then, restart the program counter operation, to load the next values.
                            pc_enable <= '1';

                            case r3_dec_opcode is

                                when i_JAL | i_JALR =>

                                    -- Basically reset the global 
                                    reg_rs2_out     <= (others => '0');
                                    alu_cmd         <= c_NONE;
                                    arg2_sel        <= '0';
                                    arg1_sel        <= '0';
                                    reg_ra1         <= 0;
                                    reg_ra2         <= 0;
                                    reg_we          <= '0';
                                    reg_wa          <= 0;

                                    -- This second section implement the proper jump logic for the PC value.
                                    -- Thus, it depends from the called instruction.

                                    if (r3_dec_opcode = i_JAL) then
                                        
                                        pc_loadvalue    <= std_logic_vector(signed(r3_pc_value) + signed(r3_dec_imm));

                                    elsif (r3_dec_opcode = i_JALR) then

                                        pc_loadvalue    <= std_logic_vector(signed(r3_reg_rs1_in) + signed(r3_dec_imm));

                                    end if;

                                    -- Finally, ask the program counter to jump to the new address
                                    -- Since the loading is done on the next cycle, we'll be computing the address next
                                    pc_wren         <= '1';

                                    -- Re-enabling decoder operation.
                                    dec_reset       <= '1';
                                    r1_flush_needed <= '0';

                                when others =>

                            end case;

                        -----------------------------------------------------------
                        -- BRANCHES
                        -----------------------------------------------------------
                        when T2_0 =>

                        when T2_1 =>

                        when T2_2 =>

                        -----------------------------------------------------------
                        -- IRQ / ERR HANDLING
                        -----------------------------------------------------------
                        when T4_0 =>

                        when T4_1 =>

                        when T4_2 =>

                        when T4_3 =>

                        when T4_4 =>

                    end case;
                    
                end if;

        end process;

        --=========================================================================
        -- Registering the signals for the Tx_1 stages
        --=========================================================================
        P10 : process(nRST, clock)
        begin

            if (nRST = '0') then

                r3_dec_opcode       <= i_NOP;
                r3_reg_rs1_in       <= (others => '0');
                r3_pc_value         <= (others => '0');
                r3_dec_imm          <= (others => '0');

            elsif rising_edge(clock) and (clock_en = '1') then

                r3_dec_opcode       <= r2_dec_opcode;
                r3_pc_value         <= r2_pc_value;
                r3_dec_imm          <= r2_dec_imm;

                r3_reg_rs1_in       <= reg_rs1_in;

            end if;

        end process;

        --=========================================================================
        -- Register the signals for the Tx_2 stages
        --=========================================================================
        P11 : process(nRST, clock)
        begin

            if (nRST = '0') then

                r4_dec_opcode       <= i_NOP;

            elsif rising_edge(clock) and (clock_en = '1') then

                r4_dec_opcode       <= r3_dec_opcode;

            end if;

        end process;

        --=========================================================================
        -- Register the signals for the Tx_3 stages
        --=========================================================================
        P12 : process(nRST, clock)
        begin

            if (nRST = '0') then

                r5_dec_opcode       <= i_NOP;

            elsif rising_edge(clock) and (clock_en = '1') then

                r5_dec_opcode       <= r4_dec_opcode;

            end if;

        end process;

        --=========================================================================
        -- Register the signals for the Tx_4 stages
        --=========================================================================
        P13 : process(nRST, clock)
        begin

            if (nRST = '0') then

                r6_dec_opcode       <= i_NOP;

            elsif rising_edge(clock) and (clock_en = '1') then

                r6_dec_opcode       <= r5_dec_opcode;

            end if;

        end process;

        --=========================================================================
        -- END OF FILE
        --=========================================================================

    end architecture;