LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE work.common.ALL;
USE work.records.ALL;

ENTITY core IS
    GENERIC (
        XLEN : INTEGER := 32;
        REG_NB : INTEGER := 32;
        INPUT_FREQ : INTEGER := 200_000_000;
        RESET_ADDR : INTEGER := 0;
        INT_ADDR : INTEGER := 0;
        ERR_ADDR : INTEGER := 0
    );
    PORT (
        -- global IOs
        clk : IN STD_LOGIC;
        nRST : IN STD_LOGIC;
        halt : IN STD_LOGIC;
        exception : IN STD_LOGIC;

        -- instruction fetching
        if_addr : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        if_rdata : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        if_err : IN STD_LOGIC;
        if_aclr : OUT STD_LOGIC;
        if_pause : OUT STD_LOGIC;

        -- external memory
        mem_addr : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        mem_we : OUT STD_LOGIC;
        mem_req : OUT STD_LOGIC;
        mem_wdata : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        mem_byten : OUT STD_LOGIC_VECTOR(((XLEN / 8) - 1) DOWNTO 0);
        mem_rdata : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        mem_err : IN STD_LOGIC;

        -- Interruptions
        int_vec : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

        -- debug / control
        core_halt : OUT STD_LOGIC;
        core_trap : OUT STD_LOGIC
    );
END ENTITY;

ARCHITECTURE behavioral OF core IS

    -- Clocking control
    SIGNAL clk_en : STD_LOGIC;

    -- Internals signals linked to registers data IO and selection
    SIGNAL reg_wdata : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL reg_rdata1 : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL reg_rdata2 : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL reg_wa : INTEGER RANGE 0 TO (REG_NB - 1);
    SIGNAL reg_we : STD_LOGIC;
    SIGNAL reg_ra1 : INTEGER RANGE 0 TO (REG_NB - 1);
    SIGNAL reg_ra2 : INTEGER RANGE 0 TO (REG_NB - 1);

    -- Internals signals linked to CSR registers data IO and selection
    SIGNAL csr_wa : csr_register;
    SIGNAL csr_we : STD_LOGIC;
    SIGNAL csr_ra1 : csr_register;
    SIGNAL csr_rdata1 : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL csr_mie : STD_LOGIC;
    SIGNAL csr_mip : STD_LOGIC;

    -- Signals for choosing the input elements
    SIGNAL arg1_sel : STD_LOGIC;
    SIGNAL arg2_sel : STD_LOGIC;

    -- Controller data IO
    SIGNAL ctl_rdata2 : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

    -- alu signals
    SIGNAL alu_cmd : commands;
    SIGNAL alu_status : alu_feedback;
    SIGNAL alu_out : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL alu_arg1 : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL alu_arg2 : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

    -- decoders signals
    SIGNAL dec_rs1 : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    SIGNAL dec_rs2 : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    SIGNAL dec_rd : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    SIGNAL dec_imm : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL dec_opcode : instructions;
    SIGNAL dec_illegal : STD_LOGIC;
    SIGNAL dec_reset_cmd : STD_LOGIC;
    SIGNAL dec_reset : STD_LOGIC;

    -- program counter
    SIGNAL pc_waddr : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL pc_raddr : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    SIGNAL pc_wen : STD_LOGIC;
    SIGNAL pc_en : STD_LOGIC;
    SIGNAL pc_overflow : STD_LOGIC;

    -- Memory
    SIGNAL mem_request : STD_LOGIC;
    SIGNAL mem_rw : STD_LOGIC;

BEGIN

    -- Combinational logic
    -- Reset
    dec_reset <= nRST AND dec_reset_cmd;

    -- Clock generator
    CLK1 : ENTITY work.clock(behavioral)
        GENERIC MAP(
            INPUT_FREQ => INPUT_FREQ,
            OUTPUT_FREQ => (INPUT_FREQ / 2),
            DUTY_CYCLE => 50
        )
        PORT MAP(
            clk => clk,
            nRST => nRST,
            clk_en => clk_en
        );

    -- Program counter
    PC1 : ENTITY work.pcounter(behavioral)
        GENERIC MAP(
            XLEN => XLEN,
            RESET_ADDR => RESET_ADDR,
            INCREMENT => (XLEN / 8)
        )
        PORT MAP(
            address => pc_raddr,
            address_in => pc_waddr,
            nOVER => pc_overflow,
            clock => clk,
            clock_en => clk_en,
            nRST => nRST,
            load => pc_wen,
            enable => pc_en
        );

    -- Decoder
    DEC1 : ENTITY work.decoder(behavioral)
        GENERIC MAP(
            XLEN => XLEN
        )
        PORT MAP(
            instruction => if_rdata,
            rs1 => dec_rs1,
            rs2 => dec_rs2,
            rd => dec_rd,
            imm => dec_imm,
            opcode => dec_opcode,
            illegal => dec_illegal,
            clock => clk,
            clock_en => clk_en,
            nRST => dec_reset,
            shift_en => pc_en,
            pause => pause
        );

    -- Controller / FSM
    FSM1 : ENTITY work.core_controller(behavioral)
        GENERIC MAP(
            XLEN => XLEN,
            REG_NB => REG_NB,
            INT_ADDR => INT_ADDR,
            EXP_ADDR => ERR_ADDR
        )
        PORT MAP(
            clock => clk,
            clock_en => clk_en,
            nRST => nRST,
            dec_rs1 => dec_rs1,
            dec_rs2 => dec_rs2,
            dec_rd => dec_rd,
            dec_imm => dec_imm,
            dec_opcode => dec_opcode,
            dec_illegal => dec_illegal,
            dec_reset => dec_reset_cmd,
            mem_addr => mem_addr,
            mem_byteen => mem_byten,
            mem_we => mem_rw,
            mem_req => mem_request,
            mem_addrerr => mem_err,
            pc_value => pc_raddr,
            pc_overflow => pc_overflow,
            pc_enable => pc_en,
            pc_wren => pc_wen,
            pc_loadvalue => pc_waddr,
            reg_we => reg_we,
            reg_wa => reg_wa,
            reg_ra1 => reg_ra1,
            reg_ra2 => reg_ra2,
            reg_rs1_in => reg_rdata2,
            reg_rs2_out => ctl_rdata2,
            arg1_sel => arg1_sel,
            arg2_sel => arg2_sel,
            csr_we => csr_we,
            csr_wa => csr_wa,
            csr_ra1 => csr_ra1,
            csr_mie => csr_mie,
            csr_mip => csr_mip,
            alu_cmd => alu_cmd,
            alu_status => alu_status,
            if_err => if_err,
            if_aclr => if_aclr,
            ctl_exception => exception,
            ctl_halt => halt,
            excep_occured => core_trap,
            core_halt => core_halt
        );

    -- Register file
    REGS1 : ENTITY work.register_file(rtl)
        GENERIC MAP(
            XLEN => XLEN,
            REG_NB => REG_NB
        )
        PORT MAP(
            clock => clk,
            clock_en => clk_en,
            nRST => nRST,
            we => reg_we,
            wa => reg_wa,
            wd => reg_wdata,
            ra1 => reg_ra1,
            ra2 => reg_ra2,
            rd1 => reg_rdata1,
            rd2 => reg_rdata2
        );

    -- CSR file
    -- Register file
    CSR1 : ENTITY work.csr_registers(rtl)
        GENERIC MAP(
            XLEN => XLEN
        )
        PORT MAP(
            clock => clk,
            clock_en => clk_en,
            nRST => nRST,
            we => csr_we,
            wa => csr_wa,
            wd => reg_wdata, -- Shared output bus with the ALU output
            ra1 => csr_ra1,
            rd1 => csr_rdata1,
            int_vec => int_vec,
            int_en => csr_mie,
            int_out => csr_mip
        );

    -- Arithmetic and Logic unit
    ALU1 : ENTITY work.alu(behavioral)
        GENERIC MAP(
            XLEN => XLEN
        )
        PORT MAP(
            arg1 => alu_arg1,
            arg2 => alu_arg2,
            result => alu_out,
            command => alu_cmd,
            status => alu_status
        );

    -- Static mappings
    if_addr <= pc_raddr;
    mem_req <= mem_request;
    mem_we <= mem_rw;

    -- Muxes
    reg_wdata <= mem_rdata WHEN (mem_request = '1') AND (mem_rw = '0') ELSE
        alu_out;
    mem_wdata <= alu_arg1 WHEN (mem_request = '1') AND (mem_rw = '1') ELSE
        (OTHERS => '0');

    alu_arg1 <= csr_rdata1 WHEN (arg1_sel = '1') ELSE
        reg_rdata1;
    alu_arg2 <= ctl_rdata2 WHEN (arg2_sel = '1') ELSE
        reg_rdata2;

END ARCHITECTURE;