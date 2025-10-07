--! @file src/core/core.vhd
--! @brief The base file that assemble all of the components of the core. Does not include any form of memory.
--! @author l.heywang <leonard.heywang@proton.me>
--! @date 05-10-2025

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.common.ALL;

ENTITY csr_registers IS
    GENERIC (
        --! @brief Configure the data width in the core.
        XLEN : INTEGER := 32
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
        --! @brief Write enable pin. Active high. Set to '1' to enable any write operation on the CSR register file.
        we : IN STD_LOGIC;
        --! @brief Write address, as an integer.
        wa : IN csr_register;
        --! @brief Write data, expressed as a vector of the same length as the the default value.
        wd : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

        --------------------------------------------------------------------------------------------------------
        -- Reading ports
        --------------------------------------------------------------------------------------------------------
        --! @brief Address for the read port
        ra1 : IN csr_register;
        --! @brief Data for the read port
        rd1 : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

        --------------------------------------------------------------------------------------------------------
        -- Interrupt related IOs
        --------------------------------------------------------------------------------------------------------
        --! @brief Interrupt vector, as input. The MIE interrupt mask will be applied to it, and result placed into MIP.
        int_vec : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        --! @brief Interrupt out, as MIP(7). Only the master external interrupt is handled, thus the interrupt_controller peripheral is required.
        int_out : OUT STD_LOGIC;
        --! @brief Interrupt enable bit, as an output MIE(3) . Indicate that the core must account for an interrupt.
        int_en : OUT STD_LOGIC;

        --------------------------------------------------------------------------------------------------------
        -- Interrupt related IOs
        --------------------------------------------------------------------------------------------------------
        --! @brief Cycle counter 32 MSB Input.
        in_cycleh : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        --! @brief Cycle counter 32 LSB Input.
        in_cyclel : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        --! @brief Instruction counter 32 MSB Input.
        in_instrh : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        --! @brief Instruction counter 32 LSB Input.
        in_instrl : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0)

    );
END ENTITY;

ARCHITECTURE rtl OF csr_registers IS

    --! @brief Write mask for MSTATUS register
    --! @details
    --! Bitmask defining which bits in **MSTATUS** are writable.
    --! Each bit corresponds to one bit position in the CSR.
    CONSTANT MSTATUS_W_MASK : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := "00000000000000000111100010001000";

    --! @brief Write mask for MIE register
    --! @details
    --! Bitmask defining which bits in **MIE** are writable.
    --! Each bit corresponds to one bit position in the CSR.
    CONSTANT MIE_W_MASK : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := "11111111111111110000100010001000";

    --! @brief Write mask for MTVEC register
    --! @details
    --! Bitmask defining which bits in **MTVEC** are writable.
    --! Each bit corresponds to one bit position in the CSR.
    CONSTANT MTVEC_W_MASK : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := "11111111111111111111111100000001";
    --! @brief Write mask for MEPC register
    --! @details
    --! Bitmask defining which bits in **MEPC** are writable.
    --! Each bit corresponds to one bit position in the CSR.
    CONSTANT MEPC_W_MASK : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := "11111111111111111111111111111110";

    --! @brief Write mask for MCAUSE register
    --! @details
    --! Bitmask defining which bits in **MCAUSE** are writable.
    --! Each bit corresponds to one bit position in the CSR.
    CONSTANT MCAUSE_W_MASK : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := "10000000000000000000000000011111";

    --! @brief Register mstatus.
    SIGNAL mstatus : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Register misa.
    SIGNAL misa : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Register mie.
    SIGNAL mie : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Register mtvec.
    SIGNAL mtvec : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Register mscratch.
    SIGNAL mscratch : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Register mepc.
    SIGNAL mepc : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Register mcause.
    SIGNAL mcause : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Register mtval.
    -- SIGNAL mtval : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Register mip.
    SIGNAL mip : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Register cycleh
    SIGNAL cycleh : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Register cyclel
    SIGNAL cyclel : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Register instrh
    SIGNAL instrh : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Register instrl
    SIGNAL instrl : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

    --! @brief Compute the new register value by applying pure logic to the inputs, while accouting for write masks.
    --! @details
    --! performs the operation OUT <= (IN & MASK) | (OLD & ~MASK)
    --! This enable to overwrite the bits with the new value regarless of their previous state, while preserving protected bits.
    FUNCTION update_bits(
        write_in : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        write_mask : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        write_old : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0))
        RETURN STD_LOGIC_VECTOR IS
    BEGIN
        RETURN (write_in AND write_mask) OR (write_old AND (NOT write_mask));
    END FUNCTION;

BEGIN

    --========================================================================================
    --! @brief P1 handle all of the write parts (since reading are done asynchronously).
    --! @details
    --! On each authorized rising edges, if we need to write (WE = '1') and the write
    --! address is not 0 (as per the spec, this register could not be written), 
    --! update the register file.
    --! On reset, the register file is initialized to 0x00000000 for all registers.
    --! The biggest difference with the register file is the fact that the mask is applied to ANy writes.
    --========================================================================================
    P1 : PROCESS (clock, nRST, int_vec)
    BEGIN

        -- Handle reset 
        IF (nRST = '0') THEN

            mstatus <= X"0000_1800";
            misa <= X"4000_0100";
            mie <= (OTHERS => '0');
            mtvec <= (OTHERS => '0');
            mscratch <= (OTHERS => '0');
            mepc <= (OTHERS => '0');
            mcause <= (OTHERS => '0');
            -- mtval <= (OTHERS => '0');
            mip <= (OTHERS => '0');
            cycleh <= (OTHERS => '0');
            cyclel <= (OTHERS => '0');
            instrl <= (OTHERS => '0');
            instrh <= (OTHERS => '0');

            -- Handle standard writes
        ELSIF rising_edge(clock) AND (clock_en = '1') THEN

            -- Synchronizing the MIP register
            mip <= int_vec AND mie;

            -- Copying the values of the counters
            cyclel <= in_cyclel;
            cycleh <= in_cycleh;
            instrl <= in_instrl;
            instrh <= in_instrh;

            -- Updating the others registers.
            IF (we = '1') THEN

                CASE wa IS
                    WHEN r_MSTATUS =>
                        mstatus <= update_bits(wd, MSTATUS_W_MASK, mstatus);
                        -- when r_MISA =>
                        --     misa        <= update_bits(wd, MISA_W_MASK,     misa); -- Mask is 0
                    WHEN r_MIE =>
                        mie <= update_bits(wd, MIE_W_MASK, mie);
                    WHEN r_MTVEC =>
                        mtvec <= update_bits(wd, MTVEC_W_MASK, mtvec);
                    WHEN r_MSCRATCH =>
                        --    mscratch    <= update_bits(wd, MSCRATCH_W_MASK, mscratch);
                        mscratch <= wd; -- Mask is FFFF_FFFF, so direct copy           
                    WHEN r_MEPC =>
                        mepc <= update_bits(wd, MEPC_W_MASK, mepc);
                    WHEN r_MCAUSE =>
                        mcause <= update_bits(wd, MCAUSE_W_MASK, mcause);
                        -- when r_MTVAL =>
                        --     mtval       <= update_bits(wd, MTVAL_W_MASK,    mtval); -- Mask is 0
                        -- when r_MIP    =>
                        --     mip         <= update_bits(wd, MIP_W_MASK,   mcause);  -- Mask is 0
                    WHEN OTHERS =>
                        -- do nothing
                END CASE;
            END IF;

        END IF;

    END PROCESS;

    -- asynchronous reads (combinational muxes)
    rd1 <= mstatus WHEN (ra1 = r_MSTATUS) ELSE
        misa WHEN (ra1 = r_MISA) ELSE
        mie WHEN (ra1 = r_MIE) ELSE
        mtvec WHEN (ra1 = r_MTVEC) ELSE
        mscratch WHEN (ra1 = r_MSCRATCH) ELSE
        mepc WHEN (ra1 = r_MEPC) ELSE
        mcause WHEN (ra1 = r_MCAUSE) ELSE
        -- mtval WHEN (ra1 = r_MTVAL) ELSE -- Reset to 0, can never been update --> return 0x00000000 on the other close
        mip WHEN (ra1 = r_MIP) ELSE
        cycleh WHEN (ra1 = r_CYCLEH) ELSE
        cyclel WHEN (ra1 = r_CYCLE) ELSE
        instrh WHEN (ra1 = r_INSTRH) ELSE
        instrl WHEN (ra1 = r_INSTR) ELSE
        -- Remaining registers are known, but unused and thus return 0 :
        -- mvendorid (0x00000000)
        -- marchid (0x00000000)
        -- mimpid (0x00000000)
        -- mhartid (0x00000000)
        (OTHERS => '0');

    -- always read the MIP port.
    int_out <= mip(11);
    int_en <= mstatus(3);

END ARCHITECTURE;