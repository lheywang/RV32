/*
 *  File :      rtl/core/counter.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file define a PERF_CNT_LEN bits counter, used 
 *              for performance monitoring of the core.
 *              It's output could a single 64 bits outL, or two 32 bits 
 *              outL and outH, which the 32 LSB and 32 MSB respectively.
 */

`timescale 1ns / 1ps

import core_config_pkg::PERF_CNT_LEN;
import core_config_pkg::PERF_CNT_PORT;
import core_config_pkg::PERF_CNT_INC;
import core_config_pkg::XLEN;

module counter(
    input   logic                       clk,
    input   logic                       clk_en,
    input   logic                       rst_n,
    input   logic                       enable,

    output logic    [(XLEN - 1) : 0]    outL,

     // optionnally assigned, depending if we use the higher port or not.
    output logic    [(XLEN - 1) : 0]    outH
);

    // Internal counter
    logic   [(PERF_CNT_LEN - 1) : 0]    cnt;

    always_ff @( posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            cnt         <= 0;
        
        end 
        else if (clk_en) begin

            if (enable) begin

                cnt     <= cnt + {32'b0, core_config_pkg::PERF_CNT_INC};

            end

        end

    end

    generate
        // Assigning outputs depending on the core configuration
        if (core_config_pkg::PERF_CNT_PORT == 1) begin : gen_dualport
            assign outL[core_config_pkg::XLEN-1:0] = 
                cnt[((core_config_pkg::PERF_CNT_LEN / 2) - 1) : 0];                                 // 32 LSB
            assign outH[core_config_pkg::XLEN-1:0] = 
                cnt[(core_config_pkg::PERF_CNT_LEN - 1) : (core_config_pkg::PERF_CNT_LEN / 2)];     // 32 MSB
        end 
        else begin : gen_singleport
            assign outL[(core_config_pkg::PERF_CNT_LEN - 1) : 0] = 
                cnt[(core_config_pkg::PERF_CNT_LEN - 1) : 0];                                       // 64 LSB
            assign outH = 0;                                                        // 0
        end
    endgenerate

endmodule
