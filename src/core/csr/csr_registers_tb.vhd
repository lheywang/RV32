LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.common.ALL;

ENTITY csr_registers_tb IS
END ENTITY;

ARCHITECTURE behavioral OF csr_registers_tb IS

    SIGNAL clock_t : STD_LOGIC := '0';
    SIGNAL clock_en_t : STD_LOGIC := '0';
    SIGNAL nRST_t : STD_LOGIC := '0';
    SIGNAL we_t : STD_LOGIC := '0';
    SIGNAL wa_t : csr_register := r_MSTATUS;
    SIGNAL wd_t : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '1');
    SIGNAL ra1_t : csr_register := r_MSTATUS;
    SIGNAL rd1_t : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL int_vec_t : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL int_out_t : STD_LOGIC := '0';

BEGIN

    U1 : ENTITY work.clock(behavioral)
        PORT MAP(
            clk => clock_t,
            nRST => nRST_t,
            clk_en => clock_en_t
        );

    U2 : ENTITY work.csr_registers(rtl)
        PORT MAP(
            clock => clock_t,
            clock_en => clock_en_t,
            nRST => nRST_t,
            we => we_t,
            wa => wa_t,
            wd => wd_t,
            ra1 => ra1_t,
            rd1 => rd1_t,
            int_vec => int_vec_t,
            int_out => int_out_t
        );

    -- clock
    P1 : PROCESS
    BEGIN
        WAIT FOR 5 ns;
        clock_t <= NOT clock_t;
    END PROCESS;

    -- nRST
    P2 : PROCESS
    BEGIN
        nRST_t <= '0';
        WAIT FOR 15 ns;
        nRST_t <= '1';
        WAIT;
    END PROCESS;

    -- Write data
    P3 : PROCESS
    BEGIN
        WAIT FOR 15 ns;
        WAIT FOR 200 ns;
        wa_t <= r_MSTATUS;
        we_t <= '1';
        WAIT FOR 20 ns;
        wa_t <= r_MISA;
        WAIT FOR 20 ns;
        wa_t <= r_MIE;
        WAIT FOR 20 ns;
        wa_t <= r_MTVEC;
        WAIT FOR 20 ns;
        wa_t <= r_MSCRATCH;
        WAIT FOR 20 ns;
        wa_t <= r_MEPC;
        WAIT FOR 20 ns;
        wa_t <= r_MCAUSE;
        WAIT FOR 20 ns;
        wa_t <= r_MTVAL;
        WAIT FOR 20 ns;
        wa_t <= r_MIP;
        WAIT FOR 20 ns;
        we_t <= '0';
        wd_t <= X"0000_0000";
        WAIT FOR 200 ns;
    END PROCESS;

    -- Read data
    P4 : PROCESS
    BEGIN
        WAIT FOR 20 ns;
        ra1_t <= r_MSTATUS;
        WAIT FOR 20 ns;
        ra1_t <= r_MISA;
        WAIT FOR 20 ns;
        ra1_t <= r_MIE;
        WAIT FOR 20 ns;
        ra1_t <= r_MTVEC;
        WAIT FOR 20 ns;
        ra1_t <= r_MSCRATCH;
        WAIT FOR 20 ns;
        ra1_t <= r_MEPC;
        WAIT FOR 20 ns;
        ra1_t <= r_MCAUSE;
        WAIT FOR 20 ns;
        ra1_t <= r_MTVAL;
        WAIT FOR 20 ns;
        ra1_t <= r_MIP;
        WAIT FOR 20 ns;
    END PROCESS;

    -- Emulate interrupt
    P5 : PROCESS
    BEGIN
        WAIT FOR 15 ns;
        WAIT FOR 600 ns;
        WAIT FOR 18 ns;
        int_vec_t <= X"FFFF_FFFF";
        WAIT;
    END PROCESS;

END ARCHITECTURE;