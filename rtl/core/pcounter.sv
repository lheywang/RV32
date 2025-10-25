`timescale 1ns / 1ps

import core_config_pkg::IF_MAX_ADDR;
import core_config_pkg::IF_INC;
import core_config_pkg::XLEN;
import core_config_pkg::IF_BASE_ADDR;

module pcounter
(
    // Logic inputs
    input   logic                       clk,
    input   logic                       clk_en,
    input   logic                       rst_n,
    input   logic                       enable,
    input   logic                       load,

    // Bus inputs
    input   logic   [(XLEN - 1) : 0]    loaded,

    // Outputs
    output  logic                       ovf,
    output  logic   [(XLEN - 1) : 0]    address
);

    always_ff @( posedge clk or negedge rst_n ) begin

        if (!rst_n) begin

            address             <= IF_BASE_ADDR;
            ovf                 <= 0;

        end 
        else if (clk_en) begin

            if (load) begin

                address         <= loaded;

            end else if (enable) begin

                if (address < (IF_MAX_ADDR - IF_INC)) begin

                    address     <= address + IF_INC;
                    ovf         <= 0;

                end else begin

                    ovf         <= 1;

                end
            end
        end
    end

endmodule
