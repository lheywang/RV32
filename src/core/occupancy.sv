`timescale 1ns / 1ps

import core_config_pkg::XLEN;
import core_config_pkg::REG_ADDR_W;
import core_config_pkg::REG_COUNT;

module occupancy(
    input   logic                           clk,
    input   logic                           rst_n,

    // Issuer interface
    input   logic   [(REG_ADDR_W - 1) : 0]  target,         // target register ID
    input   logic   [(REG_ADDR_W - 1) : 0]  source1,        // arg1
    input   logic   [(REG_ADDR_W - 1) : 0]  source2,        // arg2
    output  logic                           exec_ok,        // set to 1 if the execution is possible
    input   logic                           lock,           // Lock the target register if all are available

    // Commiter interface
    input   logic   [(REG_ADDR_W - 1) : 0]  address,        // Address of the written register
    input   logic                           write           // Write enable.
);

    /*
     *  Storage type
     */
    logic   [(REG_COUNT - 1) : 0]       reg_state;          // 1 is available, 0 is locked.
    logic                               int_ok;

    /*
     *  Combinational logic to see if the current set of arguments / target is not 
     *  currently under an execution lock.
     */
    always_comb begin

        int_ok = reg_state[target] && reg_state[source1] && reg_state[source2];

    end

    /*
     *  Synchronous set and reset logic to the state register
     */
    always_ff @( posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            reg_state   <= 32'hFFFFFFFF; // all availables.
            exec_ok     <= 0;

        end
        else begin

            /*
             *  Set logic, if we're OK to lock this register
             */
            if (int_ok && lock) begin

                reg_state[target]   <= 1'b0;
                exec_ok             <= 1;

            end 
            else begin

                exec_ok             <= 0;

            end

            /*
             *  Reset logic, only based on the register access signals.
             */
            if (write) begin

                reg_state[address]  <= 1'b1;

            end
        end
    end
endmodule
