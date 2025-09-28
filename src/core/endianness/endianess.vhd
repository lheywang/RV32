library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.common.all;

entity endianess is
    generic (
        XLEN :  integer := 32
    );
    port (
        datain : in std_logic_vector((XLEN - 1) downto 0);
        dataout : out std_logic_vector((XLEN - 1) downto 0)
    );
end entity;

architecture rtl of endianess is

begin

    process(datain)

        variable temp : std_logic_vector(XLEN-1 downto 0);

    begin
        -- swap byte by byte
        for i in 0 to (XLEN/8 - 1) loop
            temp(((i+1)*8 - 1) downto i*8) := 
            datain(((XLEN/8 - 1 - i + 1)*8 - 1) downto (XLEN/8 - 1 - i)*8);
        end loop;

        dataout <= temp;

    end process; 

end architecture rtl;
        
    