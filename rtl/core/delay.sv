/*
 *  File :      rtl/core/delay.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file define a delay line, used to synchronize address and 
 *              some commands bits arround the ROM. This prevent from forcing
 *              manual delays to the user.
 */

`timescale 1ns / 1ps

import core_config_pkg::IF_LATENCY;

module delay #(
    parameter int WIDTH = 32 // We don't use XLEN here, to enable the synth of single bit delay lines.
) (
    input  logic                   clk,
    input  logic                   clk_en,
    input  logic                   rst_n,
    input  logic [(WIDTH - 1) : 0] din,
    output logic [(WIDTH - 1) : 0] dout
);

    // Internal shift register
    logic [(WIDTH - 1) : 0] shift_reg[(IF_LATENCY - 1) : 0];

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            for (int i = 0; i < IF_LATENCY; i++) shift_reg[i] <= '0;

        end else if (clk_en) begin

            shift_reg[0] <= din;

            for (int i = 1; i < IF_LATENCY; i++) shift_reg[i] <= shift_reg[i-1];

        end
    end

    assign dout = shift_reg[IF_LATENCY-1];

endmodule
