/*
 *  File :      rtl/core/clock.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file define the clock module. It generate the 
 *              clk_en signal, which will synchronize the stages 
 *              transfers.
 */

`timescale 1ns / 1ps

import core_config_pkg::CLK_DIV_MAX;
import core_config_pkg::CLK_DIV_THRES;
import core_config_pkg::CLK_DIV_WIDTH;

module clock (
    input  logic clk,
    input  logic rst_n,
    output logic clk_en
);

    // Storages signals
    logic [CLK_DIV_WIDTH:0] cnt;

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            cnt    <= 0;
            clk_en <= 0;

        end else begin

            // Handle counter evolution
            if (cnt >= CLK_DIV_MAX[CLK_DIV_WIDTH:0]) begin

                cnt <= 0;

            end else begin

                cnt <= cnt + 1;

            end

            // Handle output state
            if (cnt < CLK_DIV_THRES[CLK_DIV_WIDTH:0]) begin

                clk_en <= 1;

            end else begin

                clk_en <= 0;

            end
        end
    end

endmodule
