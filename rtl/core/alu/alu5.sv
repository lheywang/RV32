/*
 *  File :      rtl/core/alu/alu5.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file define the ALU5 module, which is
 *              exclusively charged to handle the memory accesses.
 *              It perform timing and sign extensions if needed.
 */

`timescale 1ns / 1ps

import core_config_pkg::XLEN;
import core_config_pkg::alu_commands_t;

module alu5 (
    // Standard interface
    input logic clk,
    input logic rst_n,

    // Issuer interface
    input  logic          [      (core_config_pkg::XLEN - 1) : 0] arg0,
    input  logic          [      (core_config_pkg::XLEN - 1) : 0] arg1,
    input  logic          [      (core_config_pkg::XLEN - 1) : 0] imm,
    input  alu_commands_t                                         cmd,
    input  logic          [(core_config_pkg::REG_ADDR_W - 1) : 0] i_rd,
    output logic                                                  busy,
    output logic                                                  i_error,

    // Commiter interface
    output logic [      (core_config_pkg::XLEN - 1) : 0] res,
    output logic [(core_config_pkg::REG_ADDR_W - 1) : 0] o_rd,
    output logic                                         valid,
    output logic                                         o_error,
    output logic                                         req,
    input  logic                                         clear,

    // Additionnal interface for the memory (which perform IO trough this ALU and only THIS ALU.)
    output logic [      (core_config_pkg::XLEN - 1) : 0] mem_addr,
    output logic [((core_config_pkg::XLEN / 8) - 1) : 0] mem_byteen,
    output logic                                         mem_we,
    output logic                                         mem_req,
    output logic [      (core_config_pkg::XLEN - 1) : 0] mem_wdata,
    input  logic [      (core_config_pkg::XLEN - 1) : 0] mem_rdata,
    input  logic                                         mem_err
);

    typedef enum logic [1:0] {
        IDLE,
        REQ,
        WAIT,
        OUT
    } MEM_FSM;

    /*
     *  Storages types
     */
    logic   [      (core_config_pkg::XLEN - 1) : 0] tmp_res;
    logic                                           sext_req;
    logic   [      (core_config_pkg::XLEN - 1) : 0] address;
    logic   [      (core_config_pkg::XLEN - 1) : 0] data;
    logic   [      (core_config_pkg::XLEN - 1) : 0] data2;
    logic   [((core_config_pkg::XLEN / 8) - 1) : 0] bytes;
    logic                                           we;
    logic   [(core_config_pkg::REG_ADDR_W - 1) : 0] r_rd;
    logic                                           inp_req;
    logic   [                               15 : 0] half_val;
    logic   [                                7 : 0] byte_val;

    // Registered logic
    logic   [((core_config_pkg::XLEN / 8) - 1) : 0] r_bytes;
    logic   [      (core_config_pkg::XLEN - 1) : 0] r_address;
    logic   [      (core_config_pkg::XLEN - 1) : 0] r_data;
    logic   [      (core_config_pkg::XLEN - 1) : 0] r_data2;
    logic                                           r_sext_req;
    logic                                           r_we;
    logic                                           r_err;
    logic                                           r_inp_req;


    // FSM sync
    MEM_FSM                                         state;
    MEM_FSM                                         next_state;
    logic                                           unknown_instr;

    /*
     *  First, configure the different parameters of the request
     */
    always_comb begin

        tmp_res = arg0 + imm;
        address = {tmp_res[(core_config_pkg::XLEN-1) : 2], 2'b0};

        unique case (cmd)

            core_config_pkg::c_LB: begin
                // Calculation
                bytes         = 4'b0001 << tmp_res[1:0];
                sext_req      = 1'b1;
                we            = 1'b0;
                data          = 32'b0;
                inp_req       = 1'b1;

                // Setting flags
                unknown_instr = 1'b0;
            end
            core_config_pkg::c_LH: begin
                // Calculation
                bytes         = 4'b0011 << (tmp_res[1] * 2);
                sext_req      = 1'b1;
                we            = 1'b0;
                data          = 32'b0;
                inp_req       = 1'b1;

                // Setting flags
                unknown_instr = 0;
            end
            core_config_pkg::c_LW: begin
                // Calculation
                bytes         = 4'b1111;
                sext_req      = 1'b1;
                we            = 1'b0;
                data          = 32'b0;
                inp_req       = 1'b1;

                // Setting flags
                unknown_instr = 0;
            end
            core_config_pkg::c_LBU: begin
                // Calculation
                bytes         = 4'b0001 << tmp_res[1:0];
                sext_req      = 1'b0;
                we            = 1'b0;
                data          = 32'b0;
                inp_req       = 1'b1;

                // Setting flags
                unknown_instr = 1'b0;
            end
            core_config_pkg::c_LHU: begin
                // Calculation
                bytes         = 4'b0011 << (tmp_res[1] * 2);
                sext_req      = 1'b0;
                we            = 1'b0;
                data          = 32'b0;
                inp_req       = 1'b1;

                // Setting flags
                unknown_instr = 0;
            end
            core_config_pkg::c_SB: begin
                // Calculation
                bytes    = 4'b0001 << tmp_res[1:0];
                sext_req = 1'b0;
                we       = 1'b1;
                case (tmp_res[1:0])

                    2'b00:   data = {24'b0, arg1[7 : 0]};
                    2'b01:   data = {16'b0, arg1[7 : 0], 8'b0};
                    2'b10:   data = {8'b0, arg1[7 : 0], 16'b0};
                    2'b11:   data = {arg1[7 : 0], 24'b0};
                    default: data = 0;

                endcase
                inp_req       = 1'b0;

                // Setting flags
                unknown_instr = 1'b0;
            end
            core_config_pkg::c_SH: begin
                // Calculation
                bytes    = 4'b0011 << (tmp_res[1] * 2);
                sext_req = 1'b0;
                we       = 1'b1;

                if (tmp_res[1]) begin
                    data = {arg1[15 : 0], 16'b0};
                end else begin
                    data = {16'b0, arg1[15 : 0]};
                end
                inp_req       = 1'b0;

                // Setting flags
                unknown_instr = 1'b0;
            end
            core_config_pkg::c_SW: begin
                // Calculation
                bytes         = 4'b1111;
                sext_req      = 1'b0;
                we            = 1'b1;
                data          = arg1;
                inp_req       = 1'b0;

                // Setting flags
                unknown_instr = 1'b0;
            end
            default: begin
                // Calculation
                bytes         = 4'b0;
                sext_req      = 1'b0;
                we            = 1'b0;
                data          = 32'b0;
                inp_req       = 1'b0;

                // Setting flags
                unknown_instr = 1'b1;
            end
        endcase
    end

    /*
     *  Some sync logic to handle the FSM states and evolution
     */
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state      <= IDLE;
            r_bytes    <= 4'b0;
            r_address  <= 32'b0;
            r_sext_req <= 1'b0;
            r_we       <= 1'b0;
            r_data     <= 32'b0;
            r_rd       <= 5'b0;
            r_inp_req  <= 1'b0;
            r_data2    <= 32'b0;
            r_err      <= 1'b0;

        end else begin

            state <= next_state;

            if (state == IDLE) begin

                r_bytes    <= bytes;
                r_address  <= address;
                r_sext_req <= sext_req;
                r_we       <= we;
                r_data     <= data;
                r_rd       <= i_rd;
                r_inp_req  <= inp_req;

            end else if (state == WAIT) begin

                r_data2 <= data2;
                r_err   <= mem_err;

            end
        end
    end

    always_comb begin

        unique case (state)

            IDLE: begin
                if (!unknown_instr) begin

                    next_state = REQ;

                end else begin

                    next_state = IDLE;

                end
            end
            REQ:  next_state = WAIT;
            WAIT: next_state = OUT;
            OUT: begin
                if (clear) begin

                    next_state = IDLE;

                end else begin

                    next_state = OUT;

                end
            end

        endcase
    end

    always_comb begin

        unique case (state)

            IDLE: begin

                res        = 32'b0;
                o_rd       = 5'b0;
                valid      = 1'b0;
                o_error    = 1'b0;
                req        = 1'b0;
                busy       = 1'b0;

                mem_addr   = 32'b0;
                mem_we     = 1'b0;
                mem_req    = 1'b0;
                mem_wdata  = 32'b0;
                mem_byteen = 4'b0;

                half_val   = 16'b0;
                byte_val   = 8'b0;
                data2      = 32'b0;

            end
            REQ: begin

                res        = 32'b0;
                o_rd       = 5'b0;
                valid      = 1'b0;
                o_error    = 1'b0;
                req        = 1'b0;
                busy       = 1'b1;

                mem_addr   = r_address;
                mem_we     = r_we;
                mem_req    = 1'b1;
                mem_wdata  = r_data;
                mem_byteen = r_bytes;

                half_val   = 16'b0;
                byte_val   = 8'b0;
                data2      = 32'b0;

            end
            WAIT: begin

                res        = 32'b0;
                o_rd       = r_rd;
                valid      = 1'b0;
                o_error    = 1'b0;
                req        = 1'b0;
                busy       = 1'b1;

                mem_addr   = r_address;
                mem_we     = r_we;
                mem_req    = 1'b1;
                mem_wdata  = r_data;
                mem_byteen = r_bytes;

                if (r_inp_req) begin
                    data2 = mem_rdata;
                end else begin
                    data2 = 32'b0;
                end

                half_val = 16'b0;
                byte_val = 8'b0;

            end
            OUT: begin

                o_rd       = r_rd;
                valid      = 1'b1;
                o_error    = r_err;
                req        = 1'b0;
                busy       = 1'b1;

                mem_addr   = 32'b0;
                mem_we     = 1'b0;
                mem_req    = 1'b0;
                mem_wdata  = 32'b0;
                mem_byteen = 4'b0;

                half_val   = 16'b0;
                byte_val   = 8'b0;
                res        = 32'b0;
                data2      = 32'b0;

                case (r_bytes)

                    // LB
                    4'b1111: res = r_data2;

                    // LH
                    4'b0011: half_val = r_data2[15 : 0];
                    4'b1100: half_val = r_data2[31 : 16];

                    // LB
                    4'b0001: byte_val = r_data2[7 : 0];
                    4'b0010: byte_val = r_data2[15 : 8];
                    4'b0100: byte_val = r_data2[23 : 16];
                    4'b1000: byte_val = r_data2[31 : 24];

                    default: begin

                        half_val = 16'b0;
                        byte_val = 8'b0;
                        res      = 32'b0;

                    end

                endcase

                /* 
                 *  Performing sign extension of the data
                 */
                if (r_sext_req) begin

                    casez (r_bytes)
                        4'b1111: res = r_data2;  // full word
                        4'b0011, 4'b1100: res = {{16{half_val[15]}}, half_val};  // LH
                        4'b0001, 4'b0010, 4'b0100, 4'b1000:
                        res = {{24{byte_val[7]}}, byte_val};  // LB
                        default: res = 32'b0;
                    endcase

                end else begin

                    casez (r_bytes)
                        4'b1111:                            res = r_data2;  // LW
                        4'b0011, 4'b1100:                   res = {16'b0, half_val};  // LHU
                        4'b0001, 4'b0010, 4'b0100, 4'b1000: res = {24'b0, byte_val};  // LBU
                        default:                            res = 32'b0;
                    endcase
                end
            end
        endcase
    end

    assign i_error = unknown_instr;

endmodule
