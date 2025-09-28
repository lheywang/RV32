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

        -- Regs muxes
        arg1_sel :      out     std_logic                                   := '0';                 -- Choose between the output of the CSR register file or the RS1 output of the register file
        arg2_sel :      out     std_logic                                   := '0';                 -- Choose between the output of the controller or the RS2 output of the register file

        -- Alu controls
        alu_cmd :       out     commands                                    := c_ADD;               -- ALU controls signals
        alu_status :    in      alu_feedback;                                                       -- Alu feedback signals for jumps and other statuses.

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

        -- function to convert a 5 bit register ID (0 to 31) into it's correct representation for control
        function f_regID_to_ctrl (
            inp : in std_logic_vector(4 downto 0))
            return std_logic_vector is
                variable retval : std_logic_vector(31 downto 0) := (others => '0');
                variable pos_int    : integer range 0 to 31;
                begin
                    retval(to_integer(unsigned(inp))) := '1';
                return retval;
            end function;

        type FSM_state is (
            ANY,                -- Handle most opcodes (ADD, ADDI, LUI...) and even memory (since memory runs at twice the core clock !)
            JMP1, JMP2,         -- Handle jumps (JMP1 : Compute addresses, write control signals + stop pipeline. JMP2 : Now, values are saved, so clear pipeline and wait for valid instruction.)
            BRANCH1, BRANCH2,   -- Handle branches (BRANCH1 : Compute addresses, evaluates signals + stop pipeline. BRANCH2 : compare values, outputs signals)
            WAITING,            -- Handle wait states
            IRQ,                -- IRQ handler (compared as a BRANCH)
            ERR                 -- Exception handler (compared as a BRANCH)
        );

        -- Storing FSM states
        signal state :          FSM_state := ANY;
        signal next_state :     FSM_state := ANY;

        -- Storing data between cycle to ensure pipeline operation
        signal save_rs1, next_rs1 :       std_logic_vector((REG_NB - 1) downto 0);
        signal save_rs2, next_rs2 :       std_logic_vector((REG_NB - 1) downto 0);
        signal save_rd, next_rd :         std_logic_vector((REG_NB - 1) downto 0);
        signal save_imm, next_imm :       std_logic_vector((XLEN - 1) downto 0);
        signal save_opcode, next_opcode : instructions;

        -- Internal controls signals
        signal pipe_stop :                std_logic                         := '1';                 -- Stop the pipeline (0 active)
        signal pipe_stall :               std_logic                         := '1';                 -- Clear the pipeline

    begin

        -- Process that handle reset, and clocks evolutions
        P1 : process(clock, nRST)
        begin
            if (nRST = '0') then
                state <= ANY;
            
            elsif rising_edge(clock) and (clock_en = '1') then
                -- Updating state
                state <= next_state;

                -- Updating save values
                save_rs1 <= next_rs1;
                save_rs2 <= next_rs2;
                save_rd <= next_rd;
                save_imm <= next_imm;
                save_opcode <= next_opcode;
            
            end if;
        end process;

        -- Process that handle states evolutions
        P2 : process(nRST, state)
        begin
            if (nRST = '0') then
                next_state <= ANY;

            -- Handle potential exceptions
            elsif   (dec_illegal = '1') or 
                    (mem_addrerr = '1') or 
                    (pc_overflow = '1') or 
                    (alu_status.overflow = '1') then
                next_state <= ERR;

            -- Handle potential interrupts
            elsif (ctl_interrupt = '1') then
                next_state <= IRQ;

            else

                case state is 
                    when JMP1 =>
                        next_state <= JMP2;

                    when BRANCH1 => 
                        next_state <= BRANCH2;

                    when others =>

                        next_rs1 <= dec_rs1;
                        next_rs2 <= dec_rs2;
                        next_rd <= dec_rd;
                        next_imm <= dec_imm;
                        next_opcode <= dec_opcode;

                        case dec_opcode is

                            when    i_BEQ   |  
                                    i_BNE   |
                                    i_BLT   |
                                    i_BGE   |
                                    i_BLTU  |
                                    i_BGEU  =>
                                next_state <= BRANCH1;

                            when    i_JAL   |
                                    i_JALR  =>
                                next_state <= JMP1;

                            when    i_NOP   |
                                    i_ECALL |
                                    i_EBREAK|
                                    i_FENCE =>
                                next_state <= WAITING;

                            when others =>
                                next_state <= ANY;

                        end case;
                    end case;

            end if;

        end process;


        P3 : process(state)
        begin

            case state is
                
                    when ANY =>

                    when JMP1 =>

                    when JMP2 =>

                    when BRANCH1 => 

                    when BRANCH2 =>

                    when WAITING =>

                    when ERR =>

                    when IRQ =>

                end case;

        end process;
        
    end architecture;