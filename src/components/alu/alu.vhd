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
    status :        out     alu_status                                  := s_NONE;              -- status output (branches)
    overflow :      out     std_logic                                   := '0'                  -- Overflow detected
);
end entity;

architecture behavioral of alu is

        signal zero :       std_logic                                   := '0';

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
                result      <= (others => 'Z');
            end if;

            overflow    <= v_ovf;
            
            if (unsigned(res) = 0) then
                zero <= '1';
            else
                zero <= '0';
            end if;

        end process;

    status      <=  s_ZERO      when (zero = '1') else
                    s_EQ        when (unsigned(arg1) = unsigned(arg2)) else
                    s_GREATER   when (unsigned(arg1) > unsigned(arg2)) else
                    s_SMALLER   when (unsigned(arg1) < unsigned(arg2)) else
                    s_NONE;
        
    end architecture;