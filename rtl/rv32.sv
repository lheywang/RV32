/*
 *  File :      rtl/rv32.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      
 *  
 *  Brief :     This file is the top level of the whole core.
 *              Feel free to modify it to get the right core for your needs !
 */

`timescale 1ns / 1ps

import core_config_pkg::XLEN;

module rv32 (

    // Standard IOs
    input logic clk,
    input logic rst_n,

    // Add here your peripherals outputs if needed :)
    input logic [(core_config_pkg::XLEN - 1) : 0] interrupt_vect

);

    /*
     *  Internal global signals
     */
    logic                    int_rst_n;

    /*
     *  ROM signals
     */
    logic [  (XLEN - 1) : 0] rom_instr;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [  (XLEN - 1) : 0] rom_addr;
    /* verilator lint_on UNUSEDSIGNAL */
    logic                    rom_flush;
    logic                    rom_enable;
    logic                    rom_rden;

    /*
     *  Memory / Peripherals signals
     */
    /* verilator lint_off UNUSEDSIGNAL */
    logic [  (XLEN - 1) : 0] mem_addr;
    /* verilator lint_on UNUSEDSIGNAL */
    logic [(XLEN / 8) - 1:0] mem_byteen;
    logic                    mem_we;
    logic                    mem_req;
    logic [  (XLEN - 1) : 0] mem_wdata;
    /* verilator lint_off MULTIDRIVEN */ // Thesesignals are behind tri-state drivers, but verilator does not know that.
    logic [  (XLEN - 1) : 0] mem_rdata;
    /* verilator lint_on MULTIDRIVEN */
    logic                    mem_err;

    /*
       *    Instantiationt the main core
       */
    core riscv (
        .clk(clk),
        .i_rst_n(rst_n),
        .o_rst_n(int_rst_n),

        .instr(rom_instr),
        .rom_addr(rom_addr),
        .flush(rom_flush),
        .enable(rom_enable),
        .rden(rom_rden),

        .mem_addr(mem_addr),
        .mem_byteen(mem_byteen),
        .mem_we(mem_we),
        .mem_req(mem_req),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .mem_err(mem_err),

        .interrupt_vect(interrupt_vect)

    );

    /*
     *  Adding RAM and ROM (Actually, Altera IP's, to fit into MAX10 FPGA).
     *  Feel free to replace them with your vendors custom IPs, the interfaces
     *  shall not differ too much from one to the other.
     */
    ram RAM0 (
        .aclr(~int_rst_n),
        .byteena_a(mem_byteen),
        .clock(clk),
        .enable(1'b1),
        .rdaddress(mem_addr[16:2]),
        .wraddress(mem_addr[16:2]),
        .wren(mem_we),
        .q(mem_rdata),
        .data(mem_wdata)
    );

    /*
     *  For the first version, we stuck it to GND. We'll later add
     *  a error handling for the memory IOs (if needed ?).
     */
    assign mem_err = 1'b0;

    rom ROM0 (
        .aclr(1'b1 | rom_flush),
        .address_a(rom_addr[17:2]),
        .address_b(mem_addr[17:2]),
        .clock(clk),
        .enable(rom_enable),
        .rden_a(rom_rden),
        .rden_b(mem_req),
        .q_a(rom_instr),
        .q_b(mem_rdata)
    );

endmodule

