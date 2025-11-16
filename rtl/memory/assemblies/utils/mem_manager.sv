/*
 *  File :      rtl/memory/assemblies/utils/mem_manager.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      16/11/2025
 *  
 *  Brief :     This file define the memory manager, a block that trigger only if 
 *              the address match a specific pattern. Does also provide an
 *              isolator to the write bus in the disabled state.             
 */

`timescale 1ns / 1ps

import core_config_pkg::XLEN;

module mem_manager #(
    parameter int ADDR_BITS = 16,  // How many address bits to pass through
    parameter logic [(XLEN - ADDR_BITS - 1):0] ID_BITS = 16'hFFFF  // Address match pattern for upper bits
) (
    // Port A signals (read/write port)
    input logic [(XLEN - 1):0] data_in_a,
    output logic [(XLEN - 1):0] data_out_a,
    input logic [((XLEN / 4) - 1):0] byteen_in_a,
    output logic [((XLEN / 4) - 1):0] byteen_out_a,
    input logic [(XLEN - 1):0] addr_in_a,
    output logic [(ADDR_BITS - 1):0] addr_out_a,
    input logic aclr_in_a,
    output logic aclr_out_a,
    input logic enable_in_a,
    output logic enable_out_a,
    input logic rden_in_a,
    output logic rden_out_a,
    input logic wren_in_a,
    output logic wren_out_a,

    // Port B signals (typically read-only for instruction fetch)
    input logic [(XLEN - 1):0] data_in_b,
    output logic [(XLEN - 1):0] data_out_b,
    input logic [(XLEN - 1):0] addr_in_b,
    output logic [(ADDR_BITS - 1):0] addr_out_b,
    input logic rden_in_b,
    output logic rden_out_b
);

    // Internal enable signals for port A and B
    logic select_a;
    logic select_b;

    // Address decode logic - check if upper address bits match ID_BITS
    assign select_a = (addr_in_a[(XLEN-1):(ADDR_BITS)] == ID_BITS) && enable_in_a;
    assign select_b = (addr_in_b[(XLEN-1):(ADDR_BITS)] == ID_BITS);

    // Port A outputs - pass through lower address bits
    assign addr_out_a = addr_in_a[(ADDR_BITS-1):0];

    // Port A control signals - only enable when address matches
    assign enable_out_a = select_a;
    assign rden_out_a = select_a && rden_in_a;
    assign wren_out_a = select_a && wren_in_a;
    assign aclr_out_a = aclr_in_a;  // Pass through reset

    // Port A byte enables - only pass through when selected
    assign byteen_out_a = select_a ? byteen_in_a : '0;

    // Port A data - pass through write data, gate read data
    assign data_out_a = select_a ? data_in_a : '0;  // For OR-tree: output zeros when not selected

    // Port B outputs
    assign addr_out_b = addr_in_b[(ADDR_BITS-1):0];
    assign rden_out_b = select_b && rden_in_b;

    // Port B data - gate read data for OR-tree
    assign data_out_b = select_b ? data_in_b : '0;

endmodule
