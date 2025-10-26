/*
 *  File :      rtl/core/commiter.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file define the commit module, the one who's
 *              charged to handle the ALU outputs and the registers write-back.
 *              It also expose an address load bus, in case a branch instruction
 *              was mispredicted, and we need to flush the pipeline.
 */
`timescale 1ns / 1ps

import core_config_pkg::XLEN;
import core_config_pkg::IF_TRAP_UCODE;

module commiter (

    // Standard interface
    input logic clk,
    input logic rst_n,

    // ALU interfaces
    input  logic                                         alu0_error,
    input  logic                                         alu0_valid,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic                                         alu0_req,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [      (core_config_pkg::XLEN - 1) : 0] alu0_res,
    input  logic [(core_config_pkg::REG_ADDR_W - 1) : 0] alu0_rd,
    output logic                                         alu0_clear,
    input  logic                                         alu1_error,
    input  logic                                         alu1_valid,
    input  logic                                         alu1_req,
    input  logic [      (core_config_pkg::XLEN - 1) : 0] alu1_res,
    input  logic [(core_config_pkg::REG_ADDR_W - 1) : 0] alu1_rd,
    output logic                                         alu1_clear,
    input  logic                                         alu2_error,
    input  logic                                         alu2_valid,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic                                         alu2_req,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [      (core_config_pkg::XLEN - 1) : 0] alu2_res,
    input  logic [(core_config_pkg::REG_ADDR_W - 1) : 0] alu2_rd,
    output logic                                         alu2_clear,
    input  logic                                         alu3_error,
    input  logic                                         alu3_valid,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic                                         alu3_req,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [      (core_config_pkg::XLEN - 1) : 0] alu3_res,
    input  logic [(core_config_pkg::REG_ADDR_W - 1) : 0] alu3_rd,
    output logic                                         alu3_clear,
    input  logic                                         alu4_error,
    input  logic                                         alu4_valid,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic                                         alu4_req,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [      (core_config_pkg::XLEN - 1) : 0] alu4_res,
    input  logic [(core_config_pkg::REG_ADDR_W - 1) : 0] alu4_rd,
    output logic                                         alu4_clear,
    input  logic                                         alu5_error,
    input  logic                                         alu5_valid,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic                                         alu5_req,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [      (core_config_pkg::XLEN - 1) : 0] alu5_res,
    input  logic [(core_config_pkg::REG_ADDR_W - 1) : 0] alu5_rd,
    output logic                                         alu5_clear,

    // Register file interface
    output logic [      (core_config_pkg::XLEN - 1) : 0] reg_data,
    output logic [(core_config_pkg::REG_ADDR_W - 1) : 0] reg_addr,
    output logic                                         reg_we,

    // Program counter overwrite
    output logic [(core_config_pkg::XLEN - 1) : 0] pc_value,
    output logic                                   pc_enable,
    output logic                                   pc_we,

    // General purpose IO
    input  logic halt_needed,
    output logic issuer_flush,
    output logic commit_err
);

    /*
     *  Defining the active_ALU type
     */
    typedef enum logic [2:0] {
        ALU0,
        ALU1,
        ALU2,
        ALU3,
        ALU4,
        ALU5,
        NONE,
        ALL
    } alu_t;

    /*
     *  Storages
     */
    alu_t last_active_alu;
    alu_t active_alu;

    /*
     *  First, some combinational logic to choose the ALU that will get the right
     *  to output it's data.
     *
     *  Note :  The ALU aren't ordered, that's because we prioritize the ALU's 
     *          with the most critical functions. First, the branches conditions, 
     *          because they could influes on the program counter outputs !
     *          Then, the long operations (MUL, DIV...) to ensure we liberate them
     *          the fastest as possible. And then, the remaining ALUs.
     */
    always_comb begin

        if (halt_needed) begin

            active_alu   = ALL;

            reg_data     = '0;
            reg_addr     = '0;
            reg_we       = 1'b0;

            pc_value     = core_config_pkg::IF_TRAP_UCODE;
            pc_we        = 1'b1;
            issuer_flush = 1'b1;

        end else begin

            if (alu1_valid) begin

                active_alu   = ALU1;

                reg_data     = (alu1_req) ? '0 : alu1_res;
                reg_addr     = (alu1_req) ? '0 : alu1_rd;
                reg_we       = (alu1_req) ? 1'b0 : 1'b1;

                pc_value     = (alu1_req) ? alu1_res : '0;
                pc_we        = (alu1_req) ? 1'b1 : 1'b0;
                issuer_flush = (alu1_req) ? 1'b1 : 1'b0;

            end else if (alu2_valid) begin

                active_alu   = ALU2;

                reg_data     = alu2_res;
                reg_addr     = alu2_rd;
                reg_we       = 1'b1;

                pc_value     = '0;
                pc_we        = 1'b0;
                issuer_flush = 1'b0;

            end else if (alu3_valid) begin

                active_alu   = ALU3;

                reg_data     = alu3_res;
                reg_addr     = alu3_rd;
                reg_we       = 1'b1;

                pc_value     = '0;
                pc_we        = 1'b0;
                issuer_flush = 1'b0;

            end else if (alu5_valid) begin

                active_alu   = ALU5;

                reg_data     = alu5_res;
                reg_addr     = alu5_rd;
                reg_we       = 1'b1;

                pc_value     = '0;
                pc_we        = 1'b0;
                issuer_flush = 1'b0;

            end else if (alu4_valid) begin

                active_alu   = ALU4;

                reg_data     = alu4_res;
                reg_addr     = alu4_rd;
                reg_we       = 1'b1;

                pc_value     = '0;
                pc_we        = 1'b0;
                issuer_flush = 1'b0;

            end else if (alu0_valid) begin

                active_alu   = ALU0;

                reg_data     = alu0_res;
                reg_addr     = alu0_rd;
                reg_we       = 1'b1;

                pc_value     = '0;
                pc_we        = 1'b0;
                issuer_flush = 1'b0;

            end else begin

                active_alu   = NONE;

                reg_data     = '0;
                reg_addr     = '0;
                reg_we       = 1'b0;

                pc_value     = '0;
                pc_we        = 1'b0;
                issuer_flush = 1'b0;

            end
        end
    end

    /*
     *  Some synchronous logic to handle the clear signal
     *  to reset the different ALUs.
     */
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            last_active_alu <= NONE;

        end else begin

            last_active_alu <= active_alu;

        end
    end

    /*
     *  Some comb logic to just handle with clear signal is active.
     *  Enable the right ALU, or, in case of ALL, we flush all of them.
     */
    always_comb begin

        alu0_clear = 1'b0;
        alu1_clear = 1'b0;
        alu2_clear = 1'b0;
        alu3_clear = 1'b0;
        alu4_clear = 1'b0;
        alu5_clear = 1'b0;

        unique case (last_active_alu)

            ALU0: alu0_clear = 1'b1;
            ALU1: alu1_clear = 1'b1;
            ALU2: alu2_clear = 1'b1;
            ALU3: alu3_clear = 1'b1;
            ALU4: alu4_clear = 1'b1;
            ALU5: alu5_clear = 1'b1;
            ALL: begin

                alu0_clear = 1'b1;
                alu1_clear = 1'b1;
                alu2_clear = 1'b1;
                alu3_clear = 1'b1;
                alu4_clear = 1'b1;
                alu5_clear = 1'b1;

            end
            default: ;

        endcase
    end

    // Output the combined output logic, we probably won't handle it.
    assign commit_err = |{alu0_error, alu1_error, alu2_error, alu3_error, alu4_error, alu5_error};
    assign pc_enable  = 1'b1;

endmodule
