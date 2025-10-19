/*
 *  This section of code is mostly based on the algorithm here :
 *  https://electrobinary.blogspot.com/2020/08/booth-multiplier-verilog-code.html
 *  
 *  With modifications : 
 *  - Support of 32 bits operands
 *  - Integration of some Verilog -> SystemVerilog improvements.
 *  - Support of both signed and unsigned operands.
 */ 
 
`timescale 1ns / 1ps
import core_config_pkg::XLEN;

module booth(
    
    input   logic                                           clk,
    input   logic                                           rst_n,
    input   logic                                           start,
    input   logic                                           X_signed,
    input   logic                                           Y_signed,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       X,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       Y,
    output  logic                                           valid,
    output  logic   [((2 * core_config_pkg::XLEN) - 1) : 0] Z
);

    /*
     *  Custom types
     */
    typedef enum logic[0 : 0] {
        IDLE    = 1'b0,
        START   = 1'b1
    } state_t;

    /* 
     *  Storage registers
     */
    logic   signed  [(2 * core_config_pkg::XLEN) : 0]       next_Z;
    logic   signed  [(2 * core_config_pkg::XLEN) : 0]       Z_temp;
    logic   signed  [(2 * core_config_pkg::XLEN) : 0]       Z_reg;
    logic   signed  [(core_config_pkg::XLEN) : 0]           Y_ext;
    logic   signed  [(core_config_pkg::XLEN) : 0]           next_Y_ext;
    state_t                                                 next_state;
    state_t                                                 pres_state;
    logic           [1:0]                                   temp;
    logic           [1:0]                                   next_temp;
    logic           [($clog2(core_config_pkg::XLEN)-1) : 0] count;
    logic           [($clog2(core_config_pkg::XLEN)-1) : 0] next_count;
    logic                                                   next_valid;

    always_ff @ (posedge clk or negedge rst_n) begin

        if(!rst_n) begin

            Z_reg           <= 65'b0;
            valid           <= 1'b0;
            pres_state      <= IDLE;
            temp            <= 2'b0;
            count           <= '0;
            Y_ext           <= '0;

        end
        else begin

            Z_reg           <= next_Z;
            valid           <= next_valid;  
            pres_state      <= next_state;
            temp            <= next_temp;
            count           <= next_count;

            if (pres_state == START) begin

                Y_ext           <= next_Y_ext;

            end

        end
    end

    always_comb begin 

        case(pres_state)

            IDLE: begin

                next_count      = 0;
                next_valid      = 0;
                Z_temp          = '0;

                if(start) begin

                    next_state  = START;
                    next_temp   = {X[0],1'b0};
                
                    /*
                     *  Perform sign handling conditions : 
                     *  - If the operand is unsigned, we always padd '0' as the MSB
                     *  - If the operand is   signed, we always sign extend to the MSB
                     */

                    if (X_signed) begin

                        next_Z = {{33{X[31]}}, X};  // Sign extend

                    end
                    else begin

                        next_Z = {33'd0, X};        // Zero extend

                    end


                    if (Y_signed) begin

                        next_Y_ext = {Y[31], Y};         // Sign extend

                    end
                    else begin

                        next_Y_ext = {1'd0, Y};          // Zero extend

                    end

                end
                else begin

                    next_state = pres_state;
                    next_temp  = 0;
                    next_Z     = 0;
                    next_Y_ext = 0;

                end
            end

            START: begin

                /*
                * 	Not using default will indcate to quartus to infer muxes rather than equal + selectors.
                * 	This lead to a gain of frequency of about 35 MHz.
                */
                case(temp)
                    2'b00:  Z_temp = Z_reg;                                 // + 0
                    2'b10:  Z_temp = {Z_reg[64:32] - Y_ext,     Z[31:0]};   // - Y
                    2'b01:  Z_temp = {Z_reg[64:32] + Y_ext,     Z[31:0]};   // + Y
                    2'b11:  Z_temp = Z_reg;                                 // + 0
                endcase
                
                next_temp       = {X[count+1],X[count]};
                next_count      = count + 1;
                next_Z          = $signed(Z_temp) >>> 1;

                next_valid      = (&count) ? 1'b1 : 1'b0; 
                next_state      = (&count) ? IDLE : pres_state;

                next_Y_ext = 0;

            end
        endcase
    end

    assign Z = Z_reg[((2 * core_config_pkg::XLEN) - 1) : 0];

endmodule
