`timescale 1ns / 1ps

package core_config_pkg;

    // Disabling unused param for verilator.
    /* verilator lint_off UNUSEDPARAM */
    // -------------------------------------------------------------------------
    // Clocks and resets
    // -------------------------------------------------------------------------
    parameter int REF_CLK_FREQ      = 200_000_000;       // 200 MHz
    parameter int CORE_CLK_FREQ     = 100_000_000;       // 100 MHz
    parameter int CORE_CLK_DUTY     = 50;                // Duty cycle in percentage
    parameter int RST_TICK_CNT    = 10;                // Number of reference clock cycles for reset

    // -------------------------------------------------------------------------
    // Data path widths
    // -------------------------------------------------------------------------
    parameter int XLEN              = 32;               // Register width (32-bit or 64-bit)
    parameter int REG_ADDR_W        = 5;                // Number of bits for register index (32 registers)
    parameter int REG_COUNT         = 32;               // Number of general-purpose registers

    parameter int MEM_ADDR_W        = XLEN;             // Address width for memory
    parameter int MEM_DATA_W        = XLEN;             // Data width
    
    // -------------------------------------------------------------------------
    // Instruction fetch parameters
    // -------------------------------------------------------------------------
    parameter int IF_LEN            = 32;               // Instruction length
    parameter int IF_INC            = 4;                // Offset between two memory addresses.
    parameter int IF_MAX_ADDR       = 32'h1000_3FFF;    // Maximal address possible.
    parameter int IF_BASE_ADDR      = 32'h1000_0000;    // Base address of IF stage.

    // -------------------------------------------------------------------------
    // Decoder internal settings
    // -------------------------------------------------------------------------
    // Define how to split an instruction
    parameter int OPCODE_MSB        = 6;
    parameter int OPCODE_LSB        = 0;
    parameter int RD_MSB            = 11;
    parameter int RD_LSB            = 7;
    parameter int FUNCT3_MSB        = 14;
    parameter int FUNCT3_LSB        = 12;
    parameter int RS1_MSB           = 19;
    parameter int RS1_LSB           = 15;
    parameter int RS2_MSB           = 24;
    parameter int RS2_LSB           = 20;
    parameter int FUNCT7_MSB        = 31;
    parameter int FUNCT7_LSB        = 25;

    // -------------------------------------------------------------------------
    // Performance counter configuration
    // -------------------------------------------------------------------------
    parameter int PERF_CNT_LEN      = 64;               // Performance counters are 64 bits anyway.
    parameter int PERF_CNT_INC      = 1;                // Increment on each tick

    // -------------------------------------------------------------------------
    // Automated parameters
    // -------------------------------------------------------------------------
    parameter int PERF_CNT_PORT     = (XLEN < 64) ? 1 : 0;

    // -------------------------------------------------------------------------
    // Enums
    // -------------------------------------------------------------------------
    // Handled opcodes
    typedef enum {
        i_NOP,

        i_LUI, i_AUIPC,

        i_ADDI, i_SLTI, i_SLTIU, i_XORI,
        i_ANDI, i_SLLI, i_SRLI, i_SRAI,
        i_ORI,

        i_ADD, i_SUB, i_SLL, i_SLT, i_SLTU,
        i_XOR, i_SRL, i_SRA, i_OR, i_AND,

        i_MUL, i_MULH, i_MULHU, i_MULHSU,
        i_DIV, i_DIVU, i_REM, i_REMU,

        i_FENCE,

        i_BEQ, i_BNE, i_BLT, i_BGE, 
        i_BLTU, i_BGEU,

        i_LB, i_LH, i_LW, i_LBU, i_LHU,
        i_SB, i_SH, i_SW,

        i_JAL, i_JALR,

        i_ECALL, i_EBREAK, i_MRET,

        i_CSRRW, i_CSRRS, i_CSRRC, i_CSRRWI,
        i_CSRRSI, i_CSRRCI
    } opcodes;

    typedef enum {
        DEC_U, DEC_I, DEC_R, DEC_B, DEC_S, DEC_J, DEC_NONE
    } decoders;

    // Re-enabling used parameters of Verilator.
    /* verilator lint_on UNUSEDPARAM */
endpackage
