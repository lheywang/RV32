LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.ALL;

ENTITY core_tb IS
END ENTITY;

ARCHITECTURE behavioral OF core_tb IS

    SIGNAL clk_t : STD_LOGIC := '0';
    SIGNAL nRST_t : STD_LOGIC := '0';
    SIGNAL RST_t : STD_LOGIC := '0';
    SIGNAL halt_t : STD_LOGIC := '0';
    SIGNAL exception_t : STD_LOGIC := '0';
    SIGNAL if_addr_t : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL if_rdata_t : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL if_err_t : STD_LOGIC := '0';
    SIGNAL mem_addr_t : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL mem_we_t : STD_LOGIC := '0';
    SIGNAL mem_req_t : STD_LOGIC := '0';
    SIGNAL mem_wdata_t : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL mem_byten_t : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL mem_rdata_t : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL mem_err_t : STD_LOGIC := '0';
    SIGNAL core_halt_t : STD_LOGIC := '0';
    SIGNAL core_trap_t : STD_LOGIC := '0';
    SIGNAL if_aclr_t : STD_LOGIC := '0';
    SIGNAL int_vec_t : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL if_pause_t : STD_LOGIC := '0';

BEGIN

    RST_t <= (NOT nRST_t) OR if_aclr_t;
    CORE : ENTITY work.core(behavioral)
        GENERIC MAP(
            XLEN => 32,
            REG_NB => 32,
            INPUT_FREQ => 200_000_000,
            RESET_ADDR => 0,
            INT_ADDR => 0
        )
        PORT MAP(
            clk => clk_t,
            nRST => nRST_t,
            halt => halt_t,
            exception => exception_t,
            if_addr => if_addr_t,
            if_rdata => if_rdata_t,
            if_err => if_err_t,
            if_aclr => if_aclr_t,
            if_pause => if_pause_t,
            mem_addr => mem_addr_t,
            mem_we => mem_we_t,
            mem_req => mem_req_t,
            mem_wdata => mem_wdata_t,
            mem_byten => mem_byten_t,
            mem_rdata => mem_rdata_t,
            mem_err => mem_err_t,
            core_halt => core_halt_t,
            core_trap => core_trap_t,
            int_vec => int_vec_t
        );

    -- The two memory elements depends on the altera_mf library, which, if not available WILL cause compilation issues.
    -- Ensure you have them, or, try to make without.
    RAM : ENTITY work.ram(SYN)
        PORT MAP
        (
            aclr => RST_t,
            address => mem_addr_t(14 DOWNTO 2), -- To correct : write a memory address translator that match the different addres spaces. 
            byteena => mem_byten_t,
            clock => clk_t,
            data => mem_wdata_t,
            wren => mem_we_t,
            q => mem_rdata_t
        );

    ROM : ENTITY work.rom(SYN)
        PORT MAP
        (
            aclr => RST_t, -- Never reset the ROM. Since RAM based, we don't want to clear it.
            address_a => if_addr_t(15 DOWNTO 2),
            address_b => mem_addr_t(15 DOWNTO 2), -- To correct : write a memory address translator that match the different addres spaces.
            clock => clk_t,
            q_a => if_rdata_t,
            q_b => mem_rdata_t,
            enable => if_pause_t
        );

    -- Stimulus
    -- Clocks
    P1 : PROCESS
    BEGIN
        WAIT FOR 5 ns;
        clk_t <= NOT clk_t;
    END PROCESS;

    -- reset handler
    P2 : PROCESS
    BEGIN
        nRST_t <= '0';
        WAIT FOR 8 ns;
        nRST_t <= '1';
        WAIT;
    END PROCESS;

    -- Interrupt emulation (command / uncomment if neded)
    P3 : PROCESS
    BEGIN
        WAIT FOR 228 ns;
        -- int_vec_t(11) <= '1';
        WAIT;
    END PROCESS;

END ARCHITECTURE;