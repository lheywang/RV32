LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE work.common.ALL;

ENTITY endianess_tb IS
END ENTITY;

ARCHITECTURE behavioral OF endianess_tb IS

    SIGNAL datain_t : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"deadbeef";
    SIGNAL dataout_t : STD_LOGIC_VECTOR(31 DOWNTO 0);

BEGIN

    U1 : ENTITY work.endianess(rtl)
        GENERIC MAP(
            XLEN => 32
        )
        PORT MAP(
            datain => datain_t,
            dataout => dataout_t
        );

    P1 : PROCESS
    BEGIN
        WAIT FOR 10 ns;
        datain_t <= X"aabbccdd";
        WAIT FOR 10 ns;
        datain_t <= X"eeff1122";
    END PROCESS;

END ARCHITECTURE behavioral;