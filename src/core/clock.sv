`timescale 1ns / 1ps

import core_config_pkg::REF_CLK_FREQ;
import core_config_pkg::CORE_CLK_FREQ;
import core_config_pkg::CORE_CLK_DUTY;

module clock (
    input   logic   clk,
    input   logic   rst_n,
    output  logic   clk_en
);

    // Defining parameters :
    localparam int max = (REF_CLK_FREQ / CORE_CLK_FREQ) - 1;
    localparam int thres = (max * CORE_CLK_DUTY) / 100 + 1;

    // Storages signals
    logic   [$clog2(max):0]   cnt;

    always_ff @( posedge clk or negedge rst_n ) begin
    
        if (!rst_n) begin

            cnt <= 0;
            clk_en <= 0;
        
        end else begin

            // Handle counter evolution
            if (count >= max) begin
                
                count <= 0;

            end else begin

                count <= count + 1;

            end

            // Handle output state
            if (count < thres) begin

                clk_en <= '1';

            end else begin

                clk_en <= '0';

            end
        end
    end

endmodule
