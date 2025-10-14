`timescale 1ns / 1ps

import core_config_pkg::RST_TICK_CNT;

module reset(
    input   logic   clk,
    input   logic   rst_in,
    output  logic   rst_out
);

    integer count;
    logic   reset_op;

    always_ff @( posedge clk ) begin

        if (!rst_in) begin

            reset_op <= 1;
            rst_out <= 0;
            count <= core_config_pkg::RST_TICK_CNT;

        end
        else if (reset_op) begin

            rst_out <= 0;
            count <= count - 1;

            if (count < 1) begin

                reset_op <= 0;
                rst_out <= 1;

            end
        end
    end
endmodule
