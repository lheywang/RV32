library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity register_file is 
    generic (
        XLEN :      integer := 32;                                      -- Number of bits stored by the registers. 
        REG_NB :    integer := 32                                       -- Number of registers
    );
    port (
        -- Generic IO
        clock :     in      std_logic;                                  -- clock of the system
        nRST :      in      std_logic;                                  -- reset of the system

        -- Data IO
        in1 :       in      std_logic_vector((XLEN - 1) downto 0);      -- First input of the register file           
        in2 :       in      std_logic_vector((XLEN - 1) downto 0);      -- Second input of the register file
        out1 :      out     std_logic_vector((XLEN - 1) downto 0);      -- First output of the register file
        out2 :      out     std_logic_vector((XLEN - 1) downto 0);      -- Second output of the register file

        -- Control IO
        sel_in1 :   in      std_logic_vector((REG_NB - 1) downto 0);    -- Input signals for in1
        sel_in2 :   in      std_logic_vector((REG_NB - 1) downto 0);    -- Input signals for in2
        sel_out1 :  in      std_logic_vector((REG_NB - 1) downto 0);    -- Output signals for out1
        sel_out2 :  in      std_logic_vector((REG_NB - 1) downto 0)     -- Output signals for out2
    );
end entity;

architecture behavioral of register_file is
    
    begin
        -- Register 0 is constant to '000..000'. It cannot be written, and thus is ensured to get a constant 0 value.
        REG0 : entity work.dualreg(behavioral)
            generic map (
                XLEN    =>  XLEN
            )
            port map (
                datain1 =>  (others => '0'),
                datain2 =>  (others => '0'),
                dataout1=>  out1,
                dataout2=>  out2,
                clock   =>  clock,
                nRST    =>  nRST,
                WREN1   =>  sel_in1(0),
                INPU1   =>  '0',
                WREN2   =>  sel_in2(0),
                INPU2   =>  '0'
            );

        REG_FILE : for i in 1 to (REG_NB - 1) generate

                REGX : entity work.dualreg(behavioral)
                    generic map (
                        XLEN    =>  XLEN
                    )
                    port map (
                        datain1 =>  in1,
                        datain2 =>  in2,
                        dataout1=>  out1,
                        dataout2=>  out2,
                        clock   =>  clock,
                        nRST    =>  nRST,
                        WREN1   =>  sel_in1(i),
                        INPU1   =>  sel_out1(i),
                        WREN2   =>  sel_in2(i),
                        INPU2   =>  sel_out2(i)
                    );

        end generate REG_FILE;

    end architecture;