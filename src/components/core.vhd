library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.common.all;

entity core is 
    generic ( 
        XLEN :                      integer := 32;
        REG_NB :                    integer := 32;
        INPUT_FREQ :                integer := 200_000_000;
        RESET_ADDR :                integer := 0;
        INT_ADDR :                  integer := 0;
        ERR_ADDR :                  integer := 0
    );
    port (
        -- global IOs
        clk :       in              std_logic;
        nRST :      in              std_logic;
        irq :       in              std_logic;
        halt :      in              std_logic;
        exception : in              std_logic;

        -- instruction fetching
        if_addr :   out             std_logic_vector((XLEN - 1) downto 0);
        if_rdata :  in              std_logic_vector((XLEN - 1) downto 0);
        if_err :    in              std_logic;  

        -- external memory
        mem_addr :  out             std_logic_vector((XLEN - 1) downto 0);
        mem_we :    out             std_logic;  
        mem_req :   out             std_logic;
        mem_wdata : out             std_logic_vector((XLEN - 1) downto 0);
        mem_byten : out             std_logic_vector(((XLEN / 8) - 1) downto 0);
        mem_rdata : in              std_logic_vector((XLEN - 1) downto 0);
        mem_err :   in              std_logic;

        -- debug / control
        core_halt : out             std_logic;
        core_trap : out             std_logic
    );
end entity;

architecture behavioral of core is

        -- Clocking control
        signal clk_en :             std_logic;

        -- Internals signals linked to registers data IO and selection
        signal reg_wdata :          std_logic_vector((XLEN - 1) downto 0);
        signal reg_rdata1 :         std_logic_vector((XLEN - 1) downto 0);
        signal reg_rdata2 :         std_logic_vector((XLEN - 1) downto 0);
        signal reg_wa :             integer range 0 to (REG_NB-1);
        signal reg_we :             std_logic;
        signal reg_ra1 :            integer range 0 to (REG_NB-1);
        signal reg_ra2 :            integer range 0 to (REG_NB-1);

        -- alu signals
        signal alu_cmd :            commands;
        signal alu_out_en :         std_logic;
        signal alu_zero :           std_logic;
        signal alu_overflow :       std_logic;
        signal alu_beq :            std_logic;
        signal alu_bne :            std_logic;
        signal alu_blt :            std_logic;
        signal alu_bge :            std_logic;
        signal alu_bltu :           std_logic;
        signal alu_bgeu :           std_logic;
        signal alu_out :            std_logic_vector((XLEN - 1) downto 0);

        -- decoders signals
        signal dec_rs1 :            std_logic_vector((XLEN / 8) downto 0);
        signal dec_rs2 :            std_logic_vector((XLEN / 8) downto 0);
        signal dec_rd :             std_logic_vector((XLEN / 8) downto 0);
        signal dec_imm :            std_logic_vector((XLEN - 1) downto 0);
        signal dec_opcode :         instructions;
        signal dec_illegal :        std_logic;

        -- program counter
        signal pc_waddr :           std_logic_vector((XLEN - 1) downto 0);
        signal pc_raddr :           std_logic_vector((XLEN - 1) downto 0);
        signal pc_wen :             std_logic;
        signal pc_en :              std_logic;
        signal pc_overflow :        std_logic;

        -- Memory
        signal mem_request :        std_logic;
        signal mem_rw :             std_logic;

    begin

        -- Clock generator
        CLK1 : entity work.clock(behavioral)
        generic map (
            INPUT_FREQ      =>  INPUT_FREQ,
            OUTPUT_FREQ     =>  (INPUT_FREQ / 2),
            DUTY_CYCLE      =>  50
        )
        port map (
            clk             =>  clk,
            nRST            =>  nRST,
            clk_en          =>  clk_en
        );

        -- Program counter
        PC1 : entity work.pcounter(behavioral)
        generic map (
            XLEN            =>  XLEN,
            RESET_ADDR      =>  RESET_ADDR,
            INCREMENT       =>  (XLEN / 8)
        )
        port map (
            address         =>  pc_raddr,
            address_in      =>  pc_waddr,
            nOVER           =>  pc_overflow,
            clock           =>  clk,
            clock_en        =>  clk_en,
            nRST            =>  nRST,
            load            =>  pc_wen,
            enable          =>  pc_en
        );

        -- Decoder
        DEC1 : entity work.decoder(behavioral)
        generic map (
            XLEN            =>  XLEN
        )
        port map (
            instruction     =>  if_rdata,
            rs1             =>  dec_rs1,
            rs2             =>  dec_rs2,
            rd              =>  dec_rd,
            imm             =>  dec_imm,
            opcode          =>  dec_opcode,
            illegal         =>  dec_illegal,
            clock           =>  clk,
            clock_en        =>  clk_en,
            nRST            =>  nRST
        );

        -- Controller / FSM
        FSM1 : entity work.core_controller(behavioral)
        generic map (
            XLEN            =>  XLEN,
            REG_NB          =>  REG_NB,
            INT_ADDR        =>  INT_ADDR,
            EXP_ADDR        =>  ERR_ADDR
        )
        port map (
            clock           =>  clk,
            clock_en        =>  clk_en,
            nRST            =>  nRST,
            dec_rs1         =>  dec_rs1,
            dec_rs2         =>  dec_rs2,
            dec_rd          =>  dec_rd,
            dec_imm         =>  dec_imm,
            dec_opcode      =>  dec_opcode,
            dec_illegal     =>  dec_illegal,
            mem_addr        =>  mem_addr,
            mem_byteen      =>  mem_byten,
            mem_we          =>  mem_rw,
            mem_req         =>  mem_request,
            mem_addrerr     =>  mem_err,
            pc_value        =>  pc_raddr,
            pc_overflow     =>  pc_overflow,
            pc_enable       =>  pc_en,
            pc_wren         =>  pc_wen,
            pc_loadvalue    =>  pc_waddr,
            reg_we          =>  reg_we,
            reg_wa          =>  reg_wa,
            reg_ra1         =>  reg_ra1,
            reg_ra2         =>  reg_ra2,
            reg_rs1_in      =>  reg_rdata1,
            reg_rs2_out     =>  reg_rdata2,
            alu_cmd         =>  alu_cmd,
            alu_out_en      =>  alu_out_en,
            alu_zero        =>  alu_zero,
            alu_overflow    =>  alu_overflow,
            alu_beq         =>  alu_beq,
            alu_bne         =>  alu_bne,
            alu_blt         =>  alu_blt,
            alu_bge         =>  alu_bge,
            alu_bltu        =>  alu_bltu,
            alu_bgeu        =>  alu_bgeu,
            if_err          =>  if_err,
            ctl_interrupt   =>  irq,
            ctl_exception   =>  exception,
            ctl_halt        =>  halt,
            excep_occured   =>  core_trap,
            core_halt       =>  core_halt
        );

        -- Register file
        REGS1 : entity work.register_file(rtl)
        generic map (
            XLEN            =>  XLEN,
            REG_NB          =>  REG_NB
        )
        port map (
            clock           =>  clk,
            clock_en        =>  clk_en,
            nRST            =>  nRST,
            we              =>  reg_we,
            wa              =>  reg_wa,
            wd              =>  reg_wdata,
            ra1             =>  reg_ra1,
            ra2             =>  reg_ra2,
            rd1             =>  reg_rdata1,
            rd2             =>  reg_rdata2
        );

        -- Arithmetic and Logic unit
        ALU1 : entity work.alu(behavioral)
        generic map (
            XLEN            =>  XLEN
        )
        port map (
            arg1            =>  reg_rdata1,
            arg2            =>  reg_rdata2,
            result          =>  alu_out,
            command         =>  alu_cmd,
            outen           =>  alu_out_en,
            zero            =>  alu_zero,
            overflow        =>  alu_overflow,
            beq             =>  alu_beq,
            bne             =>  alu_bne,
            blt             =>  alu_blt,
            bge             =>  alu_bge,
            bltu            =>  alu_bltu,
            bgeu            =>  alu_bgeu
        );

        -- Static mappings
        if_addr             <=  pc_raddr;
        mem_req             <=  mem_request;
        mem_we              <=  mem_rw;

        reg_wdata           <= mem_rdata when (mem_request = '1') and (mem_rw = '0') else 
                               alu_out;
        mem_wdata           <= reg_rdata1 when (mem_request = '1') and (mem_rw = '1') else
                               (others => '0');

    end architecture;