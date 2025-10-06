--! @file src/core/core.vhd
--! @brief The base file that assemble all of the components of the core. Does not include any form of memory.
--! @author l.heywang <leonard.heywang@proton.me>
--! @date 05-10-2025

LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY counter32 IS
    GENERIC (
        --! @brief Configure the  value exposed by the counter on reset state.
        RESET : INTEGER := 0;
        --! @brief Configure the value that is added on each iteration cycle.
        INCREMENT : INTEGER := 1
    );
    PORT (
        --------------------------------------------------------------------------------------------------------
        -- Clocks
        --------------------------------------------------------------------------------------------------------
        --! @brief clock input of the core. Must match the INPUT_FREQ generics within some tolerance.
        clock : IN STD_LOGIC;
        --! @brief clock enable from the core clock controller. Used to not create two clock domains from the master clock and the auxilliary clock.
        clock_en : IN STD_LOGIC;

        --------------------------------------------------------------------------------------------------------
        -- Control signals
        --------------------------------------------------------------------------------------------------------
        --! @brief reset input, active low. When held to '0', the system will remain in the reset state until set to '1'.
        nRST : IN STD_LOGIC;
        --! @brief Enable input. When set to '1', the counter is authorized to count.
        enable : IN STD_LOGIC;

        --------------------------------------------------------------------------------------------------------
        -- IO ports
        --------------------------------------------------------------------------------------------------------
        --! @brief Higher 32 bits of the value.
        valueH : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        --! @brief Lower 32 bits of the value.
        valueL : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)

    );
END ENTITY counter32;

ARCHITECTURE rtl OF counter32 IS

    SIGNAL value : unsigned(63 DOWNTO 0) := (OTHERS => '0');

BEGIN

    --========================================================================================
    --! @brief P1 handle the incrementation of the counter.
    --========================================================================================
    P1 : PROCESS (clock, nRST)
    BEGIN

        IF (nRST = '0') THEN
            value <= to_unsigned(RESET, value'length);

        ELSIF rising_edge(clock) AND (clock_en = '1') THEN

            IF (enable = '1') THEN
                value <= value + INCREMENT;
            END IF;

        END IF;

    END PROCESS;

    -- static assignements
    valueH(31 DOWNTO 0) <= STD_LOGIC_VECTOR(value(63 DOWNTO 32));
    valueL(31 DOWNTO 0) <= STD_LOGIC_VECTOR(value(31 DOWNTO 0));

END ARCHITECTURE rtl;