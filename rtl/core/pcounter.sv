/*
 *  File :      rtl/core/pcounter.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file define the program counter, the module that handle the
 *              computing of the next address to be executed.
 *              It has two inputs ports, for different level of priority between the 
 *              commit unit and the branch prediction unit.
 */

`timescale 1ns / 1ps

import core_config_pkg::IF_MAX_ADDR;
import core_config_pkg::IF_INC;
import core_config_pkg::XLEN;
import core_config_pkg::IF_BASE_ADDR;

/*
 *  The "legacy" load input as the precedence over the load2 port.
 *  This is needed to ensure a branch mis-predicted will always be handled,
 *  because in that case, the branch prediction unit would not behave correctly.
 */

module pcounter (
    input  logic                  clk,
    input  logic                  clk_en,
    input  logic                  rst_n,
    input  logic                  enable,
    input  logic                  load,
    input  logic                  load2,
    input  logic [(XLEN - 1) : 0] loaded,
    input  logic [(XLEN - 1) : 0] loaded2,
    output logic                  ovf,
    output logic [(XLEN - 1) : 0] address
);

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            address <= IF_BASE_ADDR;
            ovf     <= 0;

        end else if (clk_en) begin

            if (load) begin

                address <= loaded;

            end else if (load2 && !load) begin

                address <= loaded2;

            end else if (enable) begin

                if (address < (IF_MAX_ADDR - IF_INC)) begin

                    address <= address + IF_INC;
                    ovf     <= 0;

                end else begin

                    ovf <= 1;

                end
            end
        end
    end

endmodule
