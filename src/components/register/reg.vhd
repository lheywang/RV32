library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity reg is
    generic (
        XLEN :      integer := 32                                       -- Number of bits stored by the register. 
    );
    port (
        -- IO ports
        datain :    in      std_logic_vector((XLEN - 1) downto 0);      -- Input on the internal bus
        dataout1 :  out     std_logic_vector((XLEN -1) downto 0);       -- Output on the internal bus
        dataout2 :  out     std_logic_vector((XLEN -1) downto 0);       -- Output on the internal bus 2

        -- Clocks
        clock :     in      std_logic;                                  -- Main clock

        -- Control signals
        nRST :      in      std_logic;                                  -- Reset. Force a 0'b00--000 value
        WREN1 :     in      std_logic;                                  -- Enable the output of the register. (adync operation)
        WREN2 :     in      std_logic;                                  -- Enable the output of the register 2. (adync operation)
        INPU :      in      std_logic                                   -- Enable the input of the register. Data will be copied on the next rising edge.         
    );
end entity;

architecture behavioral of reg is

        signal data : std_logic_vector((XLEN - 1) downto 0);

    begin

        -- Synchronous store
        P1 : process(clock, nRST) 
            begin
                if (nRST = '0') then
                    data <= (others => '0');

                elsif rising_edge(clock) then
                    if (INPU = '1') then
                        data <= datain;
                    end if;

                end if;

            end process;

        -- Asyncrhonous writes
        dataout1 <= data when (WREN1 = '1') else
            (others => 'Z');
        dataout2 <= data when (WREN2 = '1') else
            (others => 'Z');

    end architecture;