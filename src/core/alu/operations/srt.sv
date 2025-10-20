`timescale 1ns / 1ps
import core_config_pkg::XLEN;

module srt(
    input   logic                                       clk,
    input   logic                                       rst_n,
    input   logic                                       start,
    input   logic                                       dividend_signed,
    input   logic                                       divisor_signed,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]   dividend,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]   divisor,
    output  logic                                       valid,
    output  logic   [(core_config_pkg::XLEN - 1) : 0]   quotient,
    output  logic   [(core_config_pkg::XLEN - 1) : 0]   remainder,
    output  logic                                       div_by_zero
);

    /*
     * State machine (similar to Booth multiplier)
     */
    typedef enum logic[1:0] {
        IDLE        = 2'b00,
        DIVIDE      = 2'b01,
        SIGN_FIX    = 2'b10,
        ERR         = 2'b11
    } state_t;

    state_t                 pres_state;
    state_t                 next_state;

    /*
     * Registers
     */
    logic [64:0]            AQ_reg;         // Combined register [Remainder:Quotient]
    logic [64:0]            next_AQ;
    logic [31:0]            divisor_reg;
    logic [31:0]            next_divisor;
    logic [5:0]             count;
    logic [5:0]             next_count;
    logic                   next_valid;
    logic                   next_div_by_zero;
    
    // Sign tracking
    logic                   dividend_neg_reg;
    logic                   divisor_neg_reg;
    logic                   next_dividend_neg;
    logic                   next_divisor_neg;

    logic                   next_quotient_null;
    logic                   next_remainder_null;
    logic                   quotient_null;
    logic                   remainder_null; 
    logic [31:0]            final_quotient;
    logic [31:0]            final_remainder;
    

    /*
     * Sequential logic
     */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            pres_state       <= IDLE;
            AQ_reg           <= '0;
            divisor_reg      <= '0;
            count            <= '0;
            valid            <= 1'b0;
            div_by_zero      <= 1'b0;
            dividend_neg_reg <= 1'b0;
            divisor_neg_reg  <= 1'b0;
            quotient_null    <= 1'b0;
            remainder_null   <= 1'b0;

        end 
        else begin

            pres_state       <= next_state;
            AQ_reg           <= next_AQ;
            divisor_reg      <= next_divisor;
            count            <= next_count;
            valid            <= next_valid;
            div_by_zero      <= next_div_by_zero;
            dividend_neg_reg <= next_dividend_neg;
            divisor_neg_reg  <= next_divisor_neg;
            quotient_null    <= next_quotient_null;
            remainder_null   <= next_remainder_null;

        end
    end

    /*
     * Combinational logic part of the divider, where the magic is done
     */
    always_comb begin

        // Defaults assignements
        next_state          = pres_state;
        next_AQ             = AQ_reg;
        next_divisor        = divisor_reg;
        next_count          = count;
        next_valid          = 1'b0;
        next_div_by_zero    = div_by_zero;
        next_dividend_neg   = dividend_neg_reg;
        next_divisor_neg    = divisor_neg_reg;
        next_quotient_null  = 1'b0;
        next_remainder_null = 1'b0;
        final_quotient      = 32'b0;
        final_remainder     = 32'b0;

        case (pres_state)

            IDLE: begin
                
                next_count          = 6'd0;
                next_div_by_zero    = 1'b0;
                next_valid          = 1'b0;

                if (start) begin
                   
                    /*
                     *  Note : The math prevent from dividing by zero. So, we end up in errors
                     *  that would happen.
                     */
                    if (divisor == 32'd0) begin

                        next_div_by_zero    = 1'b1;
                        next_AQ             = {dividend, 33'h1FFFFFFFF};
                        next_state          = ERR;

                    end

                    /* 
                     *  Note : Using two different signes for the division lead to incorrect 
                     *  and unpredictable results.
                     *
                     *  XORing the signs ensure us to get an error in theses cases, or the
                     *  right result at the end !
                     */
                    else if (dividend_signed ^ divisor_signed) begin

                        next_div_by_zero    = 1'b0;
                        next_AQ             = {dividend, 33'h1FFFFFFFF};
                        next_state          = ERR;

                    end 
                    else begin

                        logic [31:0] sign_mask_dividend;
                        logic [31:0] sign_mask_divisor;
                        logic [31:0] abs_dividend;
                        logic [31:0] abs_divisor;

                        sign_mask_dividend  = {32{dividend_signed && dividend[31]}};
                        sign_mask_divisor   = {32{divisor_signed  && divisor[31]}};

                        /*
                         *  Note : This combinational logic enable to negate a number while being 
                         *  faster than the default assignements.
                         *  The logic is A XOR MASK + 1, where XOR is used as a commanded inverter.
                         */
                        abs_dividend        = (dividend ^ sign_mask_dividend) + {31'b0, sign_mask_dividend[0]};
                        abs_divisor         = (divisor  ^ sign_mask_divisor)  + {31'b0, sign_mask_divisor[0]};

                        next_dividend_neg   = dividend_signed && dividend[31];
                        next_divisor_neg    = divisor_signed  && divisor[31];

                        next_AQ             = {33'd0, abs_dividend};
                        next_divisor        = abs_divisor;

                        next_state          = DIVIDE;
                    end
                end
            end

            DIVIDE: begin

                /* verilator lint_off UNUSEDSIGNAL */
                logic [64:0] shifted_AQ;
                /* verilator lint_on UNUSEDSIGNAL */
                logic [32:0] A_part;        // Remainder part (33 bits)
                logic [32:0] temp_sub;
                
                // Performing the shift
                shifted_AQ                  = AQ_reg << 1;
                A_part                      = shifted_AQ[64:32];
                
                /*
                 *  Theses lines, the substraction and the selection are on the critical path.
                 *  Getting better expression here WILL result in a better FMAX.
                 */
                // Checking if we can perform another step
                temp_sub                    = A_part - {1'b0, divisor_reg};
                case (temp_sub[32])
                    1'b1 :  next_AQ         = {shifted_AQ[64:1], 1'b0};
                    1'b0 :  next_AQ         = {temp_sub, shifted_AQ[31:1], 1'b1};
                endcase

                // Incrementing count
                next_count                  = count + 6'd1;

                // Registered assignement of the conditions, get use some better results
                next_quotient_null          = (next_AQ[31:0] == 32'd0) ? 1'b1 : 1'b0; 
                next_remainder_null         = (next_AQ[63:32] == 32'd0) ? 1'b1 : 1'b0; 

                if (count == 6'd31) begin
                    next_state              = SIGN_FIX;
                end
            end

            SIGN_FIX: begin

                logic [31:0] sign_mask_q;
                logic [31:0] sign_mask_r;

                sign_mask_q                 = {32{(dividend_neg_reg ^ divisor_neg_reg) && !quotient_null}};
                sign_mask_r                 = {32{(dividend_neg_reg && !remainder_null)}};

                /*
                 *  Note : This combinational logic enable to negate a number while being 
                 *  faster than the default assignements.
                 *  The logic is A XOR MASK + 1, where XOR is used as a commanded inverter.
                 */	
                final_quotient              = (AQ_reg[31:0] ^ sign_mask_q) + {31'b0, sign_mask_q[0]};
                final_remainder             = (AQ_reg[63:32] ^ sign_mask_r) + {31'b0, sign_mask_r[0]};
                next_AQ                     = {AQ_reg[64], final_remainder, final_quotient};

                next_valid                  = 1'b1;
                next_state                  = IDLE;
            end

            /*
             *  Handling errors by exiting early and setting out the valid bit.
             */
            ERR: begin
                next_valid                  = 1'b1;
                next_state                  = IDLE;
            end
        endcase
    end

    // Output assignments
    assign quotient                         = AQ_reg[31:0];
    assign remainder                        = AQ_reg[63:32];

endmodule
