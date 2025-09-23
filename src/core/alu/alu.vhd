library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.common.all;

entity alu is 
generic (
    XLEN :      integer := 32                                                                   -- Number of bits stored by the register. 
);
port (
    -- Data IO
    arg1 :          in      std_logic_vector((XLEN - 1) downto 0);                              -- Argument 1
    arg2 :          in      std_logic_vector((XLEN - 1) downto 0);                              -- Argument 2
    result   :      out     std_logic_vector((XLEN - 1) downto 0)       := (others => 'Z');     -- Output

    -- Controls
    command :       in      commands;                                                           -- Required operation
    outen :         in      std_logic;                                                          -- Enable output drivers

    -- Status output
    zero :          out     std_logic                                   := '0';                 -- Result is ZERO
    overflow :      out     std_logic                                   := '0';                 -- Overflow detected
    beq :           out     std_logic                                   := '0';                 -- Indicate that the BEQ  condition is valid for jump
    bne :           out     std_logic                                   := '0';                 -- Indicate that the BNE  condition is valid for jump
    blt :           out     std_logic                                   := '0';                 -- Indicate that the BLT  condition is valid for jump
    bge :           out     std_logic                                   := '0';                 -- Indicate that the BGE  condition is valid for jump
    bltu :          out     std_logic                                   := '0';                 -- Indicate that the BLTU condition is valid for jump
    bgeu :          out     std_logic                                   := '0'                  -- Indicate that the BGEU condition is valid for jump
);
end entity;

architecture behavioral of alu is

    begin

        P1: process(arg1, arg2, command, outen)

            variable tmp    : signed(XLEN-1 downto 0);
            variable res    : std_logic_vector(XLEN-1 downto 0);
            
            variable v_ovf  : std_logic := '0';

            variable highz_out :  std_logic_vector((XLEN - 1) downto 0)       := (others => 'Z');     -- Used for HIGH-Z assignements

        begin

            res    := (others => '0');
            v_ovf  := '0';

            case command is

                when c_ADD =>
                    tmp := signed(arg1) + signed(arg2);
                    res := std_logic_vector(tmp);
                    -- signed overflow detection
                    if (arg1(XLEN-1) = arg2(XLEN-1)) and (res(XLEN-1) /= arg1(XLEN-1)) then
                        v_ovf := '1';
                    end if;

                when c_SUB =>
                    tmp := signed(arg1) - signed(arg2);
                    res := std_logic_vector(tmp);
                    -- signed overflow detection
                    if (arg1(XLEN-1) /= arg2(XLEN-1)) and (res(XLEN-1) /= arg1(XLEN-1)) then
                        v_ovf := '1';
                    end if;

                when c_SLL =>
                    res := std_logic_vector(shift_left(unsigned(arg1), to_integer(unsigned(arg2(4 downto 0)))));

                when c_SRL =>
                    res := std_logic_vector(shift_right(unsigned(arg1), to_integer(unsigned(arg2(4 downto 0)))));

                when c_SRA =>
                    res := std_logic_vector(shift_right(signed(arg1), to_integer(unsigned(arg2(4 downto 0)))));

                when c_AND =>
                    res := arg1 and arg2;

                when c_OR =>
                    res := arg1 or arg2;

                when c_XOR =>
                    res := arg1 xor arg2;

                when c_SLT =>
                    if signed(arg1) < signed(arg2) then
                        res := (others => '0');
                        res(0) := '1';
                    else
                        res := (others => '0');
                    end if;

                when c_SLTU =>
                    if unsigned(arg1) < unsigned(arg2) then
                        res := (others => '0');
                        res(0) := '1';
                    else
                        res := (others => '0');
                    end if;

                when others =>
                    res := (others => '0');

            end case;

            -- outputs assignment
            if (outen = '1') then
                result      <= res;
            else
                result      <= (others => '0');
            end if;

            overflow    <= v_ovf;
            
            if (unsigned(res) = 0) and (command /= c_None) then -- This make c_NONE be used for branchs evaluations.
                zero <= '1';
            else
                zero <= '0';
            end if;

            -- Jumps condition checks
            if (unsigned(arg1) = unsigned(arg2)) then
                beq <= '1';
                bne <= '0';
            else
                beq <= '0';
                bne <= '1';
            end if;

            if (unsigned(arg1) < unsigned(arg2)) then
                bltu <= '1';
                bgeu <= '0';
            else
                bltu <= '0';
                bgeu <= '1';
            end if;

            if (signed(arg1) < signed(arg2)) then
                blt <= '1';
                bge <= '0';
            else
                blt <= '0';
                bge <= '1';
            end if;

        end process;
        
    end architecture;