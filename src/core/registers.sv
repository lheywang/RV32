`timescale 1ns / 1ps

import core_config_pkg::XLEN;
import core_config_pkg::REG_COUNT;
import core_config_pkg::REG_ADDR_W;

module registers (
    input   logic                                   clk,
    input   logic                                   clk_en,
    input   logic                                   rst_n,

    input   logic                                   we,
    input   logic   [(REG_ADDR_W - 1) : 0]          wa,
    input   logic   [(XLEN - 1)  : 0]               wd,

    input   logic   [(REG_ADDR_W - 1) : 0]          ra1,
    input   logic   [(REG_ADDR_W - 1) : 0]          ra2,
    output  logic   [(XLEN - 1) : 0]                rd1,
    output  logic   [(XLEN - 1) : 0]                rd2
);

    /*
     *  Storage array
     */

    logic  [(REG_COUNT - 1) : 0][(XLEN - 1) : 0]    regs;

    /*
    *   Synchronous write logic
    */
    always_ff @( posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            regs <= 0;

        end
        else if (clk_en) begin

            if (we) begin

                if (wa != 0) begin

                    regs[wa] <= wd;

                end
            end
        end
    end

    /*
    *   Asynchronous read logic
    */
    always_comb begin

        rd1 = regs[ra1];
        rd2 = regs[ra2];

    end

endmodule
