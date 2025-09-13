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
    res :           out     std_logic_vector((XLEN - 1) downto 0)       := (others => 'Z');     -- Output

    -- Controls
    command :       in      commands;                                                           -- Required operation
    outen :         in      std_logic;                                                          -- Enable output drivers
    sign_mode :     in      std_logic;                                                          -- Sign mode (1 = signed, 0 = unsigned)

    -- Status output
    status :        out     alu_status                                  := s_NONE;              -- status output (branches)
    overflow :      out     std_logic                                   := '0';                 -- Overflow detected
    underflow :     out     std_logic                                   := '0';                 -- Underflow detected
);
end entity;

architecture behavioral of alu is
    begin


        
    end architecture;