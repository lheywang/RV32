/*
 *  File :      rtl/core/assembly/assembly_csr.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file assemble all of the CSR with it's associated
 *              counters. This make the global core assembly much
 *              more readable.
 *
 *  Note :      There's not associated testbench for this module.
 */

import core_config_pkg::XLEN;

module assembly_csr (

    input logic clk,
    input logic clk_en,
    input logic rst_n,

    // ALU (4) interface
    input  logic [(core_config_pkg::CSR_ADDR_W - 1) : 0] csr_wa,
    input  logic [(core_config_pkg::CSR_ADDR_W - 1) : 0] csr_ra,
    input  logic                                         csr_we,
    input  logic [      (core_config_pkg::XLEN - 1) : 0] csr_wd,
    output logic [      (core_config_pkg::XLEN - 1) : 0] csr_rd,
    output logic                                         csr_err,

    // Counter interface
    input logic count_waited,
    input logic count_decoded,
    input logic count_flushed,
    input logic count_commited,

    // Issuer interface
    output logic halt_pending,

    // External interface
    input logic [(core_config_pkg::XLEN - 1) : 0] interrupt_vect
);
    /*
     *  Internals signals
     */
    logic [(core_config_pkg::XLEN - 1) : 0] waitL;
    logic [(core_config_pkg::XLEN - 1) : 0] waitH;
    logic [(core_config_pkg::XLEN - 1) : 0] decodedL;
    logic [(core_config_pkg::XLEN - 1) : 0] decodedH;
    logic [(core_config_pkg::XLEN - 1) : 0] flushL;
    logic [(core_config_pkg::XLEN - 1) : 0] flushH;
    logic [(core_config_pkg::XLEN - 1) : 0] commitL;
    logic [(core_config_pkg::XLEN - 1) : 0] commitH;
    logic [(core_config_pkg::XLEN - 1) : 0] countL;
    logic [(core_config_pkg::XLEN - 1) : 0] countH;


    /*
     *  Instantiating counters
     */
    counter wait_cnt (
        .clk   (clk),
        .clk_en(clk_en),
        .rst_n (rst_n),
        .enable(count_waited),
        .outL  (waitL),
        .outH  (waitH)
    );

    counter decode_cnt (
        .clk   (clk),
        .clk_en(clk_en),
        .rst_n (rst_n),
        .enable(count_decoded),
        .outL  (decodedL),
        .outH  (decodedH)
    );

    counter flush_cnt (
        .clk   (clk),
        .clk_en(clk_en),
        .rst_n (rst_n),
        .enable(count_flushed),
        .outL  (flushL),
        .outH  (flushH)
    );

    counter commit_cnt (
        .clk   (clk),
        .clk_en(clk_en),
        .rst_n (rst_n),
        .enable(count_commited),
        .outL  (commitL),
        .outH  (commitH)
    );

    counter count_cnt (
        .clk   (clk),
        .clk_en(clk_en),
        .rst_n (rst_n),
        .enable(1'b1),
        .outL  (countL),
        .outH  (countH)
    );

    /*
     *  Adding the global CSR register module
     */
    csr csr_regs (
        .clk           (clk),
        .we            (csr_we),
        .wa            (csr_wa),
        .wd            (csr_wd),
        .ra            (csr_ra),
        .rd            (csr_rd),
        .err           (csr_err),
        .cycleL        (countL),
        .cycleH        (countH),
        .instructionsL (commitL),
        .instructionsH (commitH),
        .flushsL       (flushL),
        .flushsH       (flushH),
        .waitsL        (waitL),
        .waitsH        (waitH),
        .decodedL      (decodedL),
        .decodedH      (decodedH),
        .interrupt_vect(interrupt_vect),
        .int_pend      (halt_pending)

    );

endmodule
