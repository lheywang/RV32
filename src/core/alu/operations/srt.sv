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
     * State machine
     */
    typedef enum logic[1:0] {
        IDLE        = 2'b00,
        DIVIDE      = 2'b01,
        CORRECT     = 2'b10,
        SIGN_FIX    = 2'b11
    } state_t;

    state_t                                             pres_state;
    state_t                                             next_state;

    /*
     * Registers
     */
    logic signed [(core_config_pkg::XLEN) : 0]          remainder_reg;      // 33 bits (sign + 32 data)
    logic signed [(core_config_pkg::XLEN) : 0]          next_remainder;
    logic        [(core_config_pkg::XLEN - 1) : 0]      quotient_reg;
    logic        [(core_config_pkg::XLEN - 1) : 0]      next_quotient;
    logic signed [(core_config_pkg::XLEN - 1) : 0]      divisor_reg;        // Store divisor
    logic signed [(core_config_pkg::XLEN - 1) : 0]      next_divisor;
    logic        [($clog2(core_config_pkg::XLEN)) : 0]  count;
    logic        [($clog2(core_config_pkg::XLEN)) : 0]  next_count;
    logic                                               next_valid;
    logic                                               next_div_by_zero;
    logic signed [(core_config_pkg::XLEN) : 0]          shifted_remainder;
    logic signed [(core_config_pkg::XLEN - 1) : 0]      test_sub;
    
    // Sign tracking for final adjustment
    logic                                           dividend_neg;
    logic                                           divisor_neg;
    logic                                           next_dividend_neg;
    logic                                           next_divisor_neg;

    /*
     * Sequential logic
     */
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            pres_state      <= IDLE;
            remainder_reg   <= '0;
            quotient_reg    <= '0;
            divisor_reg     <= '0;
            count           <= '0;
            valid           <= 1'b0;
            div_by_zero     <= 1'b0;
            dividend_neg    <= 1'b0;
            divisor_neg     <= 1'b0;

        end 
        else begin

            pres_state      <= next_state;
            remainder_reg   <= next_remainder;
            quotient_reg    <= next_quotient;
            divisor_reg     <= next_divisor;
            count           <= next_count;
            valid           <= next_valid;
            div_by_zero     <= next_div_by_zero;
            dividend_neg    <= next_dividend_neg;
            divisor_neg     <= next_divisor_neg;

        end
    end

    /*
     * Combinational logic
     */
    always_comb begin
        // Defaults
        next_state          = pres_state;
        next_remainder      = remainder_reg;
        next_quotient       = quotient_reg;
        next_divisor        = divisor_reg;
        next_count          = count;
        next_valid          = 1'b0;
        next_div_by_zero    = div_by_zero;
        next_dividend_neg   = dividend_neg;
        next_divisor_neg    = divisor_neg;
        shifted_remainder   = 0;
        test_sub            = 0;

        case (pres_state)
            IDLE: begin
                next_count = 6'd0;
                next_div_by_zero = 1'b0;

                if (start) begin
                    // Check for division by zero
                    if (divisor == 0) begin
                        next_div_by_zero = 1'b1;
                        next_state = SIGN_FIX;  // Go to output with error
                    end else begin
                        next_state = DIVIDE;

                        // Track signs for final correction
                        next_dividend_neg = dividend_signed && dividend[31];
                        next_divisor_neg  = divisor_signed && divisor[31];

                        // Convert to absolute values for division
                        if (dividend_signed && dividend[31]) begin
                            // Negative dividend: convert to positive
                            next_remainder = {1'b0, -$signed(dividend)};
                        end else begin
                            next_remainder = {1'b0, dividend};
                        end

                        if (divisor_signed && divisor[31]) begin
                            // Negative divisor: convert to positive
                            next_divisor = -$signed(divisor);
                        end else begin
                            next_divisor = divisor;
                        end

                        next_quotient = 32'd0;
                    end
                end
            end

            DIVIDE: begin

                
                // Shift remainder left by 1 (multiply by 2)
                shifted_remainder = remainder_reg << 1;
                
                // Try subtracting divisor (32-bit subtraction for timing!)
                test_sub = shifted_remainder[31:0] - divisor_reg;
                
                // Non-restoring division logic
                if (shifted_remainder[32] == 1'b0) begin
                    // Remainder is positive: subtract divisor
                    if (test_sub[31] == 1'b0) begin
                        // Result still positive: accept subtraction
                        next_remainder = {1'b0, test_sub[31:0]};
                        next_quotient = {quotient_reg[30:0], 1'b1};  // Q bit = 1
                    end else begin
                        // Result negative: keep original
                        next_remainder = shifted_remainder;
                        next_quotient = {quotient_reg[30:0], 1'b0};  // Q bit = 0
                    end
                end else begin
                    // Remainder is negative: add divisor
                    next_remainder = {1'b0, shifted_remainder[31:0] + divisor_reg};
                    next_quotient = {quotient_reg[30:0], 1'b0};  // Q bit = 0
                end

                next_count = count + 6'd1;

                if (count == 6'd31) begin
                    next_state = CORRECT;
                end
            end

            CORRECT: begin
                // Final correction if remainder is negative
                if (remainder_reg[32]) begin
                    next_remainder = remainder_reg + {1'b0, divisor_reg};
                    next_quotient = quotient_reg - 1;
                end
                next_state = SIGN_FIX;
            end

            SIGN_FIX: begin
                // Apply signs according to RISC-V rules:
                // - Quotient sign: dividend_sign XOR divisor_sign
                // - Remainder sign: dividend_sign

                if (div_by_zero) begin
                    // Division by zero: return -1 for quotient, dividend for remainder
                    next_quotient = 32'hFFFFFFFF;
                    next_remainder = {1'b0, dividend};
                end else begin
                    // Fix quotient sign
                    if (dividend_neg ^ divisor_neg) begin
                        next_quotient = -$signed(quotient_reg);
                    end

                    // Fix remainder sign (takes dividend's sign)
                    if (dividend_neg && remainder_reg != 0) begin
                        next_remainder = -remainder_reg;
                    end
                end

                next_valid = 1'b1;
                next_state = IDLE;
            end
        endcase
    end

    // Output assignments
    assign quotient = quotient_reg;
    assign remainder = remainder_reg[31:0];

endmodule
