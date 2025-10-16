`timescale 1ns / 1ps
import core_config_pkg::XLEN;

module booth (
    input   logic                                           clk,
    input   logic                                           rst_n,
    input   logic                                           start,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       multiplicand,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       multiplier,
    input   logic                                           signed_multiplicand,  // 1 = signed, 0 = unsigned
    input   logic                                           signed_multiplier,    // 1 = signed, 0 = unsigned
    output  logic   [((2 * core_config_pkg::XLEN) - 1) : 0] product,
    output  logic   [(core_config_pkg::XLEN - 1) : 0]       product_low,   // For MUL
    output  logic   [(core_config_pkg::XLEN - 1) : 0]       product_high,  // For MULH/MULHU/MULHSU
    output  logic                                           done
);

    typedef enum logic [1:0] {
        IDLE,
        INIT,
        COMPUTE,
        DONE
    } state_t;

    state_t                                                     state;
    
    logic signed    [((2 * core_config_pkg::XLEN) + 1) : 0]     partial_product;
    logic signed    [((2 * core_config_pkg::XLEN) - 1) : 0]     extended_multiplicand;
    logic signed    [((2 * core_config_pkg::XLEN) - 1) : 0]     multiplicand_x2;
    logic           [5:0]                                       counter;
    logic           [5:0]                                       max_iterations;
    
    // Sign extension logic based on signedness
    function automatic logic signed [((2 * core_config_pkg::XLEN) - 1) : 0] sign_extend_multiplicand(
        input logic [(core_config_pkg::XLEN - 1) : 0]           value,
        input logic                                             is_signed
    );
        if (is_signed)
            return {{core_config_pkg::XLEN{value[(core_config_pkg::XLEN -1)]}}, value}; // Sign extend
        else
            return {{core_config_pkg::XLEN{1'b0}},                              value}; // Zero extend
    endfunction
    
    // FSM and Datapath
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state                   <= IDLE;
            partial_product         <= '0;
            extended_multiplicand   <= '0;
            multiplicand_x2         <= '0;
            counter                 <= '0;
            max_iterations          <= '0;
            product                 <= '0;
            product_low             <= '0;
            product_high            <= '0;
            done                    <= 1'b0;

        end else begin

            unique case (state)

                IDLE: begin

                    done            <= 1'b0;
                    counter         <= '0;

                    if (start) begin

                        state       <= INIT;

                    end
                end
                
                INIT: begin

                    // Handle unsigned multiplier by zero-extending
                    if (signed_multiplier) begin

                        partial_product <= {{(core_config_pkg::XLEN + 1){1'b0}}, multiplier, 1'b0};

                    end
                    else begin

                        partial_product <= {{(core_config_pkg::XLEN + 1){1'b0}}, multiplier, 1'b0};

                    end
                    
                    // Sign/zero extend multiplicand based on signedness
                    extended_multiplicand   <= sign_extend_multiplicand(multiplicand, signed_multiplicand);
                    multiplicand_x2         <= sign_extend_multiplicand(multiplicand, signed_multiplicand) << 1;
                    
                    max_iterations          <= {(core_config_pkg::XLEN + 1) / 2}[5 : 0];
                    counter                 <= '0;
                    state                   <= COMPUTE;

                end
                
                COMPUTE: begin
                    logic           [2:0]                                   booth_bits;
                    logic signed    [((2 * core_config_pkg::XLEN) + 1) : 0] temp_pp;
                    
                    booth_bits      = partial_product[2:0];
                    temp_pp         = partial_product;
                    
                    // Radix-4 Booth encoding
                    case (booth_bits)
                        3'b001, 3'b010: temp_pp[((2 * core_config_pkg::XLEN) + 1) : 2] = 
                            partial_product[((2 * core_config_pkg::XLEN) + 1) : 2] + extended_multiplicand;  // +1M
                        3'b011:         temp_pp[((2 * core_config_pkg::XLEN) + 1) : 2] = 
                            partial_product[((2 * core_config_pkg::XLEN) + 1) : 2] + multiplicand_x2;        // +2M
                        3'b100:         temp_pp[((2 * core_config_pkg::XLEN) + 1) : 2] = 
                            partial_product[((2 * core_config_pkg::XLEN) + 1) : 2] - multiplicand_x2;        // -2M
                        3'b101, 3'b110: temp_pp[((2 * core_config_pkg::XLEN) + 1) : 2] = 
                            partial_product[((2 * core_config_pkg::XLEN) + 1) : 2] - extended_multiplicand;  // -1M
                        3'b000, 3'b111: ; // +0
                    endcase
                    
                    // Arithmetic right shift by 2
                    partial_product <= $signed(temp_pp) >>> 2;
                    counter         <= counter + 1;
                    
                    if (counter == max_iterations - 1) begin

                        state       <= DONE;

                    end
                end
                
                DONE: begin

                    product         <= partial_product[(2 * core_config_pkg::XLEN) : 1];
                    product_low     <= partial_product[(core_config_pkg::XLEN - 1) : 0];                            // MUL result
                    product_high    <= partial_product[((2 * core_config_pkg::XLEN) - 1): core_config_pkg::XLEN];   // MULH/MULHU/MULHSU result
                    done            <= 1'b1;
                    state           <= IDLE;

                end
            endcase
        end
    end

endmodule
