/*
 *  File :      rtl/core/alu/alu1.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file define the ALU1 module, which
 *              handle the logic for the branches.
 *              It compare two values, and compute the associated 
 *              address, if needed.
 *              It also expose two signals, in case the logic was correctly predicted, or not.
 */

`timescale 1ns / 1ps

import core_config_pkg::XLEN;
import core_config_pkg::alu_commands_t;

import core_config_pkg::IF_INC;
import core_config_pkg::IF_MRET_UCODE;
import core_config_pkg::IF_ECALL_UCODE;
import core_config_pkg::IF_EBREAK_UCODE;

module alu1 (
    input  logic                                                  clk,
    input  logic                                                  rst_n,
    input  logic          [      (core_config_pkg::XLEN - 1) : 0] arg0,
    input  logic          [      (core_config_pkg::XLEN - 1) : 0] arg1,
    input  logic          [      (core_config_pkg::XLEN - 1) : 0] addr,
    input  logic          [      (core_config_pkg::XLEN - 1) : 0] imm,
    input  alu_commands_t                                         cmd,
    input  logic          [(core_config_pkg::REG_ADDR_W - 1) : 0] i_rd,
    output logic                                                  busy,
    output logic                                                  i_error,
    input  logic                                                  predict_in,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] res,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] jmp,
    output logic          [(core_config_pkg::REG_ADDR_W - 1) : 0] o_rd,
    output logic                                                  valid,
    output logic                                                  o_error,
    output logic                                                  req,
    input  logic                                                  clear,
    output logic                                                  predict_ok,
    output logic                                                  mispredict
);
    /*
     *  Storages types
     */
    logic [(core_config_pkg::XLEN) : 0] tmp_res;  // One more bit to handle overflow.
    logic [(core_config_pkg::XLEN) : 0] tmp_jmp;  // One more bit to handle overflow.
    logic                               unknown_instr;
    logic                               int_req;
    logic                               act_needed;
    logic                               end_of_op;
    logic                               predict_value;

    /*
     *  Note : Two outputs are used here : jmp and res.
     *  
     *  Res :   Used to output the value that WILL be written into the register file
     *  Jmp :   Used to output the value to be written into the PC.
     *
     *  This enable the ability to perform single cycle JAL / JALR instructions and so on.
     */


    /*
     *  First, perform calculations (outputs from issuer are synchronous to clock).
     */
    always_comb begin

        unique case (cmd)

            /*
             *  SLTx instructions
             */
            core_config_pkg::c_SLT: begin
                // Calculation
                tmp_res       = ($signed(arg0) < $signed(arg1)) ? 33'b1 : 33'b0;
                tmp_jmp       = '0;

                // Setting flags
                act_needed    = 1'b0;
                predict_value = 1'b0;
                int_req       = 1'b1;
                unknown_instr = 1'b0;
            end
            core_config_pkg::c_SLTU: begin
                // Calculation
                tmp_res       = ($unsigned(arg0) < $unsigned(arg1)) ? 33'b1 : 33'b0;
                tmp_jmp       = '0;

                // Setting flags
                act_needed    = 1'b0;
                predict_value = 1'b0;
                int_req       = 1'b1;
                unknown_instr = 1'b0;
            end

            /*
             *  Branch conditions
             */
            core_config_pkg::c_BEQ: begin
                // Calculation
                tmp_jmp       = {1'b0, addr} + {1'b0, imm};
                tmp_res       = '0;

                // Setting flags
                act_needed    = (arg0 == arg1) ? 1'b1 : 1'b0;
                predict_value = predict_in;
                int_req       = 1'b1;
                unknown_instr = 1'b0;
            end
            core_config_pkg::c_BNE: begin
                // Calculation
                tmp_jmp       = {1'b0, addr} + {1'b0, imm};
                tmp_res       = '0;

                // Setting flags
                act_needed    = (arg0 == arg1) ? 1'b0 : 1'b1;
                predict_value = predict_in;
                int_req       = 1'b1;
                unknown_instr = 1'b0;
            end
            core_config_pkg::c_BGE: begin
                // Calculation
                tmp_jmp       = {1'b0, addr} + {1'b0, imm};
                tmp_res       = '0;

                // Setting flags
                act_needed    = ($signed(arg0) >= $signed(arg1)) ? 1'b1 : 1'b0;
                predict_value = predict_in;
                int_req       = 1'b1;
                unknown_instr = 1'b0;
            end
            core_config_pkg::c_BLT: begin
                // Calculation
                tmp_jmp       = {1'b0, addr} + {1'b0, imm};
                tmp_res       = '0;

                // Setting flags
                act_needed    = ($signed(arg0) < $signed(arg1)) ? 1'b1 : 1'b0;
                predict_value = predict_in;
                int_req       = 1'b1;
                unknown_instr = 1'b0;
            end
            core_config_pkg::c_BGEU: begin
                // Calculation
                tmp_jmp       = {1'b0, addr} + {1'b0, imm};
                tmp_res       = '0;

                // Setting flags
                act_needed    = ($unsigned(arg0) >= $unsigned(arg1)) ? 1'b1 : 1'b0;
                predict_value = predict_in;
                int_req       = 1'b1;
                unknown_instr = 1'b0;
            end
            core_config_pkg::c_BLTU: begin
                // Calculation
                tmp_jmp       = {1'b0, addr} + {1'b0, imm};
                tmp_res       = '0;

                // Setting flags
                act_needed    = ($unsigned(arg0) < $unsigned(arg1)) ? 1'b1 : 1'b0;
                predict_value = predict_in;
                int_req       = 1'b1;
                unknown_instr = 1'b0;
            end

            /*
             *  Jumps
             */
            core_config_pkg::c_JAL: begin
                // Calculation
                tmp_jmp       = {1'b0, addr} + {1'b0, IF_INC};
                tmp_res       = '0;

                // Setting flags
                act_needed    = 1'b0;  // always predicted
                predict_value = 1'b0;
                int_req       = 1'b1;
                unknown_instr = 1'b0;
            end
            core_config_pkg::c_JALR: begin
                // Calculation
                tmp_jmp       = ({1'b0, addr} + {1'b0, arg0}) & ~1;
                tmp_res       = {1'b0, addr} + IF_INC;

                // Setting flags
                act_needed    = 1'b1;  // always jumped
                predict_value = 1'b0;
                int_req       = 1'b1;
                unknown_instr = 1'b0;
            end
            /*
             *  Special instructions
             */
            core_config_pkg::c_EBREAK: begin
                // Calculation
                tmp_jmp       = {1'b0, IF_EBREAK_UCODE};
                tmp_res       = '0;

                // Setting flags
                act_needed    = 1'b1;  // always jumped
                predict_value = 1'b0;
                int_req       = 1'b1;
                unknown_instr = 1'b0;
            end
            core_config_pkg::c_ECALL: begin
                // Calculation
                tmp_jmp       = {1'b0, IF_ECALL_UCODE};
                tmp_res       = '0;

                // Setting flags
                act_needed    = 1'b1;  // always jumped
                predict_value = 1'b0;
                int_req       = 1'b1;
                unknown_instr = 1'b0;
            end
            core_config_pkg::c_MRET: begin
                // Calculation
                tmp_jmp       = {1'b0, IF_MRET_UCODE};
                tmp_res       = '0;

                // Setting flags
                act_needed    = 1'b1;  // always jumped
                predict_value = 1'b0;
                int_req       = 1'b1;
                unknown_instr = 1'b0;
            end
            /*
             *  Default case
             */
            default: begin
                // Calculation
                tmp_res       = 33'b0;
                tmp_jmp       = 33'b0;

                // Setting flags
                act_needed    = 1'b0;
                predict_value = 1'b0;
                int_req       = 1'b0;
                unknown_instr = 1'b1;
            end

        endcase
    end

    /*
     *  Second, latching the first stage outputs before outputing them for the
     *  commiter stage.
     */
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            busy      <= 1'b0;
            res       <= 32'b0;
            jmp       <= 32'b0;
            i_error   <= 1'b0;
            o_error   <= 1'b0;
            req       <= 1'b0;
            o_rd      <= 5'b0;
            valid     <= 1'b0;
            end_of_op <= 1'b0;

        end 
        else if (clear && end_of_op) begin

            busy       <= 1'b0;
            res        <= 32'b0;
            jmp        <= 32'b0;
            i_error    <= 1'b0;
            o_error    <= 1'b0;
            req        <= 1'b0;
            o_rd       <= 5'b0;
            valid      <= 1'b0;
            end_of_op  <= 1'b0;
            predict_ok <= 1'b0;
            mispredict <= 1'b0;

        end 
        else if (!unknown_instr) begin

            busy       <= int_req;
            res        <= tmp_res[(core_config_pkg::XLEN-1) : 0];
            jmp        <= tmp_jmp[(core_config_pkg::XLEN-1) : 0];
            i_error    <= 1'b0;
            o_error    <= tmp_res[(core_config_pkg::XLEN)] | tmp_jmp[(core_config_pkg::XLEN)];
            req        <= act_needed;
            o_rd       <= i_rd;
            valid      <= 1'b1;
            end_of_op  <= 1'b1;
            predict_ok <= ~(act_needed ^ predict_value);
            mispredict <= act_needed ^ predict_value;

        end 
        else begin

            busy       <= 1'b0;
            res        <= 32'b0;
            jmp        <= 32'b0;
            i_error    <= 1'b1; // Set to 1
            o_error    <= 1'b0;
            req        <= 1'b0;
            o_rd       <= 5'b0;
            valid      <= 1'b0;
            end_of_op  <= 1'b0;
            predict_ok <= 1'b0;
            mispredict <= 1'b0;

        end
    end

endmodule
