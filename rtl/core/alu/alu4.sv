/*
 *  File :      rtl/core/alu/alu4.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file define the ALU4 module, which handle the
 *              CSR registers accesses. It handle the swaps and masks
 *              required for theses operations.
 */

`timescale 1ns / 1ps

import core_config_pkg::XLEN;
import core_config_pkg::alu_commands_t;
import core_config_pkg::CSR_ADDR_W;
import core_config_pkg::REG_ADDR_W;

module alu4 (
    input  logic                                                  clk,
    input  logic                                                  rst_n,
    input  logic          [      (core_config_pkg::XLEN - 1) : 0] arg0,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic          [      (core_config_pkg::XLEN - 1) : 0] arg1,
    input  logic          [      (core_config_pkg::XLEN - 1) : 0] addr,
    input  logic          [      (core_config_pkg::XLEN - 1) : 0] imm,
    /* verilator lint_on UNUSEDSIGNAL */
    input  alu_commands_t                                         cmd,
    input  logic          [(core_config_pkg::REG_ADDR_W - 1) : 0] i_rd,
    output logic                                                  busy,
    output logic                                                  i_error,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] res,
    output logic          [(core_config_pkg::REG_ADDR_W - 1) : 0] o_rd,
    output logic                                                  valid,
    output logic                                                  o_error,
    output logic                                                  req,
    input  logic                                                  clear,
    output logic          [(core_config_pkg::CSR_ADDR_W - 1) : 0] csr_wa,
    output logic          [(core_config_pkg::CSR_ADDR_W - 1) : 0] csr_ra,
    output logic                                                  csr_we,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] csr_wd,
    input  logic          [      (core_config_pkg::XLEN - 1) : 0] csr_rd,
    input  logic                                                  csr_err

);
    /*
     *  Custom types
     */
    typedef enum logic [2:0] {
        IDLE,
        READ,
        WRITE
    } state_t;

    /*
     *  Storage registers
     */
    // FSM status
    state_t state;
    state_t next_state;

    // Access mode
    logic write, next_write;
    logic set, next_set;
    logic clearb, next_clearb;
    logic [(core_config_pkg::XLEN - 1) : 0] value;
    logic [(core_config_pkg::XLEN - 1) : 0] next_value;
    logic [(core_config_pkg::XLEN - 1) : 0] readback;
    logic [(core_config_pkg::CSR_ADDR_W - 1) : 0] address;
    logic [(core_config_pkg::CSR_ADDR_W - 1) : 0] next_address;

    // Data transfer
    logic [(core_config_pkg::REG_ADDR_W - 1) : 0] r_rd, next_rd;

    // Identification
    logic unknown_instr;


    /*
     *  First, a comb block to identify the instruction and output 
     *  pre-control signals
     */
    always_comb begin

        unique case (cmd)

            core_config_pkg::c_CSRRW: begin

                next_write    = 1'b1;
                next_set      = 1'b0;
                next_clearb   = 1'b0;
                next_address  = imm[(core_config_pkg::CSR_ADDR_W-1) : 0];
                next_value    = arg0;
                next_rd       = i_rd;
                unknown_instr = 1'b0;

            end

            core_config_pkg::c_CSRRS: begin

                next_write    = 1'b0;
                next_set      = 1'b1;
                next_clearb   = 1'b0;
                next_address  = imm[(core_config_pkg::CSR_ADDR_W-1) : 0];
                next_value    = arg0;
                next_rd       = i_rd;
                unknown_instr = 1'b0;

            end

            core_config_pkg::c_CSRRC: begin

                next_write    = 1'b0;
                next_set      = 1'b0;
                next_clearb   = 1'b1;
                next_address  = imm[(core_config_pkg::CSR_ADDR_W-1) : 0];
                next_value    = ~arg0;  // Already performing the NOT operation here !
                next_rd       = i_rd;
                unknown_instr = 1'b0;

            end

            default: begin

                next_write    = 1'b0;
                next_set      = 1'b0;
                next_clearb   = 1'b0;
                next_address  = 12'b0;
                next_value    = 32'b0;
                next_rd       = 5'b0;
                unknown_instr = 1'b1;

            end

        endcase
    end

    /*
     *  Synchronous logic to handle the states
     */

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state    <= IDLE;

            write    <= 1'b0;
            set      <= 1'b0;
            clearb   <= 1'b0;
            value    <= 32'b0;
            readback <= 32'b0;

        end else begin

            state   <= next_state;
            o_error <= csr_err;

            if (state == IDLE) begin

                r_rd     <= next_rd;

                write    <= next_write;
                set      <= next_set;
                clearb   <= next_clearb;
                value    <= next_value;
                address  <= next_address;
                readback <= 32'b0;

            end else if (state == READ) begin

                readback <= csr_rd;

            end
        end
    end

    /* 
     *  State evolution logic
     */
    always_comb begin

        unique case (state)

            IDLE:  next_state = (unknown_instr) ? IDLE : READ;
            READ:  next_state = WRITE;
            WRITE: next_state = (clear) ? IDLE : WRITE;
        endcase
    end

    /*
     *  Output handling logic
     */
    always_comb begin

        unique case (state)

            IDLE: begin

                csr_wa = 12'b0;
                csr_ra = 12'b0;
                csr_we = 1'b0;
                csr_wd = 32'b0;

                req    = 1'b0;
                res    = 32'b0;
                busy   = 1'b0;
                o_rd   = 5'b0;
                valid  = 1'b0;

            end

            READ: begin

                csr_wa = 12'b0;
                csr_ra = address;
                csr_we = 1'b0;
                csr_wd = 32'b0;

                req    = 1'b0;
                res    = 32'b0;
                busy   = 1'b1;
                o_rd   = 5'b0;
                valid  = 1'b0;

            end

            WRITE: begin

                csr_wa = address;
                csr_ra = 12'b0;
                csr_we = 1'b1;

                unique case ({
                    write, set, clearb
                })

                    3'b100:  csr_wd = value;
                    3'b010:  csr_wd = readback | value;
                    3'b001:  csr_wd = readback & value;  // Value is already negated !
                    default: csr_wd = 32'b0;

                endcase

                req   = 1'b0;
                res   = readback;
                busy  = 1'b1;
                o_rd  = r_rd;
                valid = 1'b1;

            end

        endcase
    end

    assign i_error = unknown_instr;

endmodule
