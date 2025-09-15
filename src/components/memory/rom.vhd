library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rom is
    generic (
        XLEN :      integer := 32                                       -- Number of bits stored by the register. 
    );
    port (
        clock :     in      std_logic
    );
end entity;

architecture behavioral of rom is

        -- Create the memory array (192 kB)
        type ram_array is array(0 to 49_152) of std_logic_vector((XLEN - 1) downto 0);
        signal mem : mem_array_t := (others => (others => '0'));

    begin
    end architecture;