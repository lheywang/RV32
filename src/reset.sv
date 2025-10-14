`timescale 1ns/1ps

import core_config_pkg::RST_TICK_CNT;

module reset (
    input  logic clk,          // system clock
    input  logic rst_in,     // async active-low input reset (from button, POR, etc.)
    output logic rst_out       // sync active-high reset output
);

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------
    logic [1:0] sync_rst;          // two-flop synchronizer
    logic       reset_active;      // internal "we are in reset" flag
    integer     counter;           // countdown register

    // -------------------------------------------------------------------------
    // Power-up initialization (for simulation and synthesis)
    // -------------------------------------------------------------------------
    initial begin
        sync_rst      = 2'b00;
        reset_active  = 1'b1;
        counter       = RST_TICK_CNT;
        rst_out       = 1'b1;
    end

    // -------------------------------------------------------------------------
    // Asynchronous input synchronization
    // Ensures rstrst_in_in_n is safely synchronized to clk domain.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_in) begin

        if (!rst_in)

            sync_rst <= 2'b00;               // immediate async assertion

        else

            sync_rst <= {sync_rst[0], 1'b1}; // synchronize release

    end

    // -------------------------------------------------------------------------
    // Reset pulse generator
    // Ensures rst_out stays asserted for at least RST_TICK_CNT cycles after
    // rst_in goes high (deasserted) and during any reset.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin

        if (sync_rst[1] == 0) begin

            // External reset active -> restart counter
            reset_active <= 1'b1;
            counter      <= RST_TICK_CNT;
            rst_out      <= 1'b0;

        end else if (reset_active) begin

            // Continue holding reset for at least N cycles
            if (counter > 0) begin

                counter  <= counter - 1;
                rst_out  <= 1'b0;

            end else begin

                reset_active <= 1'b0;
                rst_out      <= 1'b1;
                
            end
        end else begin

            rst_out <= 1'b1;
            
        end
    end

endmodule
