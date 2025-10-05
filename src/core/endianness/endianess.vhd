LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE work.common.ALL;

ENTITY endianess IS
    GENERIC (
        --! @brief Configure the data width in the core.
        XLEN : INTEGER := 32
    );
    PORT (
        --! @brief Data intput, to be swapped from endianness type.
        datain : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        --! @brief Data output, swapped.
        dataout : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0)
    );
END ENTITY;

ARCHITECTURE rtl OF endianess IS

BEGIN

    --========================================================================================
    --! @brief This process handle the data swapping, and isn't synchronously done.
    --! @details
    --! This process won't, in fact exist. It's a pure logic representation of a different wirings,
    --! which quartus will synthetize as a ... wiring with 0 LUT usage.
    --========================================================================================
    PROCESS (datain)

        VARIABLE temp : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);

    BEGIN
        -- swap byte by byte
        FOR i IN 0 TO (XLEN/8 - 1) LOOP
            temp(((i + 1) * 8 - 1) DOWNTO i * 8) :=
            datain(((XLEN/8 - 1 - i + 1) * 8 - 1) DOWNTO (XLEN/8 - 1 - i) * 8);
        END LOOP;

        dataout <= temp;

    END PROCESS;

END ARCHITECTURE rtl;