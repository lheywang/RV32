library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity decoder is 
    generic (
        XLEN :      integer := 32;                                          -- Width of the data outputs. 
                                                                            -- Warning : This does not change the number of registers not instruction lenght
        REG_NB :    integer := 32                                           -- Number of processors registers.
    );
    port (
        -- instruction input
        instruction :   in      std_logic_vector(31 downto 0);

        -- outputs
        -- buses
        rs1 :           out     std_logic_vector(REG_NB downto 0);          -- One more register here, for the selection of immediate value.
        rs2 :           out     std_logic_vector((REG_NB - 1) downto 0);
        rd :            out     std_logic_vector((REG_NB - 1) downto 0);
        imm :           out     std_logic_vector((XLEN - 1) downto 0);
        opcode :        out     std_logic_vector(16 downto 0);              -- ISA use an up to 17 bit opcode.
        -- signals
        nILLEGAL :      out     std_logic;
        counter_en :    out     std_logic;

        -- Clocks
        clock :         in      std_logic;
        nRST :          in      std_logic
    );
end entity;

architecture behavioral of decoder is

        -- signal

    begin

        P1 : process(clock, nRST) 
            begin

                if (nRST = '0') then

                elsif rising_edge(clock) then

                end if;
                
            end process;

    end architecture;