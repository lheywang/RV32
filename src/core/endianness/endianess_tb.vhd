library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.common.all;

entity endianess_tb is
end entity;

architecture behavioral of endianess_tb is

    signal datain_t : std_logic_vector(31 downto 0) := X"deadbeef";
    signal dataout_t : std_logic_vector(31 downto 0);

begin

    U1 : entity work.endianess(rtl)
        generic map (
            XLEN        =>  32
        )
        port map (
            datain      =>  datain_t,
            dataout     =>  dataout_t
        );

    P1 : process
    begin
        wait for 10 ns;
        datain_t <= X"aabbccdd";
        wait for 10 ns;
        datain_t <= X"eeff1122";
    end process;

end architecture behavioral;
        
    