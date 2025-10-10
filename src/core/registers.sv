`timescale 1ns / 1ps

import core_config_pkg::XLEN;
import core_config_pkg::REG_COUNT;
import core_config_pkg::REG_ADDR_W;

module registers (
    input   logic                                   clk,
    input   logic                                   clk_en,

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

    logic   [(XLEN - 1) : 0]    	regs					[(REG_COUNT - 1) : 0];

    /*
    *   Synchronous write logic
    */
    always_ff @( posedge clk) begin
	 
			if (clk_en) begin

            if (we) begin

                if (wa != 0) begin

                    regs[wa] <= wd;

                end
            end
				
				rd1 <= regs[ra1];
				rd2 <= regs[ra2];
	 
        end
    end

endmodule
