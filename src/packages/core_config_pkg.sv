`timescale 1ns / 1ps

package core_config_pkg;

    // -------------------------------------------------------------------------
    // Data path widths
    // -------------------------------------------------------------------------
    parameter int XLEN              = 32;               // Register width (32-bit or 64-bit)
    // parameter int REG_ADDR_W        = 5;                // Number of bits for register index (32 registers)
    // parameter int REG_COUNT         = 32;               // Number of general-purpose registers

    // -------------------------------------------------------------------------
    // Instruction fetch parameters
    // -------------------------------------------------------------------------
    // parameter int IF_LEN            = 32;               // Instruction length
    parameter int IF_INC            = 4;                // Offset between two memory addresses.
    parameter int IF_MAX_ADDR       = 32'h1000_3FFF;    // Maximal address possible.
    parameter int IF_BASE_ADDR      = 32'h1000_0000;    // Base address of IF stage.

    // -------------------------------------------------------------------------
    // Memory configuration
    // -------------------------------------------------------------------------
    // parameter int MEM_ADDR_W        = XLEN;             // Address width for memory
    // parameter int MEM_DATA_W        = XLEN;             // Data width

    // -------------------------------------------------------------------------
    // Misc / constants
    // -------------------------------------------------------------------------
    // localparam int INVALID_REG      = 0;                // Reserved reg index (x0)
    // localparam int DEFAULT_PC       = 32'h0000_0000;

endpackage
