library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity dualreg is
    generic (
        XLEN :      integer := 32                                       -- Number of bits stored by the register. 
    );
    port (
        -- IO ports
        datain1 :   in      std_logic_vector((XLEN - 1) downto 0);      -- Input the first internal bus
        datain2 :   in      std_logic_vector((XLEN - 1) downto 0);      -- Input on the second internal bus

        dataout1 :  out     std_logic_vector((XLEN - 1) downto 0);      -- Output on first internal bus
        dataout2 :  out     std_logic_vector((XLEN - 1) downto 0);      -- Output on the second internal bus

        -- Clocks
        clock :     in      std_logic;                                  -- Main clock

        -- Control signals
        nRST :      in      std_logic;                                  -- Reset. Force a 0'b00--000 value

        WREN1 :     in      std_logic;                                  -- Enable the output of the register on dataout1
        WREN2 :     in      std_logic;                                  -- Enable the output of the register on dataout2

        INPU1 :     in      std_logic;                                  -- Enable the input of the register on the next clock edge, from datatin1. 
        INPU2 :     in      std_logic                                   -- Enable the input of the register on the next clock edge, from datatin2.
    );
end entity;

architecture behavioral of dualreg is

        signal data : std_logic_vector((XLEN - 1) downto 0);

    begin

        -- Synchronous store
        P1 : process(clock, nRST) 
            begin
                if (nRST = '0') then
                    data <= (others => '0');

                elsif rising_edge(clock) then
                    if (INPU1 = '1') and (INPU2 = '0') then
                        data <= datain1;
                    elsif (INPU1 = '0') and (INPU2 = '1') then
                        data <= datain2;
                    end if;

                end if;

            end process;

        -- Asyncrhonous writes
        dataout1 <= data when (WREN1 = '1') else
            (others => 'Z');
        dataout2 <= data when (WREN2 = '1') else
            (others => 'Z');

    end architecture;