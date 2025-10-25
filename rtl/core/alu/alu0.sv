/*
 *  File :      rtl/core/alu/alu0.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file define the ALU0 module, which handle
 *              the most basic operations (ADD, SUB, AND, OR, XOR).
 */

`timescale 1ns / 1ps

import core_config_pkg::XLEN;
import core_config_pkg::alu_commands_t;
import core_config_pkg::REG_ADDR_W;

module alu0 (
    // Standard interface
    input   logic                                           clk,
    input   logic                                           rst_n,

    // Issuer interface
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       arg0,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       arg1,
    /* verilator lint_off UNUSEDSIGNAL */
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       addr,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       imm,
    /* verilator lint_off UNUSEDSIGNAL */
    input   alu_commands_t                                  cmd,
    input   logic   [(core_config_pkg::REG_ADDR_W - 1) : 0] i_rd,
    output  logic                                           busy,
    output  logic                                           i_error,

    // Commiter interface
    output  logic   [(core_config_pkg::XLEN - 1) : 0]       res,
    output  logic   [(core_config_pkg::REG_ADDR_W - 1) : 0] o_rd,
    output  logic                                           valid,
    output  logic                                           o_error,
    output  logic                                           req,
    input   logic                                           clear

    // Additionnal interface (optionnal)
    // None for this ALU.                  
);
    /*
     *  Storages types
     */
    logic   [(core_config_pkg::XLEN) : 0]           tmp_res; // One more bit to handle overflow.
    logic                                           unknown_instr;
    logic                                           int_req;
    logic                                           end_of_op;

    /*
     *  First, perform calculations (outputs from issuer are synchronous to clock).
     */
    always_comb begin

        unique case (cmd)

            core_config_pkg::c_ADD : begin
                // Calculation
                tmp_res         = {1'b0, arg0} + {1'b0, arg1};

                // Setting flags
                int_req         = 1'b1;
                unknown_instr   = 1'b0;
            end
            core_config_pkg::c_SUB : begin
                // Calculation
                tmp_res         = {1'b0, arg0} - {1'b0, arg1};

                // Setting flags
                int_req         = 1'b1;
                unknown_instr   = 1'b0;
            end 
            core_config_pkg::c_AND : begin
                // Calculation
                tmp_res         = {1'b0, arg0} & {1'b0, arg1};

                // Setting flags
                int_req         = 1'b1;
                unknown_instr   = 1'b0;
            end
            core_config_pkg::c_OR : begin
                // Calculation
                tmp_res         = {1'b0, arg0} | {1'b0, arg1};

                // Setting flags
                int_req         = 1'b1;
                unknown_instr   = 1'b0;
            end
            core_config_pkg::c_XOR : begin
                // Calculation
                tmp_res         = {1'b0, arg0} ^ {1'b0, arg1};

                // Setting flags
                int_req         = 1'b1;
                unknown_instr   = 1'b0;
            end
            default : begin
                // Calculation
                tmp_res         = 33'b0;

                // Setting flags
                int_req         = 1'b0;
                unknown_instr   = 1'b1;
            end
        endcase
    end

    /*
     *  Second, latching the first stage outputs before outputing them for the
     *  commiter stage.
     */
    always_ff @( posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            busy                <= 1'b0;
            res                 <= 32'b0;
            i_error             <= 1'b0;
            o_error             <= 1'b0;
            req                 <= 1'b0;
            o_rd                <= 5'b0;
            valid               <= 1'b0;
            end_of_op           <= 1'b0;

        end
        else if (clear && end_of_op) begin

            busy                <= 1'b0;
            res                 <= 32'b0;
            i_error             <= 1'b0;
            o_error             <= 1'b0;
            req                 <= 1'b0;
            o_rd                <= 5'b0;
            valid               <= 1'b0;
            end_of_op           <= 1'b0;

        end
        else begin

            busy                <= int_req;
            res                 <= tmp_res[(core_config_pkg::XLEN - 1) : 0];
            i_error             <= unknown_instr;
            o_error             <= tmp_res[(core_config_pkg::XLEN)];
            req                 <= 1'b0;
            o_rd                <= i_rd;
            valid               <= 1'b1;
            end_of_op           <= 1'b1;

        end
    end
endmodule
