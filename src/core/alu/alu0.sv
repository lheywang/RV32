`timescale 1ns / 1ps

import core_config_pkg::XLEN;
import core_config_pkg::alu_commands_t;

/* 
 *  ALU 0 : Used for doing simple logic and maths 
        - Additions
        - Substractions
        - AND
        - OR
        - XOR
 */


module alu0 (
    // Standard interface
    input   logic                                           clk,
    input   logic                                           rst_n,

    // Issuer interface
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       arg0,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       arg1,
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
                tmp_res = {1'b0, arg0} + {1'b0, arg1};

                // Setting flags
                int_req = 1;
                unknown_instr = 0;
            end
            core_config_pkg::c_SUB : begin
                // Calculation
                tmp_res = {1'b0, arg0} - {1'b0, arg1};

                // Setting flags
                int_req = 1;
                unknown_instr = 0;
            end 
            core_config_pkg::c_AND : begin
                // Calculation
                tmp_res = {1'b0, arg0} & {1'b0, arg1};

                // Setting flags
                int_req = 1;
                unknown_instr = 0;
            end
            core_config_pkg::c_OR : begin
                // Calculation
                tmp_res = {1'b0, arg0} | {1'b0, arg1};

                // Setting flags
                int_req = 1;
                unknown_instr = 0;
            end
            core_config_pkg::c_XOR : begin
                // Calculation
                tmp_res = {1'b0, arg0} ^ {1'b0, arg1};

                // Setting flags
                int_req = 1;
                unknown_instr = 0;
            end
            default : begin
                // Calculation
                tmp_res = 0;

                // Setting flags
                int_req = 0;
                unknown_instr = 1;
            end
        endcase
    end

    /*
     *  Second, latching the first stage outputs before outputing them for the
     *  commiter stage.
     */
    always_ff @( posedge clk or negedge rst_n) begin

        if (!rst_n || (clear && end_of_op)) begin

            busy <= 0;
            res <= 0;
            i_error <= 0;
            o_error <= 0;
            req <= 0;
            o_rd <= 0;
            valid <= 0;
            end_of_op <= 0;

        end
        else begin

            busy <= int_req;
            res <= tmp_res[(core_config_pkg::XLEN - 1) : 0];
            i_error <= unknown_instr;
            o_error <= tmp_res[(core_config_pkg::XLEN)];
            req <= 0;
            o_rd <= i_rd;
            valid <= 1;
            end_of_op <= 1;

        end
    end



endmodule
