/*
 *  File :      rtl/core/prediction.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file define the BPU, Branch Prediction Unit, which
 *              will try to help to reduce the pipeline stalls, by trying to predict
 *              the next program counter address.
 */

`timescale 1ns / 1ps

import core_config_pkg::XLEN;
import core_config_pkg::BPU_BITS_NB;
import core_config_pkg::opcodes_t;

module prediction (

    // Standards
    input  logic                                       clk,
    input  logic                                       rst_n,
    input  logic                                       predict_ok,
    input  logic                                       mispredict,
    input  logic     [(core_config_pkg::XLEN - 1) : 0] addr_in,
    output logic     [(core_config_pkg::XLEN - 1) : 0] addr_out,
    output logic                                       rom_flush,
    output logic     [(core_config_pkg::XLEN - 1) : 0] PC_value,
    output logic                                       PC_write,
    input  logic     [(core_config_pkg::XLEN - 1) : 0] actual_addr,
    input  logic     [(core_config_pkg::XLEN - 1) : 0] actual_imm,
    input  opcodes_t                                   actual_instr

);

    /*
     *  Implementing the small counter that register the taken / not taken IOs.
     */
    logic [(core_config_pkg::BPU_BITS_NB - 1) : 0] counter;
    logic                                          counter_ack;

    /*
     *  Incrementing the counter if only one of the input signal is active, and ensure we ack
     *  this signal, to not count it twice.
     *  Return to the default state only if both are cleared, which is the idle state of the ALU.
     */
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            counter <= '0;

        end else if (!counter_ack) begin

            if (mispredict && counter != 0) begin

                counter <= counter - 1;
                counter_ack <= 1'b1;

            end else if (predict_ok && counter != '1) begin

                counter <= counter + 1;
                counter_ack <= 1'b1;

            end

        end else if (predict_ok == 1'b0 && mispredict == 1'b0) begin

            counter_ack <= 1'b0;

        end
    end

    /*
     *  Implementing control signals to manage the outputs
     */
    logic [(core_config_pkg::XLEN - 1) : 0] next_addr;
    logic                                   updated_needed;

    /*
     *  Then, some logic to predict the next operation.
     */
    always_comb begin

        unique case (actual_instr)

            // First, unconditionnal jumps (always taken)
            core_config_pkg::i_JAL, core_config_pkg::i_JALR: begin

                next_addr      = $signed(actual_addr) + $signed(actual_imm);
                updated_needed = 1'b1;

            end

            // Then, conditionnal jumps (need to account for the counter MSB)
            core_config_pkg::i_BEQ,
            core_config_pkg::i_BNE,
            core_config_pkg::i_BGE,
            core_config_pkg::i_BLT,
            core_config_pkg::i_BGEU,
            core_config_pkg::i_BLTU : begin

                next_addr = $signed(actual_addr) + $signed(actual_imm);
                updated_needed  = counter[core_config_pkg::BPU_BITS_NB - 1]; // Look for the MSB if needed

            end

            default: begin

                next_addr      = '0;
                updated_needed = 1'b0;

            end

        endcase
    end

    /*
     *  Finally, some logic to handle the signals timings, with a small FSM
     */
    logic active;

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            addr_out  <= '0;
            rom_flush <= 1'b1;  // inverted logic !
            PC_value  <= addr_in;
            PC_write  <= 1'b0;

        end else begin

            if (!active && updated_needed) begin

                addr_out  <= next_addr;
                rom_flush <= 1'b0;
                PC_value  <= next_addr;
                PC_write  <= 1'b1;
                active    <= 1'b1;

            end else begin

                addr_out  <= addr_in;
                rom_flush <= 1'b1;
                PC_value  <= '0;
                PC_write  <= 1'b0;
                active    <= 1'b0;

            end
        end
    end

endmodule
