--! @file src/core/core.vhd
--! @brief The base file that assemble all of the components of the core. Does not include any form of memory.
--! @author l.heywang <leonard.heywang@proton.me>
--! @date 05-10-2025

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

ENTITY pcounter IS
    GENERIC (
        --! @brief Configure the data width in the core.
        XLEN : INTEGER := 32;
        --! @brief Configure the address exposed by the counter on startup. Must match the linker script file provided.
        RESET_ADDR : INTEGER := 0;
        --! @brief Configure the value that is added on each iteration cycle. This enable the ability to modify the memory alignement used.
        INCREMENT : INTEGER := 4
    );
    PORT (
        --------------------------------------------------------------------------------------------------------
        -- IO ports
        --------------------------------------------------------------------------------------------------------
        --! @brief Address output, to be sent to the instruction memory.
        address : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        --! @brief Address input, this value is copied synchronously into the counter when load = '1'
        address_in : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

        --------------------------------------------------------------------------------------------------------
        -- Status
        --------------------------------------------------------------------------------------------------------
        --! @brief Overflow flag output. Asserted when the address is greater than 4 294 967 288.
        nOVER : OUT STD_LOGIC;

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
        --! @brief Load enable input. When set to '1', the counting is disabled and the value of address_in is set into the counter.
        load : IN STD_LOGIC;
        --! @brief Enable input. When set to '1', the counter is authorized to count.
        enable : IN STD_LOGIC
    );
END ENTITY;

ARCHITECTURE behavioral OF pcounter IS

    --! @brief Internal counter for the address value, as an unsigned of XLEN bits.
    SIGNAL internal_address : unsigned((XLEN - 1) DOWNTO 0);
    --! @brief Internal value for the maximal address, computed on the runtime.
    SIGNAL address_maxval : unsigned((XLEN - 1) DOWNTO 0) := (OTHERS => '1');
    --! @brief Internal overflow status. Used to block the future evolutions of the counter.
    SIGNAL internal_nOVER : STD_LOGIC;

BEGIN

    --========================================================================================
    --! @brief P1 handle any operations of the program counter.
    --! @details
    --! On rising edges of the clocks, if authorized, the counter is increment by INCREMENT (typ. 4).
    --! If the load command is active, the counter is NOT incremented and the value is copied into the counter.
    --! This effect is shown immediately on the output, since the assignement is done asynchrounsly.
    --! When the value is greater than 0xFFFFFFF8, the overflow is asserted. This enable the ability to handle it
    --! within the core_controller. 
    --========================================================================================
    P1 : PROCESS (clock, nRST)
    BEGIN
        IF (nRST = '0') THEN
            internal_address <= to_unsigned(RESET_ADDR, internal_address'length);
            address_maxval <= (OTHERS => '1');
            address_maxval(2 DOWNTO 0) <= (OTHERS => '0');
            internal_nOVER <= '0';

        ELSIF rising_edge(clock) AND (clock_en = '1') THEN

            IF (load = '1') THEN
                internal_address <= unsigned(address_in);
                internal_nOVER <= '0';

            ELSIF (enable = '1') AND (internal_nOVER = '0') THEN
                internal_address <= internal_address + INCREMENT;

                IF (internal_address >= address_maxval) THEN
                    internal_nOVER <= '1';
                END IF;

            END IF;

        END IF;

    END PROCESS;

    -- Output assignement, in any time.
    address <= STD_LOGIC_VECTOR(internal_address);
    nOVER <= internal_nOVER;

END ARCHITECTURE;