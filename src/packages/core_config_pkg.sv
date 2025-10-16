`timescale 1ns / 1ps

package core_config_pkg;

    // Disabling unused param for verilator.
    /* verilator lint_off UNUSEDPARAM */
    // -------------------------------------------------------------------------
    // Clocks and resets
    // -------------------------------------------------------------------------
    parameter int REF_CLK_FREQ                  = 200_000_000;      // 200 MHz
    parameter int CORE_CLK_FREQ                 = 100_000_000;      // 100 MHz
    parameter int CORE_CLK_DUTY                 = 50;               // Duty cycle in percentage
    parameter int RST_TICK_CNT                  = 8;                // Number of reference clock cycles for reset

    // -------------------------------------------------------------------------
    // Data path widths
    // -------------------------------------------------------------------------
    parameter int XLEN                          = 32;               // Register width (32-bit or 64-bit)
    parameter int MEM_ADDR_W                    = XLEN;             // Address width for memory
    parameter int MEM_DATA_W                    = XLEN;             // Data width

    // -------------------------------------------------------------------------
    // Registers configuration
    // -------------------------------------------------------------------------
    parameter int REG_ADDR_W                    = 5;                // Number of bits for register index (32 registers)
    parameter int REG_COUNT                     = 32;               // Number of general-purpose registers
    parameter int CSR_ADDR_W                    = 12;               // Number of bits for register index (32 registers)
    parameter int CSR_COUNT                     = 23;               // Number of CSR registers

    // CSR Addresses
    
    // -------------------------------------------------------------------------
    // Instruction fetch parameters
    // -------------------------------------------------------------------------
    parameter int IF_LEN                        = 32;               // Instruction length
    parameter int IF_INC                        = 4;                // Offset between two memory addresses.
    parameter int IF_MAX_ADDR                   = 32'h1000_3FFF;    // Maximal address possible.
    parameter int IF_BASE_ADDR                  = 32'h1000_0000;    // Base address of IF stage.

    // -------------------------------------------------------------------------
    // Decoder internal settings
    // -------------------------------------------------------------------------
    // Define how to split an instruction
    parameter int OPCODE_MSB                    = 6;
    parameter int OPCODE_LSB                    = 0;
    parameter int RD_MSB                        = 11;
    parameter int RD_LSB                        = 7;
    parameter int FUNCT3_MSB                    = 14;
    parameter int FUNCT3_LSB                    = 12;
    parameter int RS1_MSB                       = 19;
    parameter int RS1_LSB                       = 15;
    parameter int RS2_MSB                       = 24;
    parameter int RS2_LSB                       = 20;
    parameter int FUNCT7_MSB                    = 31;
    parameter int FUNCT7_LSB                    = 25;

    // -------------------------------------------------------------------------
    // CSR internal settings
    // -------------------------------------------------------------------------
    /*
     * Writes masks
     */
    parameter logic [(XLEN - 1):0] CSR_WMASK [CSR_COUNT] = '{
        32'h00007188, // MSTATUS
        32'hFFFF0888, // MIE
        32'hFFFFFF01, // MTVEC
        32'hFFFFFFFF, // MSCRATCH
        32'hFFFFFFFE, // MEPC
        32'h8000001F, // MCAUSE
        32'h00000000, // MTVAL
        32'h00000000, // MIP
        32'h00000000, // VENDORID
        32'h00000000, // MARCHID
        32'h00000000, // MIMPID
        32'h00000000, // MHARTID
        32'h00000000, // MISA
        32'h00000000, // CYCLE
        32'h00000000, // CYCLEH
        32'h00000000, // INSTR
        32'h00000000, // INSTRH
        32'h00000000, // FLUSH
        32'h00000000, // FLUSHH
        32'h00000000, // WAIT
        32'h00000000, // WAITH
        32'h00000000, // DECOD
        32'h00000000  // DECODH
    };

    // -------------------------------------------------------------------------
    // ALUs configuration
    // -------------------------------------------------------------------------
    parameter logic [5:0] MAX_SHIFT_PER_CYCLE   = 8;              // Max bits shifts per cycles. Optimize for LUT / Speed

    // -------------------------------------------------------------------------
    // Performance counter configuration
    // -------------------------------------------------------------------------
    parameter int PERF_CNT_LEN                  = 64;               // Performance counters are 64 bits anyway.
    parameter int PERF_CNT_INC                  = 1;                // Increment on each tick

    // -------------------------------------------------------------------------
    // Enums
    // -------------------------------------------------------------------------
    /*
     *  List all of the known opcodes for the system.
     */
    typedef enum logic [6:0] {
        i_NOP,

        i_LUI,  i_AUIPC,

        i_ADDI, i_SLTI, i_SLTIU,    i_XORI,
        i_ANDI, i_SLLI, i_SRLI,     i_SRAI,
        i_ORI,

        i_ADD,  i_SUB,  i_SLL,      i_SLT,      i_SLTU,
        i_XOR,  i_SRL,  i_SRA,      i_OR,       i_AND,

        i_MUL,  i_MULH, i_MULHU,    i_MULHSU,
        i_DIV,  i_DIVU, i_REM,      i_REMU,

        i_FENCE,

        i_BEQ,  i_BNE,  i_BLT,      i_BGE, 
        i_BLTU, i_BGEU,

        i_LB,   i_LH,   i_LW,       i_LBU,      i_LHU,
        i_SB,   i_SH,   i_SW,

        i_JAL,  i_JALR,

        i_ECALL, 
        i_EBREAK, 
        i_MRET,

        i_CSRRW, i_CSRRS, i_CSRRC, i_CSRRWI,
        i_CSRRSI, i_CSRRCI
    } opcodes_t;

    typedef enum logic [2:0] {
        DEC_U, DEC_I, DEC_R, DEC_B, DEC_S, DEC_J, DEC_NONE
    } decoders_t;

    typedef enum logic [4:0] {
        r_MSTATUS, r_MIE, r_MTVEC, r_MSCRATCH, r_MEPC, r_MCAUSE,
        r_MTVAL, r_MIP, 
        
        r_MVENDORID, r_MARCHID, r_MIMPID, r_MHARTID, r_MISA,

        r_CYCLE, r_CYCLEH,  // CPU Cycle counters
        r_INSTR, r_INSTRH,  // CPU Commited instructions
        r_FLUSH, r_FLUSHH,  // CPU Pipeline flush counters
        r_WAIT, r_WAITH,    // CPU Number of waited cycles
        r_DECOD, r_DECODH,  // CPU Number of decoded instructions.

        r_NONE              // Must be the last
    } csr_t;

    typedef enum logic [6:0] {
        // ALU 0 (basic arithemetic)
        c_ADD, c_SUB,
        c_AND, c_OR,  c_XOR,

        // ALU 1 (branches and conditions)
        c_SLT, c_SLTU,
        c_BEQ, c_BNE, c_BLT, c_BGE, c_BLTU, c_BGEU,

        // ALU 2 & 3 (multiplications and divisions, multi cycles)
        c_SLL, c_SRL, c_SRA,
        c_MUL, 
        c_MULH, c_MULHSU, c_MULHU,
        c_DIV, c_DIVU,
        c_REM, c_REMU,

        // ALU 4 (CSR)
        c_CSRRW, c_CSRRS, c_CSRRC,

        // ALU 5 (Memory)
        c_SB, c_SH, c_SW,
        c_LB, c_LH, c_LW, c_LBU, c_LHU,

        // Common
        c_NONE
    } alu_commands_t;

    // -------------------------------------------------------------------------
    // Automated parameters
    // -------------------------------------------------------------------------
    parameter int PERF_CNT_PORT             = (XLEN < 64) ? 1 : 0;

    // Re-enabling used parameters of Verilator.
    /* verilator lint_on UNUSEDPARAM */
endpackage
