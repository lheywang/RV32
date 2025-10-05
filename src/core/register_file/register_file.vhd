--! @file src/core/core.vhd
--! @brief The base file that assemble all of the components of the core. Does not include any form of memory.
--! @author l.heywang <leonard.heywang@proton.me>
--! @date 05-10-2025

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

--! 
ENTITY register_file IS
    GENERIC (
        --! @brief Configure the data width in the core.
        XLEN : INTEGER := 32;
        --! @brief Configure the number of registers available. May be changed accordingly to configure for example the reduced instruction set.
        REG_NB : INTEGER := 32
    );
    PORT (
        --------------------------------------------------------------------------------------------------------
        -- Clocks & controls
        --------------------------------------------------------------------------------------------------------
        --! @brief clock input of the core. Must match the INPUT_FREQ generics within some tolerance.
        clock : IN STD_LOGIC;
        --! @brief clock enable from the core clock controller. Used to not create two clock domains from the master clock and the auxilliary clock.
        clock_en : IN STD_LOGIC;
        --! @brief reset input, active low. When held to '0', the system will remain in the reset state until set to '1'.
        nRST : IN STD_LOGIC;

        --------------------------------------------------------------------------------------------------------
        -- Writing port
        --------------------------------------------------------------------------------------------------------
        --! @brief Write enable pin. Active high. Set to '1' to enable any write operation on the register file.
        we : IN STD_LOGIC;
        --! @brief Write address, as an integer.
        wa : IN INTEGER RANGE 0 TO REG_NB - 1;
        --! @brief Write data, expressed as a vector of the same length as the the default value.
        wd : IN STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);

        --------------------------------------------------------------------------------------------------------
        -- Reading ports
        --------------------------------------------------------------------------------------------------------
        --! @brief Address for the first read port
        ra1 : IN INTEGER RANGE 0 TO REG_NB - 1;
        --! @brief Data for the first read port
        rd1 : OUT STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
        --! @brief Address for the second read port
        ra2 : IN INTEGER RANGE 0 TO REG_NB - 1;
        --! @brief Data for the second read port
        rd2 : OUT STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0)
    );
END ENTITY;

ARCHITECTURE rtl OF register_file IS

    --! @brief Type definiton of the register array
    TYPE reg_array_t IS ARRAY (0 TO REG_NB - 1) OF STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
    --! @brief instantiation of the register array, to be used.
    SIGNAL reg_array : reg_array_t := (OTHERS => (OTHERS => '0'));

BEGIN

    --========================================================================================
    --! @brief P1 handle all of the write parts (since reading are done asynchronously).
    --! @details
    --! On each authorized rising edges, if we need to write (WE = '1') and the write
    --! address is not 0 (as per the spec, this register could not be written), 
    --! update the register file.
    --! On reset, the register file is initialized to 0x00000000 for all registers.
    --========================================================================================
    P1 : PROCESS (clock, nRST)
    BEGIN
        IF nRST = '0' THEN
            reg_array <= (OTHERS => (OTHERS => '0'));
        ELSIF rising_edge(clock) AND (clock_en = '1') THEN
            IF (we = '1') AND (wa /= 0) THEN
                reg_array(wa) <= wd;
            END IF;
        END IF;
    END PROCESS;

    -- asynchronous reads (combinational muxes)
    rd1 <= (OTHERS => '0') WHEN ra1 = 0 ELSE
        reg_array(ra1);
    rd2 <= (OTHERS => '0') WHEN ra2 = 0 ELSE
        reg_array(ra2);

END ARCHITECTURE;