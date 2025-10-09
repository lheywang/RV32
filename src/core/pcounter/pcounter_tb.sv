`timescale 1ns / 1ps

import core_config_pkg::XLEN;

module pcounter_tb ();

    logic               clk;
    logic               clk_en;
    logic               rst_n;
    logic               enable;
    logic               load;
    logic               ovf;
    logic   [XLEN-1:0]  address;
    logic   [XLEN-1:0]  loaded; 

    pcounter pcounter(
        clk, 
        clk_en, 
        rst_n, 
        enable, 
        load, 
        loaded,
        ovf, 
        address
    );

    initial #1000ns $finish;

    // Testbench config
    initial begin
      $dumpfile("./dump.vcd");
      $dumpvars();
    end
    always #10 $display("0x%h | %h", address, ovf);

    // Clock
    initial clk = 1;
    initial clk_en = 0;
    always #10 clk <= ~clk;
    always #20 clk_en <= ~clk_en;

    // Signals
    initial begin

        rst_n = 0;
        clk_en = 0;
        enable = 0;
        load = 0;
        loaded = 0;

        #10 
        rst_n = 1;
        #50 
        enable = 1;

        #600
        loaded = 32'h1000_3FF0;
        load = 1;
        #40;
        load = 0;

    end

endmodule
