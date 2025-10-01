library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.common.all;
use work.records.all;

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
        halt :      in              std_logic;
        exception : in              std_logic;

        -- instruction fetching
        if_addr :   out             std_logic_vector((XLEN - 1) downto 0);
        if_rdata :  in              std_logic_vector((XLEN - 1) downto 0);
        if_err :    in              std_logic;  
        if_aclr :   out             std_logic;

        -- external memory
        mem_addr :  out             std_logic_vector((XLEN - 1) downto 0);
        mem_we :    out             std_logic;  
        mem_req :   out             std_logic;
        mem_wdata : out             std_logic_vector((XLEN - 1) downto 0);
        mem_byten : out             std_logic_vector(((XLEN / 8) - 1) downto 0);
        mem_rdata : in              std_logic_vector((XLEN - 1) downto 0);
        mem_err :   in              std_logic;

        -- Interruptions
        int_vec :   in              std_logic_vector((XLEN - 1) downto 0);

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

        -- Internals signals linked to CSR registers data IO and selection
        signal csr_wa :             csr_register;
        signal csr_we :             std_logic;
        signal csr_ra1 :            csr_register;
        signal csr_rdata1 :         std_logic_vector((XLEN - 1) downto 0);
        signal csr_mie :            std_logic;
        signal csr_mip :            std_logic;

        -- Signals for choosing the input elements
        signal arg1_sel :           std_logic;
        signal arg2_sel :           std_logic;
        
        -- Controller data IO
        signal ctl_rdata2 :         std_logic_vector((XLEN - 1) downto 0);

        -- alu signals
        signal alu_cmd :            commands;
        signal alu_status :         alu_feedback;
        signal alu_out :            std_logic_vector((XLEN - 1) downto 0);
        signal alu_arg1 :           std_logic_vector((XLEN - 1) downto 0);
        signal alu_arg2 :           std_logic_vector((XLEN - 1) downto 0);

        -- decoders signals
        signal dec_rs1 :            std_logic_vector((XLEN / 8) downto 0);
        signal dec_rs2 :            std_logic_vector((XLEN / 8) downto 0);
        signal dec_rd :             std_logic_vector((XLEN / 8) downto 0);
        signal dec_imm :            std_logic_vector((XLEN - 1) downto 0);
        signal dec_opcode :         instructions;
        signal dec_illegal :        std_logic;
        signal dec_reset_cmd :      std_logic;
        signal dec_reset :          std_logic;

        -- program counter
        signal pc_waddr :           std_logic_vector((XLEN - 1) downto 0);
        signal pc_raddr :           std_logic_vector((XLEN - 1) downto 0);
        signal pc_wen :             std_logic;
        signal pc_en :              std_logic;
        signal pc_overflow :        std_logic;

        -- Memory
        signal mem_request :        std_logic;
        signal mem_rw :             std_logic;

        -- Fifo output to decoder
        signal fifo_out :           std_logic_vector((XLEN - 1) downto 0);
        signal r_fifo_write :       std_logic;
        signal r0_fifo_read :       std_logic;
        signal r1_fifo_read :       std_logic;
        signal r_fifo_read :        std_logic;

    begin

        -- registration process
        P0 : process(clk, nRST)
        begin
            if (nRST = '0') then

                r_fifo_write <= '0';
                r0_fifo_read <= '0';
                r1_fifo_read <= '0';

            elsif rising_edge(clk) and (clk_en = '1') then

                r_fifo_write <= pc_en;
                r1_fifo_read <= r0_fifo_read;
                r0_fifo_read <= '1';

            end if;
        end process;

        -- Combinational logic
        -- Reset
        dec_reset           <= nRST and dec_reset_cmd;
        r_fifo_read         <= pc_en and r1_fifo_read;

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

        -- Instruction FIFO
        FIFO1 : entity work.fifo(rtl)
        generic map (
            XLEN            => XLEN,
            DEPTH           => 8 -- arbitrary value to 8, which shall be more than enough
        )
        port map (
            clk             => clk,
            clk_en          => clk_en,
            nRST            => nRST,
            wr_en           => r_fifo_write,
            rd_en           => r_fifo_read,
            din             => if_rdata,
            dout            => fifo_out
        );

        -- Decoder
        DEC1 : entity work.decoder(behavioral)
        generic map (
            XLEN            =>  XLEN
        )
        port map (
            instruction     =>  fifo_out,
            rs1             =>  dec_rs1,
            rs2             =>  dec_rs2,
            rd              =>  dec_rd,
            imm             =>  dec_imm,
            opcode          =>  dec_opcode,
            illegal         =>  dec_illegal,
            clock           =>  clk,
            clock_en        =>  clk_en,
            nRST            =>  dec_reset,
            shift_en        =>  pc_en
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
            dec_reset       =>  dec_reset_cmd,
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
            reg_rs1_in      =>  reg_rdata2,
            reg_rs2_out     =>  ctl_rdata2,
            arg1_sel        =>  arg1_sel,
            arg2_sel        =>  arg2_sel,
            csr_we          =>  csr_we,
            csr_wa          =>  csr_wa,
            csr_ra1         =>  csr_ra1,
            csr_mie         =>  csr_mie,
            csr_mip         =>  csr_mip,
            alu_cmd         =>  alu_cmd,
            alu_status      =>  alu_status,
            if_err          =>  if_err,
            if_aclr         =>  if_aclr,
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

        -- CSR file
        -- Register file
        CSR1 : entity work.csr_registers(rtl)
        generic map (
            XLEN            =>  XLEN
        )
        port map (
            clock           =>  clk,
            clock_en        =>  clk_en,
            nRST            =>  nRST,
            we              =>  csr_we,
            wa              =>  csr_wa,
            wd              =>  reg_wdata,      -- Shared output bus with the ALU output
            ra1             =>  csr_ra1,
            rd1             =>  csr_rdata1,
            int_vec         =>  int_vec,
            int_en          =>  csr_mie,
            int_out         =>  csr_mip
        );

        -- Arithmetic and Logic unit
        ALU1 : entity work.alu(behavioral)
        generic map (
            XLEN            =>  XLEN
        )
        port map (
            arg1            =>  alu_arg1,
            arg2            =>  alu_arg2,
            result          =>  alu_out,
            command         =>  alu_cmd,
            status          =>  alu_status
        );

        -- Static mappings
        if_addr             <=  pc_raddr;
        mem_req             <=  mem_request;
        mem_we              <=  mem_rw;

        -- Muxes
        reg_wdata           <= mem_rdata when (mem_request = '1') and (mem_rw = '0') else alu_out;
        mem_wdata           <= alu_arg1 when (mem_request = '1') and (mem_rw = '1') else (others => '0');

        alu_arg1            <= csr_rdata1 when (arg1_sel = '1') else reg_rdata1;
        alu_arg2            <= ctl_rdata2 when (arg2_sel = '1') else reg_rdata2;  

    end architecture;