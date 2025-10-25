/*
 *  File :      rtl/core/occupancy.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file define the module that track dependencies between registers.
 *              This ensure an instruction won't start until all of it's required data is 
 *              available, on both the registers or the bypass.
 *              In the same manner, it will also track writting dependencies to ensure
 *              the correct order is present.
 */

`timescale 1ns / 1ps

import core_config_pkg::XLEN;
import core_config_pkg::REG_ADDR_W;
import core_config_pkg::REG_COUNT;

module occupancy (
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic [(REG_ADDR_W - 1) : 0] target,   // target register ID
    input  logic [(REG_ADDR_W - 1) : 0] source1,  // arg1
    input  logic [(REG_ADDR_W - 1) : 0] source2,  // arg2
    output logic                        exec_ok,  // set to 1 if the execution is possible
    input  logic                        lock,     // Lock the target register if all are available
    input  logic [(REG_ADDR_W - 1) : 0] address,  // Address of the written register
    input  logic                        write     // Write enable.
);

    /*
     *  Storage type
     */
    logic [(REG_COUNT - 1) : 0] reg_state;  // 1 is available, 0 is locked.
    logic                       status0;
    logic                       status1;
    logic                       status2;

    /*
     *  Using an assign block did show better results than always_comb logic.
     */
    assign status0 = reg_state[target];
    assign status1 = reg_state[source1];
    assign status2 = reg_state[source2];

    /*
     *  Synchronous set and reset logic to the state register
     */
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            reg_state <= 32'hFFFFFFFF;  // all availables.
            exec_ok   <= 0;

        end else begin

            exec_ok <= status0 && status1 && status2;

            /*
             *  Set logic, if we're OK to lock this register
             */
            if (exec_ok && lock) begin

                if (target != 0) begin  // protect against reserving the register 0

                    reg_state[target] <= 1'b0;

                end

            end

            /*
             *  Reset logic, only based on the register access signals.
             */
            if (write) begin

                reg_state[address] <= 1'b1;

            end
        end
    end
endmodule
