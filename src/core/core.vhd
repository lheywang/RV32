--! @file src/core/core.vhd
--! @brief The base file that assemble all of the components of the core. Does not include any form of memory.
--! @author l.heywang <leonard.heywang@proton.me>
--! @date 05-10-2025

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE work.common.ALL;
USE work.records.ALL;

ENTITY core IS
    GENERIC (
        --! @brief Configure the data width in the core. DOES NOT configure the instruction lenght, which is fixed to 32 bits.
        XLEN : INTEGER := 32;
        --! @brief Configure the number of registers available. May be changed accordingly to configure for example the reduced instruction set.
        REG_NB : INTEGER := 32;
        --! @brief Pure value to set the input frequency. Used to configure the clock subsystem, which will half it. The frequency MUST be divisible by two.
        INPUT_FREQ : INTEGER := 200_000_000;
        --! @brief Address taken by the program counter after a reset.
        RESET_ADDR : INTEGER := 0;
        --! @brief Default address jumped in case of interrupt. This value is used to default the MTVEC register.
        INT_ADDR : INTEGER := 0
    );
    PORT (
        --------------------------------------------------------------------------------------------------------
        -- global IOs
        --------------------------------------------------------------------------------------------------------
        --! @brief clock input of the core. Must match the INPUT_FREQ generics within some tolerance.
        clk : IN STD_LOGIC;
        --! @brief reset input, active low. When held to '0', the system will remain in the reset state until set to '1'.
        nRST : IN STD_LOGIC;
        --! @brief halt input, active high. When hel to '1', the system won't execute any instructions and will stop as it.
        halt : IN STD_LOGIC;
        --! @brief exception input, used to trigger exceptions for external peripherals from the core.
        exception : IN STD_LOGIC;

        --------------------------------------------------------------------------------------------------------
        -- instruction fetching
        --------------------------------------------------------------------------------------------------------
        --! @brief Instruction fetch address. This is the output of the current program counter address.
        if_addr : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        --! @brief Instruction read data. This is the input of the instruction to be executed.
        if_rdata : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        --! @brief Instruction fetch error. Active high. When set to '1', this indicate that the memory subsystem as encountered an issue.
        if_err : IN STD_LOGIC;
        --! @brief Instruction fetch, output registers asynchronous clear. Used to empty the output registers of the ROM.
        if_aclr : OUT STD_LOGIC;
        --! @brief Instruction fetch pause. Active low. This is inhibit the registers of the different memory modules, and shall stop them.
        if_pause : OUT STD_LOGIC;

        --------------------------------------------------------------------------------------------------------
        -- external memory
        --------------------------------------------------------------------------------------------------------
        --! @brief External memory address. This is the output of the current memory location written.
        mem_addr : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        --! @brief External memory write enable. When set to '1', this indicate a write.
        mem_we : OUT STD_LOGIC;
        --! @brief External memory request. This signal is active '1' when the memory is performing a request, otherwise 0. Peripherals shall ignore buses states when '0'.
        mem_req : OUT STD_LOGIC;
        --! @brief External memory write data. This is the data to be written into the memory, must be ignored when reading.
        mem_wdata : OUT STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        --! @brief External memory byte enable signals. Used to perform I/O of different sizes (smaller) than XLEN.
        mem_byten : OUT STD_LOGIC_VECTOR(((XLEN / 8) - 1) DOWNTO 0);
        --! @brief External memory read data. This is the data to be written into the registers, must be zeroed when writting.
        mem_rdata : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
        --! @brief External memory error pin, active high. Used to trigger an exception.
        mem_err : IN STD_LOGIC;

        --------------------------------------------------------------------------------------------------------
        -- Interruptions
        --------------------------------------------------------------------------------------------------------
        --! @brief Interrupt vector, 32 bits. When a bit is set to high, it's fed into the CSR MIE register which will mask them, and transfer them to the core if it match the right position. Only the 11 bit will trigger an interrupt, but the MIP register can be used to fetch ANY interrupt.
        int_vec : IN STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

        --------------------------------------------------------------------------------------------------------
        -- debug / control
        --------------------------------------------------------------------------------------------------------
        --! @brief Output to indicate that the core have been halted.
        core_halt : OUT STD_LOGIC;
        --! @brief Output to indicate that the core is actually executing code within an exception handling context.
        core_trap : OUT STD_LOGIC
    );
END ENTITY;

ARCHITECTURE behavioral OF core IS

    -- Since most signals are between a component and the core controller, they're sorted as this logic.
    --------------------------------------------------------------------------------------------------------
    -- Clock enabling 
    --------------------------------------------------------------------------------------------------------
    --! @brief Clock enable signal, used to synchronise the elements within the core without creating CDC.
    SIGNAL clk_en : STD_LOGIC;

    --------------------------------------------------------------------------------------------------------
    -- Registers files operations.
    --------------------------------------------------------------------------------------------------------
    --! @brief data to be written into the registers, if required (shared with CSR registers).
    SIGNAL reg_wdata : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief data to be read from the first port of the register file.
    SIGNAL reg_rdata1 : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief data to be read from the second port of the register file.
    SIGNAL reg_rdata2 : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief address of the wrote register.
    SIGNAL reg_wa : INTEGER RANGE 0 TO (REG_NB - 1);
    --! @brief register write enable
    SIGNAL reg_we : STD_LOGIC;
    --! @brief address of the read register on the port 1.
    SIGNAL reg_ra1 : INTEGER RANGE 0 TO (REG_NB - 1);
    --! @brief address of the read register on the port 2.
    SIGNAL reg_ra2 : INTEGER RANGE 0 TO (REG_NB - 1);

    --------------------------------------------------------------------------------------------------------
    -- CSR registers operations.
    --------------------------------------------------------------------------------------------------------
    --! @brief address of the wrote CSR register.
    SIGNAL csr_wa : csr_register;
    --! @brief CSR register write enable.
    SIGNAL csr_we : STD_LOGIC;
    --! @brief address of the read port of the CSR register file.
    SIGNAL csr_ra1 : csr_register;
    --! @brief data to be read from the CSR register file.
    SIGNAL csr_rdata1 : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief special output of the register to indicate if interrupts are enabled, or not. If '0', no interrupts / exceptions are going to be handled.
    SIGNAL csr_mie : STD_LOGIC;
    --! @brief special output of the register to indicate if an interrupt is pending, or not.
    SIGNAL csr_mip : STD_LOGIC;
    --! @brief Performance monitor, cycleL value
    SIGNAL csr_cyclel : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Performance monitor, cycleH value
    SIGNAL csr_cycleh : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Performance monitor, instrL value
    SIGNAL csr_instrl : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Performance monitor, instrH value
    SIGNAL csr_instrh : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

    --------------------------------------------------------------------------------------------------------
    -- ALU Argument selection.
    --------------------------------------------------------------------------------------------------------
    --! @brief ALU selection signal for the argument 1, which is CSR ('1') or register file ('0') (port 1).
    SIGNAL arg1_sel : STD_LOGIC;
    --! @brief ALU selection signal for the argument 2, which is Immediate ('1') or register file ('0') (port 2).
    SIGNAL arg2_sel : STD_LOGIC;

    --------------------------------------------------------------------------------------------------------
    -- Core controller data input
    --------------------------------------------------------------------------------------------------------
    --! @brief Core controller immediate input, tied to register file read port 2. 
    SIGNAL ctl_rdata2 : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

    --------------------------------------------------------------------------------------------------------
    -- ALU controls
    --------------------------------------------------------------------------------------------------------
    --! @brief ALU operation selection.
    SIGNAL alu_cmd : commands;
    --! @brief ALU status feedback, used for exception (overflows) or branch comparisons.
    SIGNAL alu_status : alu_feedback;
    --! @brief ALU output, to be written into CSR or the register file.
    SIGNAL alu_out : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief ALU arg 1, choosen from the mux controlled by arg1_sel.
    SIGNAL alu_arg1 : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief ALU arg 2, choosed from the mux controlled by arg2_sel.
    SIGNAL alu_arg2 : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);

    --------------------------------------------------------------------------------------------------------
    -- Decoder inputs
    --------------------------------------------------------------------------------------------------------
    --! @brief Decoder RS1 value, to the core controller.
    SIGNAL dec_rs1 : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    --! @brief Decoder RS2 value, to the core controller.
    SIGNAL dec_rs2 : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    --! @brief Decoder RD value, to the core controller.
    SIGNAL dec_rd : STD_LOGIC_VECTOR((XLEN / 8) DOWNTO 0);
    --! @brief Decoder Immediate value, to the core controller.
    SIGNAL dec_imm : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Decoder Address value, to the core controller.
    SIGNAL dec_addr : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief Decoder Opcode value, to the core controller.
    SIGNAL dec_opcode : instructions;
    --! @brief Decoder Illegal flag, to the core controller.
    SIGNAL dec_illegal : STD_LOGIC;
    --! @brief Decoder reset flag, asserted after a jump by the core_controller.
    SIGNAL dec_reset_cmd : STD_LOGIC;
    --! @brief Decoder RS1 value, sent to the decoder. (dec_reset_cmd AND nRST) to handle both reset cases.
    SIGNAL dec_reset : STD_LOGIC;

    --------------------------------------------------------------------------------------------------------
    -- Program counters controls
    --------------------------------------------------------------------------------------------------------
    --! @brief program counter load address.
    SIGNAL pc_waddr : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief program counter output address.
    SIGNAL pc_raddr : STD_LOGIC_VECTOR((XLEN - 1) DOWNTO 0);
    --! @brief program counter load command bit.
    SIGNAL pc_wen : STD_LOGIC;
    --! @brief program counter enable bit.
    SIGNAL pc_en : STD_LOGIC;
    --! @brief program counter overflow status.
    SIGNAL pc_overflow : STD_LOGIC;

    --------------------------------------------------------------------------------------------------------
    -- Memory related
    --------------------------------------------------------------------------------------------------------
    --! @brief memory request flag, used to select the muxes to redirect mem data into the standard data path.
    SIGNAL mem_request : STD_LOGIC;
    --! @brief memory read write, used to select the right mux for the current operation.
    SIGNAL mem_rw : STD_LOGIC;

    --------------------------------------------------------------------------------------------------------
    -- Pause requested
    --------------------------------------------------------------------------------------------------------
    --! @brief a pause is issued by the decoder when the instruction currently decoded is going to take more than a CPU cycle.
    SIGNAL pause : STD_LOGIC;

BEGIN

    -- Combinational logic
    -- Reset
    dec_reset <= nRST AND dec_reset_cmd;

    --! @brief Clock generator module, used to generate the clk_en signal.
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

    --! @brief Program counter module, used to generate addresses for the next instruction fetch cycle.
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
            enable => pause
        );

    --! @brief Decoder module, split instruction into smaller args.
    DEC1 : ENTITY work.decoder(behavioral)
        GENERIC MAP(
            XLEN => XLEN
        )
        PORT MAP(
            instruction => if_rdata,
            act_addr => pc_raddr,
            rs1 => dec_rs1,
            rs2 => dec_rs2,
            rd => dec_rd,
            imm => dec_imm,
            opcode => dec_opcode,
            illegal => dec_illegal,
            clock => clk,
            clock_en => clk_en,
            nRST => dec_reset,
            pause => pause,
            addr => dec_addr
        );

    --! @brief Core controller module. Decide active signals for each cycles.
    FSM1 : ENTITY work.core_controller(behavioral)
        GENERIC MAP(
            XLEN => XLEN,
            REG_NB => REG_NB,
            INT_ADDR => INT_ADDR
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
            pc_value => dec_addr,
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

    --! @brief General purpose register file.
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

    --! @brief CSR registers file.
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
            int_out => csr_mip,
            in_cycleh => csr_cycleh,
            in_cyclel => csr_cyclel,
            in_instrh => csr_instrh,
            in_instrl => csr_instrl
        );

    --! @brief ALU for the whole core.
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

    --! @brief Cycle counter module
    CYCLECNT : ENTITY work.counter32(rtl)
        GENERIC MAP(
            RESET => 0,
            INCREMENT => 1
        )
        PORT MAP(
            clock => clk,
            clock_en => clk_en,
            nRST => nRST,
            enable => '1',
            valueL => csr_cyclel,
            valueH => csr_cycleh
        );

    --! @brief Instruction counter.
    INSTRCNT : ENTITY work.counter32(rtl)
        GENERIC MAP(
            RESET => 0,
            INCREMENT => 1
        )
        PORT MAP(
            clock => clk,
            clock_en => clk_en,
            nRST => nRST,
            enable => pause,
            valueL => csr_instrl,
            valueH => csr_instrh
        );

    -- Static mappings
    if_addr <= pc_raddr;
    if_pause <= pause;
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