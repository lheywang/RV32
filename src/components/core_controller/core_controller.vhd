library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.common.all;

entity core_controller is 
    generic (
        -- Size generic values :
        XLEN :      integer := 32;                                                                  -- Number of bits stored by the register. 
        REG_NB :    integer := 32;                                                                  -- Number of registers in the processor.

        -- Handler exceptions : 
        INT_ADDR :  integer := X"70000";                                                            -- Address of the interrupt handler to jump.
        EXP_ADDR :  integer := X"7F000"                                                             -- Address of the exception handler to jump.
    );
    port (
        -- General inputs : 
        clock :         in      std_logic;                                                          -- Global core clock.
        nRST :          in      std_logic;                                                          -- System reset
        
        -- Decoder signals : 
        dec_rs1 :       in      std_logic_vector((REG_NB + 1) downto 0);                            -- Register selection 1
        dec_rs2 :       in      std_logic_vector((REG_NB - 1) downto 0);                            -- Register selection 2
        dec_rd :        in      std_logic_vector((REG_NB - 1) downto 0);                            -- Register selection for write
        dec_imm :       in      std_logic_vector((XLEN - 1) downto 0);                              -- Immediate value, already signed extended
        dec_opcode :    in      instructions;                                                       -- Opcode, custom type
        dec_illegal :   in      std_logic;                                                          -- Illegal instruction exception handler

        -- Memory signals : 
        mem_addr :      out     std_logic_vector((XLEN - 1) downto 0)       := (others => '0');     -- Memory address
        mem_byteen :    out     std_logic_vector(3 downto 0)                := (others => '1');     -- Memory byte selection
        mem_read :      out     std_logic                                   := '1';                 -- Memory read order
        mem_write :     out     std_logic                                   := '1';                 -- Memory write order
        mem_valid :     in      std_logic;                                                          -- Memory operation is complete.
        mem_addrerr :   in      std_logic;                                                          -- Incorrect memory address.
        mem_busy :      in      std_logic;                                                          -- Indicate that the memory is doing IO operations.
        
        -- Program counter signals : 
        pc_value :      in      std_logic_vector((XLEN -1) downto 0);                               -- Readback of the PC value
        pc_overflow :   in      std_logic;                                                          -- Overflow status of the PC.
        pc_enable :     out     std_logic                                   := '1';                 -- Enable of the PC counter
        pc_wren :       out     std_logic                                   := '0';                 -- Load a new value on the program counter
        pc_loadvalue :  out     std_logic_vector((XLEN - 1) downto 0)       := (others => '0');     -- Value to be loaded on the program counter

        -- Regs selection : 
        reg_rs1 :       out     std_logic_vector((REG_NB - 1) downto 0)     := (others => '0');     -- Selection signals for the register file (1)
        reg_rs2 :       out     std_logic_vector((REG_NB - 1) downto 0)     := (others => '0');     -- Selection signals for the register file (2)
        reg_rd :        out     std_logic_vector((REG_NB - 1) downto 0)     := (others => '0');     -- Selection signals for the register file (out)
        reg_rs1_in :    in      std_logic_vector((XLEN - 1) downto 0);                              -- Register rs1 input signal
        reg_rs2_out :   out     std_logic_vector((XLEN - 1) downto 0)       := (others => 'Z');     -- Forced output for an argument

        -- Alu controls
        alu_cmd :       out     commands                                    := c_ADD;               -- ALU controls signals
        alu_out_en :    out     std_logic                                   := '1';                 -- Enable output (output bus is shared with memory)
        alu_overflow :  in      std_logic;                                                          -- ALU overflow
        alu_beq :       in      std_logic                                   := '0';                 -- Indicate that the BEQ  condition is valid for jump
        alu_bne :       in      std_logic                                   := '0';                 -- Indicate that the BNE  condition is valid for jump
        alu_blt :       in      std_logic                                   := '0';                 -- Indicate that the BLT  condition is valid for jump
        alu_bge :       in      std_logic                                   := '0';                 -- Indicate that the BGE  condition is valid for jump
        alu_bltu :      in      std_logic                                   := '0';                 -- Indicate that the BLTU condition is valid for jump
        alu_bgeu :      in      std_logic                                   := '0'                  -- Indicate that the BGEU condition is valid for jump

        -- Generics inputs :
        ctl_interrupt : in      std_logic;                                                          -- Interrupt flag
        
        -- Generics outputs :
        excep_occured : out     std_logic                                   := '0'                  -- Generic flag to signal an exception occured (LED ?)
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
    begin
    end architecture;