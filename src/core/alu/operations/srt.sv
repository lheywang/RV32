`timescale 1ns / 1ps
import core_config_pkg::XLEN;

module srt(
    input   logic                                           clk,
    input   logic                                           rst_n,
    input   logic                                           start,
    input   logic [(core_config_pkg::XLEN - 1) : 0]         dividend,
    input   logic [(core_config_pkg::XLEN - 1) : 0]         divisor,
    input   logic                                           is_signed,  // 1 = signed (DIV/REM), 0 = unsigned (DIVU/REMU)
    output  logic [(core_config_pkg::XLEN - 1) : 0]         quotient,
    output  logic [(core_config_pkg::XLEN - 1) : 0]         remainder,
    output  logic                                           done,
    output  logic                                           div_by_zero
);

    typedef enum logic [2:0] {
        IDLE,
        INIT,
        COMPUTE,
        CORRECT,
        ADJUST_SIGN,
        DONE
    } state_t;

    state_t                                                 state;
    
    logic signed    [(core_config_pkg::XLEN + 2) : 0]       partial_remainder;
    logic signed    [(core_config_pkg::XLEN - 1) : 0]       partial_quotient;
    logic signed    [(core_config_pkg::XLEN + 2) : 0]       divisor_ext;
    logic signed    [(core_config_pkg::XLEN + 2) : 0]       divisor_x2;
    logic           [5:0]                                   counter;
    logic           [5:0]                                   max_iterations;
    logic                                                   dividend_negative;
    // logic                                                   divisor_negative;
    logic                                                   quotient_negative;
    
    // FSM and Datapath
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state               <= IDLE;
            partial_remainder   <= '0;
            partial_quotient    <= '0;
            divisor_ext         <= '0;
            divisor_x2          <= '0;
            counter             <= '0;
            max_iterations      <= '0;
            quotient            <= '0;
            remainder           <= '0;
            done                <= 1'b0;
            div_by_zero         <= 1'b0;
            dividend_negative   <= 1'b0;
            // divisor_negative    <= 1'b0;
            quotient_negative   <= 1'b0;

        end else begin

            case (state)

                IDLE: begin

                    done        <= 1'b0;
                    div_by_zero <= 1'b0;
                    counter     <= '0;

                    if (start) begin

                        if (divisor == 0) begin

                            div_by_zero <= 1'b1;
                            state       <= DONE;

                        end 
                        else begin

                            state       <= INIT;

                        end
                    end
                end
                
                INIT: begin

                    // Store sign information for signed operations
                    if (is_signed) begin
                        
                        dividend_negative       <= dividend[(core_config_pkg::XLEN - 1)];
                        // divisor_negative        <= divisor[(core_config_pkg::XLEN - 1)];
                        quotient_negative       <= dividend[(core_config_pkg::XLEN - 1)] ^ divisor[(core_config_pkg::XLEN - 1)];
                        
                        // Convert to positive for computation
                        if (dividend[(core_config_pkg::XLEN - 1)]) begin

                            partial_remainder   <= {{3{1'b0}}, (~dividend + 1'b1)};  // Negate

                        end
                        else begin

                            partial_remainder   <= {{3{1'b0}}, dividend};

                        end
                            
                        if (divisor[(core_config_pkg::XLEN - 1)]) begin

                            divisor_ext         <= {{3{1'b0}}, (~divisor + 1'b1)};
                            divisor_x2          <= {{3{1'b0}}, (~divisor + 1'b1)} << 1;

                        end 
                        else begin

                            divisor_ext         <= {{3{1'b0}}, divisor};
                            divisor_x2          <= {{3{1'b0}}, divisor} << 1;
                            
                        end
                    end 
                    else begin

                        // Unsigned: just zero extend
                        dividend_negative       <= 1'b0;
                        // divisor_negative        <= 1'b0;
                        quotient_negative       <= 1'b0;
                        partial_remainder       <= {{3{1'b0}}, dividend};
                        divisor_ext             <= {{3{1'b0}}, divisor};
                        divisor_x2              <= {{3{1'b0}}, divisor} << 1;

                    end
                    
                    partial_quotient            <= '0;
                    max_iterations              <= {(core_config_pkg::XLEN + 1) / 2}[5 : 0];
                    counter                     <= '0;
                    state                       <= COMPUTE;
                end
                
                COMPUTE: begin

                    logic signed [(core_config_pkg::XLEN + 2) : 0] temp_rem;
                    logic [1:0] q_digit;
                    
                    // Left shift by 2
                    temp_rem                    = partial_remainder << 2;
                    
                    // Radix-4 quotient selection (simplified)
                    if (temp_rem >= divisor_x2) begin

                        temp_rem                = temp_rem - divisor_x2;
                        q_digit                 = 2'b10;

                    end 
                    else if (temp_rem >= divisor_ext) begin

                        temp_rem                = temp_rem - divisor_ext;
                        q_digit                 = 2'b01;

                    end 
                    else begin
                        
                        q_digit                 = 2'b00;

                    end
                    
                    partial_remainder           <= temp_rem;
                    partial_quotient            <= {partial_quotient[(core_config_pkg::XLEN - 3) : 0], q_digit};
                    counter                     <= counter + 1;
                    
                    if (counter == max_iterations - 1) begin

                        state                   <= CORRECT;

                    end
                end
                
                CORRECT: begin
                    // Adjust if remainder is too large
                    if (partial_remainder >= divisor_ext) begin

                        partial_remainder       <= partial_remainder - divisor_ext;
                        partial_quotient        <= partial_quotient + 1;
                        state                   <= CORRECT;

                    end
                    else begin

                        state                   <= ADJUST_SIGN;

                    end

                    // while (partial_remainder >= divisor_ext) begin                  // Change this thing with a sync loop --> Critical path

                    //     partial_remainder <= partial_remainder - divisor_ext;
                    //     partial_quotient <= partial_quotient + 1;

                    // end
                    // state <= ADJUST_SIGN;
                end
                
                ADJUST_SIGN: begin
                    // For signed operations, restore signs
                    if (is_signed) begin

                        // Quotient sign
                        if (quotient_negative && partial_quotient != 0) begin

                            partial_quotient    <= -partial_quotient;
                        
                        end
                        
                        // Remainder takes sign of dividend (RISC-V spec)
                        if (dividend_negative && partial_remainder != 0) begin

                            partial_remainder   <= -partial_remainder;

                        end
                    end
                    state <= DONE;
                end
                
                DONE: begin

                    if (!div_by_zero) begin

                        quotient                <= partial_quotient[(core_config_pkg::XLEN - 1) : 0];
                        remainder               <= partial_remainder[(core_config_pkg::XLEN - 1) : 0];

                    end else begin

                        // RISC-V spec: division by zero
                        quotient                <= '1;  // -1 for all bits
                        remainder               <= dividend;  // Return dividend

                    end

                    done                        <= 1'b1;
                    state                       <= IDLE;
                end

                default begin
                    state                       <= IDLE;
                end
            endcase
        end
    end

endmodule
