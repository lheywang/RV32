LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.common.ALL;

ENTITY csr_registers IS
    GENERIC (
        XLEN : INTEGER := 32
    );
    PORT (
        clock : IN STD_LOGIC;
        clock_en : IN STD_LOGIC;
        nRST : IN STD_LOGIC;

        -- single write port
        we : IN STD_LOGIC;
        wa : IN csr_register;
        wd : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

        -- two read ports
        ra1 : IN csr_register;
        rd1 : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

        -- Interrupt specific IOs
        int_vec : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        int_out : OUT STD_LOGIC;
        int_en : OUT STD_LOGIC
    );
END ENTITY;

ARCHITECTURE rtl OF csr_registers IS

    -- Define write permissions for each register
    CONSTANT MSTATUS_W_MASK : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := "00000000000000000111100010001000";
    CONSTANT MISA_W_MASK : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := "00000000000000000000000000000000";
    CONSTANT MIE_W_MASK : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := "11111111111111110000100010001000";
    CONSTANT MTVEC_W_MASK : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := "11111111111111111111111100000001";
    CONSTANT MSCRATCH_W_MASK : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := "11111111111111111111111111111111";
    CONSTANT MEPC_W_MASK : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := "11111111111111111111111111111110";
    CONSTANT MCAUSE_W_MASK : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := "10000000000000000000000000011111";
    CONSTANT MTVAL_W_MASK : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := "00000000000000000000000000000000";
    CONSTANT MIP_W_MASK : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0) := "00000000000000000000000000000000";

    -- Since there's not a lot of registers, we define them manually.
    SIGNAL mstatus : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL misa : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL mie : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL mtvec : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL mscratch : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL mepc : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL mcause : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL mtval : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL mip : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

    -- Defining logic mask function for easier updates
    FUNCTION update_bits(
        write_in : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        write_mask : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        write_old : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0))
        RETURN STD_LOGIC_VECTOR IS
    BEGIN
        RETURN (write_in AND write_mask) OR (write_old AND (NOT write_mask));
    END FUNCTION;

BEGIN

    -- synchronous write
    PROCESS (clock, nRST, int_vec)
    BEGIN

        -- Handle reset 
        IF nRST = '0' THEN

            mstatus <= X"0000_1800";
            misa <= X"4000_0100";
            mie <= (OTHERS => '0');
            mtvec <= (OTHERS => '0');
            mscratch <= (OTHERS => '0');
            mepc <= (OTHERS => '0');
            mcause <= (OTHERS => '0');
            mtval <= (OTHERS => '0');
            mip <= (OTHERS => '0');

            -- Handle standard writes
        ELSIF rising_edge(clock) AND (clock_en = '1') THEN

            -- Synchronizing the MIP register
            mip <= int_vec AND mie;

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
        mtval WHEN (ra1 = r_MTVAL) ELSE
        mip WHEN (ra1 = r_MIP) ELSE
        (OTHERS => '0');

    -- always read the MIP port.
    int_out <= mip(11);
    int_en <= mstatus(3);

END ARCHITECTURE;