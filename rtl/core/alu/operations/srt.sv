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
    typedef enum logic[2:0] {
        IDLE,
        IDLE2,
        IDLE3,
        DIVIDE,
        DIVIDE2,
        SIGN_COMP,
        SIGN_FIX1,
        SIGN_FIX2
    } state_t;

    state_t pres_state, next_state;

    /*
     * Registers
     * Structure: [Remainder (33 bits) | Quotient (32 bits)]
     * Similar to Booth's [AC | QR] structure
     */
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
     
    logic [31:0]            abs_dividend;
    logic [31:0]            abs_divisor;
    logic [31:0]            next_abs_dividend;
    logic [31:0]            next_abs_divisor;

    /* verilator lint_off UNUSEDSIGNAL */
    logic [64:0]            shifted_AQ;
    logic [64:0]            next_shifted_AQ;
    /* verilator lint_on UNUSEDSIGNAL */      
    logic [32:0]            temp_sub;  
    logic [32:0]            A_part;   
    logic [32:0]            next_temp_sub;
    logic [31:0]            sign_mask_q;
    logic [31:0]            sign_mask_r;
    logic [31:0]            next_sign_mask_q;
    logic [31:0]            next_sign_mask_r;
    logic [31:0]            sign_mask_dividend;
    logic [31:0]            sign_mask_divisor;
    logic [31:0]            next_sign_mask_dividend;
    logic [31:0]            next_sign_mask_divisor;

     /*
      * Note : Theses registers, AQ_regx are high fanout ones, so we use multiple
      * registers rather than one. This gave us a frequency increase which was not
      * negligeable.
      */
    logic [64:0]            next_AQ;
    logic [64:0]            AQ_reg;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [64:0]            AQ_reg2;
    logic [64:0]            AQ_reg3; 
    /* verilator lint_on UNUSEDSIGNAL */


    /*
     * Sequential logic
     */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            pres_state          <= IDLE;
            AQ_reg              <= '0;
            AQ_reg2             <= '0;
            AQ_reg3             <= '0;
            divisor_reg         <= '0;
            count               <= '0;
            valid               <= 1'b0;
            div_by_zero         <= 1'b0;
            dividend_neg_reg    <= 1'b0;
            divisor_neg_reg     <= 1'b0;
            quotient_null       <= 1'b0;
            remainder_null      <= 1'b0;
            quotient            <= 32'b0;
            remainder           <= 32'b0;
            abs_dividend        <= 32'b0;
            abs_divisor         <= 32'b0;
            shifted_AQ          <= 65'b0;
            temp_sub            <= 33'b0;
            sign_mask_q         <= 32'b0;
            sign_mask_r         <= 32'b0;
            sign_mask_dividend  <= 32'b0;
            sign_mask_divisor   <= 32'b0;

        end 
        else begin

            pres_state          <= next_state;
            AQ_reg              <= next_AQ;
            AQ_reg2             <= next_AQ;
            AQ_reg3             <= next_AQ;
            divisor_reg         <= next_divisor;
            count               <= next_count;
            valid               <= next_valid;
            div_by_zero         <= next_div_by_zero;
            dividend_neg_reg    <= next_dividend_neg;
            divisor_neg_reg     <= next_divisor_neg;
            quotient_null       <= next_quotient_null;
            remainder_null      <= next_remainder_null;
            quotient            <= final_quotient;
            remainder           <= final_remainder;
            abs_dividend        <= next_abs_dividend;
            abs_divisor         <= next_abs_divisor;
            shifted_AQ          <= next_shifted_AQ;
            temp_sub            <= next_temp_sub;
            sign_mask_q         <= next_sign_mask_q;
            sign_mask_r         <= next_sign_mask_r;
            sign_mask_dividend  <= next_sign_mask_dividend;
            sign_mask_divisor   <= next_sign_mask_divisor;

        end
    end

    /*
     * Combinational logic
     */
    always_comb begin
        // Defaults
        next_state              = pres_state;
        next_AQ                 = AQ_reg;
        next_divisor            = divisor_reg;
        next_count              = count;
        next_valid              = 1'b0;
        next_div_by_zero        = div_by_zero;
        next_dividend_neg       = dividend_neg_reg;
        next_divisor_neg        = divisor_neg_reg;
        next_quotient_null      = 1'b0;
        next_remainder_null     = 1'b0;
        final_quotient          = '0;
        final_remainder         = '0;
        next_abs_dividend       = 32'b0;
        next_abs_divisor        = 32'b0;
        next_shifted_AQ         = AQ_reg;
        next_temp_sub           = 33'b0;
        next_sign_mask_q        = 32'b0;
        next_sign_mask_r        = 32'b0;
        next_sign_mask_dividend = 32'b0;
        next_sign_mask_divisor  = 32'b0;
        A_part                  = 33'b0;

        case (pres_state)

            /*
             *  Initialization cases
             */

            IDLE: begin
                next_count = 6'd0;
                next_div_by_zero = 1'b0;
                next_valid = 1'b0;

                if (start) begin
                   
                    if (divisor == 32'd0) begin

                        next_div_by_zero = 1'b1;
                        next_AQ = {dividend, 33'h1FFFFFFFF};
                        next_state = SIGN_FIX2;

                    end

                    /* 
                     *  Note : Using two signess for the division lead to incorrect 
                     *  and unpredictable results.
                     *
                     *  XORing the signs ensure us to get an error in theses cases, or the
                     *  right result at the end !
                     */
                    else if (dividend_signed ^ divisor_signed) begin

                        next_div_by_zero = 1'b0;
                        final_quotient = 32'b1;
                        final_remainder = 32'b1;
                        next_state = SIGN_FIX2;

                    end 
                    else begin

                        next_sign_mask_dividend = {32{dividend_signed && dividend[31]}};
                        next_sign_mask_divisor  = {32{divisor_signed  && divisor[31]}};
                                
                        next_state = IDLE2;
                        
                        end
                    end
                end
                
            IDLE2 : begin

                /*
                 *  Note : This combinational logic enable to negate a number without needing
                 *  carry chains. The logic is A XOR MASK + 1, where XOR is used as a wanted inverter.
                 */
                next_abs_dividend = (dividend ^ sign_mask_dividend) + {31'b0, sign_mask_dividend[0]};
                next_abs_divisor  = (divisor  ^ sign_mask_divisor)  + {31'b0, sign_mask_divisor[0]};
                          
                next_state = IDLE3;

                end
             
            IDLE3 : begin

                next_dividend_neg = dividend_signed && dividend[31];
                next_divisor_neg  = divisor_signed  && divisor[31];

                next_AQ       = {33'd0, abs_dividend};
                next_divisor  = abs_divisor;

                next_state = DIVIDE;
                    
            end

            /*
             *  Computing cases
             */
            DIVIDE: begin
                
                next_shifted_AQ = AQ_reg << 1;
                A_part          = next_shifted_AQ[64:32];
                
                next_temp_sub = A_part - {1'b0, divisor_reg};
                next_state = DIVIDE2;

            end

            DIVIDE2: begin

                next_AQ = (temp_sub[32]) ? 
                            {shifted_AQ[64:1], 1'b0} : 
                            {temp_sub, shifted_AQ[31:1], 1'b1};

                next_count = count + 6'd1;
                next_state = (count == 6'd31) ? 
                            SIGN_COMP : 
                            DIVIDE;

            end
                
            /*
             *  Output cases
             */
            SIGN_COMP : begin

                next_quotient_null  = ~(|AQ_reg2[31:0]);
                next_remainder_null = ~(|AQ_reg2[63:32]);
                next_state = SIGN_FIX1;
            
            end

            SIGN_FIX1: begin

                next_sign_mask_q = {32{(dividend_neg_reg ^ divisor_neg_reg) && !quotient_null}};
                next_sign_mask_r = {32{(dividend_neg_reg && !remainder_null)}};

                next_state = SIGN_FIX2;

            end

            SIGN_FIX2 : begin

                /*
                 *  Note : This combinational logic enable to negate a number without needing
                 *  carry chains. The logic is A XOR MASK + 1, where XOR is used as a wanted inverter.
                 */ 
                final_quotient  = (AQ_reg3[31:0] ^ sign_mask_q) + {31'b0, sign_mask_q[0]};
                final_remainder = (AQ_reg3[63:32] ^ sign_mask_r) + {31'b0, sign_mask_r[0]};
                
                next_valid = 1'b1;
                next_state = IDLE;
            end

            /* 
             *  Default handler
             */ 
            default: next_state = IDLE;
        endcase
    end
endmodule
