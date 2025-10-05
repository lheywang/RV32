LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

ENTITY clock IS
    GENERIC (
        --! @brief Input frequency of the module. This value is needed to deduce the counter limits.
        INPUT_FREQ : INTEGER := 200_000_000;
        --! @brief Output frequency of the module. This value is needed to deduce the counter limits.
        --! output frequency must be an integer factor of the input, otherwise roundings errors will be issued,
        --! and the output frequency may not match the requirements.
        OUTPUT_FREQ : INTEGER := 100_000_000;
        --! @brief Wanted duty cycle (only possible when division factor is >= 2)
        DUTY_CYCLE : INTEGER := 50
    );
    PORT (
        --! @brief clock input of the core. Must match the INPUT_FREQ generics within some tolerance.
        clk : IN STD_LOGIC;
        --! @brief reset input, active low. When held to '0', the system will remain in the reset state until set to '1'.
        nRST : IN STD_LOGIC;
        --! @brief clock output, divided by the factor INPUT_FREQ / OUTPUT_FREQ and with a duty cycle of DUTY_CYCLE value.
        clk_en : OUT STD_LOGIC
    );
END ENTITY;

ARCHITECTURE behavioral OF clock IS

    --! @brief constant that will be used as the upper limit of the counter.
    CONSTANT maxval : INTEGER := (INPUT_FREQ / OUTPUT_FREQ) - 1;
    --! @brief constant that will trigger a change in the output value.
    CONSTANT threshold : INTEGER := ((maxval * DUTY_CYCLE) / 100) + 1;

    --! @brief counter value.
    SIGNAL count : INTEGER RANGE 0 TO maxval + 1;

BEGIN

    --========================================================================================
    --! @brief Process to handle the clock evolution, based on a counter and comparisons.
    --========================================================================================
    P1 : PROCESS (clk, nRST)
    BEGIN

        IF (nRST = '0') THEN
            count <= 0;
            clk_en <= '0';

        ELSIF rising_edge(clk) THEN

            IF (count >= maxval) THEN
                count <= 0;
            ELSE
                count <= count + 1;
            END IF;

            IF (count < threshold) THEN
                clk_en <= '1';
            ELSE
                clk_en <= '0';
            END IF;

        END IF;

    END PROCESS;

END ARCHITECTURE;