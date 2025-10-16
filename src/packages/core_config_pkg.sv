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
    `include "generated_opcodes.svh"
    `include "generated_decoders.svh"
    `include "generated_csr.svh"
    `include "generated_commands.svh"

    // -------------------------------------------------------------------------
    // Automated parameters
    // -------------------------------------------------------------------------
    parameter int PERF_CNT_PORT             = (XLEN < 64) ? 1 : 0;

    // Re-enabling used parameters of Verilator.
    /* verilator lint_on UNUSEDPARAM */
endpackage
