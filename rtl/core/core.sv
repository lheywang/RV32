/*
 *  File :      rtl/core/core.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file assemble all of the core components into
 *              a single entity, easier to use rather than a lot
 *              of smallers modules.
 */

`timescale 1ns / 1ps

import core_config_pkg::XLEN;
import core_config_pkg::REG_ADDR_W;
import core_config_pkg::opcodes_t;

module core (

    input  logic clk,
    input  logic i_rst_n,
    output logic o_rst_n,

    // Program ROM IF
    input logic [(XLEN - 1) : 0] instr,
    output logic [(XLEN - 1) : 0] rom_addr,
    output logic flush,
    output logic enable,
    output logic rden,

    // Peripherals / RAM interface
    output logic [      (XLEN - 1) : 0] mem_addr,
    output logic [((XLEN / 8) - 1) : 0] mem_byteen,
    output logic                        mem_we,
    output logic                        mem_req,
    output logic [      (XLEN - 1) : 0] mem_wdata,
    input  logic [      (XLEN - 1) : 0] mem_rdata,
    input  logic                        mem_err,

    // Interruption logic
    input logic [(core_config_pkg::XLEN - 1) : 0] interrupt_vect

);
    /*
     *  Global signals
     */
    logic clk_en;

    /*
     *  PC
     */
    logic [(XLEN - 1) : 0] pc_addr;
    logic pc_ovf;

    /*
     *  BPU
     */
    logic [(XLEN - 1) : 0] if_addr;  // Used as output address.
    logic bpu_branch_taken;  // Show if the branch was predicted as taken or not.
    logic [(XLEN - 1) : 0] bpu_write_addr;
    logic bpu_write;
    logic bpu_flush;

    /*
     *  Delay lines
     */
    logic [(XLEN - 1) : 0] del_addr;  // From if_addr to dec_i_addr;
    logic del_branch_taken;  // Show if the branch was predicted as taken or not.

    /*
     *  Endianness corrections
     */
    logic [(XLEN - 1) : 0] cor_instr;
    logic [(XLEN - 1) : 0] cor_mem_rdata;
    logic [(XLEN - 1) : 0] cor_mem_wdata;

    /*
     *  Decoder
     */
    opcodes_t dec_opcode;
    logic dec_illegal;
    logic [(XLEN - 1) : 0] dec_imm;
    logic [(REG_ADDR_W - 1) : 0] dec_rs1;
    logic [(REG_ADDR_W - 1) : 0] dec_rs2;
    logic [(REG_ADDR_W - 1) : 0] dec_rd;
    logic [(XLEN - 1) : 0] dec_addr;
    logic dec_busy;
    logic dec_decoded;

    /*
     *  Execution logic
     */
    logic exec_busy;
    logic exec_flush;
    logic [(XLEN - 1) : 0] commit_addr;
    logic commit_write;
    logic commit_enable;
    logic alu_branch_taken;
    logic alu_branch_not_taken;

    /*
     *  Instantiating modules for system wide 
     */
    clock clk_gen (
        .clk(clk),
        .rst_n(o_rst_n),
        .clk_en(clk_en)
    );

    reset reset (
        .clk(clk),
        .rst_in(i_rst_n),
        .rst_out(o_rst_n)
    );

    /*
     *  Instantiating modules for the core
     */
    pcounter PC (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(o_rst_n),
        .enable(commit_enable),
        .load(commit_write),
        .load2(bpu_write),
        .loaded(commit_addr),
        .loaded2(bpu_write_addr),
        .ovf(pc_ovf),
        .address(pc_addr)
    );

    prediction BPU (
        .clk(clk),
        .rst_n(o_rst_n),
        .predict_ok(alu_branch_taken),
        .mispredict(alu_branch_not_taken),
        .addr_in(pc_addr),
        .addr_out(if_addr),
        .rom_flush(bpu_flush),
        .PC_value(bpu_write_addr),
        .PC_write(bpu_write),
        .actual_addr(dec_addr),
        .actual_imm(dec_imm),
        .actual_instr(dec_opcode),
        .bpu_branch_taken(bpu_branch_taken)
    );


    /*
     *  Adding the delay lines, in parallel of the
     *  instruction memory (leaved outside, to ensure
     *  compatibility with any vendors IP or so...).
     */
    delay #(
        .WIDTH(XLEN)
    ) instr_delay (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(o_rst_n),
        .din(if_addr),
        .dout(del_addr)
    );

    delay #(
        .WIDTH(1)
    ) branch_delay (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(o_rst_n),
        .din(bpu_branch_taken),
        .dout(del_branch_taken)
    );

    /*
     *  Adding the endianess corrections modules
     *  This is required since our design is based on big endian to
     *  make debugging easier, but the spec is little endian.
     *  Thus, we need to swap bytes on the edges of each modules.
     */
    endianess if_endian (
        .in (instr),
        .out(cor_instr)
    );

    /*
     *  Adding the decoder
     */
    decoder DEC (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(o_rst_n),
        .instruction(cor_instr),
        .i_address(del_addr),
        .i_busy(exec_busy),
        .o_busy(dec_busy),
        .rs1(dec_rs1),
        .rs2(dec_rs2),
        .rd(dec_rd),
        .imm(dec_imm),
        .o_address(dec_addr),
        .opcode(dec_opcode),
        .illegal(dec_illegal),
        .decoded_cnt(dec_decoded)
    );

    /*
     *  Finally, adding the whole execution logic
     */
    assembly_alu ALUS (
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(o_rst_n),

        .rs1(dec_rs1),
        .rs2(dec_rs2),
        .rd(dec_rd),
        .imm(dec_imm),
        .address(dec_addr),
        .opcode(dec_opcode),
        .illegal(dec_illegal),
        .busy(exec_busy),
        .flush(exec_flush),
        .branch_taken(del_branch_taken),
        .count_decoded(dec_decoded),

        .PC_ovf (pc_ovf),
        .PC_en  (commit_enable),
        .PC_load(commit_write),
        .PC_addr(commit_addr),

        .mem_addr(mem_addr),
        .mem_byteen(mem_byteen),
        .mem_we(mem_we),
        .mem_req(mem_req),
        .mem_wdata(cor_mem_wdata),
        .mem_rdata(cor_mem_rdata),
        .mem_err(mem_err),

        .bpu_branch_taken(alu_branch_taken),
        .bpu_branch_not_taken(alu_branch_not_taken),

        .interrupt_vect(interrupt_vect)
    );

    /*
     *  Endianess correction (for the same reasons as above),
     *  but for the memory interface.
     */
    endianess mem_read_cor (
        .in (mem_rdata),
        .out(cor_mem_rdata)
    );

    endianess mem_write_cor (
        .in (cor_mem_wdata),
        .out(mem_wdata)
    );

    /*
     *  Statics IO of the module
     */

    assign rom_addr = if_addr;
    assign flush = bpu_flush | exec_flush;
    assign enable = ~dec_busy;
    assign rden = 1'b1;


endmodule
