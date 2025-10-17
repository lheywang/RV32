// Modified Booth Multiplier (Radix-4) with AC-QR architecture
// AC (Accumulator) and QR (Quotient Register) shift together
// CRITICAL PATH OPTIMIZATION: Only 32-bit addition in AC!
// Supports: MUL, MULH, MULHU, MULHSU
`timescale 1ns/1ps

import core_config_pkg::XLEN;

module booth (
    input   logic                                           clk,
    input   logic                                           rst_n,
    input   logic                                           start,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       multiplicand,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       multiplier,
    input   logic                                           signed_multiplicand,  // 1 = signed, 0 = unsigned
    input   logic                                           signed_multiplier,    // 1 = signed, 0 = unsigned
    input   logic                                           highlow,
    output  logic   [(core_config_pkg::XLEN - 1) : 0]       res,
    output  logic                                           done
);

    typedef enum logic [1:0] {
        IDLE,
        INIT,
        COMPUTE,
        DONE
    } state_t;

    state_t state;
    
    // Classic Booth architecture with AC-QR registers
    logic   signed  [WIDTH-1:0]                             AC;             // Accumulator - 32 bits ONLY (Critical path!)
    logic           [WIDTH-1:0]                             QR;             // Quotient Register (holds multiplier, then low result)
    logic                                                   Q_minus1;       // Extra bit for Booth encoding
    
    logic   signed  [WIDTH-1:0]                             M;              // Multiplicand
    logic   signed  [WIDTH-1:0]                             M_x2;           // 2 * Multiplicand for radix-4
    logic   signed  [WIDTH-1:0]                             m_M;            // Multiplicand
    logic   signed  [WIDTH-1:0]                             m_M_x2;         // 2 * Multiplicand for radix-4
    logic           [5:0]                                   counter;
    logic           [5:0]                                   max_iterations;
    
    // FSM and Datapath
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state                   <= IDLE;
            AC                      <= '0;
            QR                      <= '0;
            Q_minus1                <= 1'b0;
            M                       <= '0;
            M_x2                    <= '0;
            counter                 <= '0;
            max_iterations          <= '0;
            res                     <= '0;
            done                    <= 1'b0;

        end else begin

            case (state)

                IDLE: begin

                    done            <= 1'b0;
                    counter         <= '0;

                    if (start) begin

                        state       <= INIT;

                    end
                end
                
                INIT: begin

                    // Initialize AC-QR architecture
                    AC              <= '0;                  // Accumulator starts at 0
                    QR              <= multiplier;          // QR holds the multiplier initially
                    Q_minus1        <= 1'b0;                // Extra bit for Booth encoding
                    
                    // Store multiplicand as pre-calculated factors.
                    M               <= multiplicand;
                    M_x2            <= multiplicand << 1;  // Pre-compute 2*M for radix-4
                    m_M             <= -multiplicand;
                    m_M_x2          <= -(multiplicand << 1);
                    
                    max_iterations  <= (WIDTH + 1) / 2;  // Radix-4: process 2 bits at a time
                    counter         <= '0;
                    state           <= COMPUTE;
                end
                
                COMPUTE: begin

                    logic           [2:0]                               booth_bits;
                    logic   signed  [(core_config_pkg::XLEN - 1) : 0]   add_value;
                    logic   signed  [(core_config_pkg::XLEN):0]         temp_ac;        // 1 extra bit for carry
                    logic           [1:0]                               padd;
                          
                    logic   signed  [(core_config_pkg::XLEN - 1) : 0]   tmp_m;
                    logic   signed  [(core_config_pkg::XLEN - 1) : 0]   tmp;
                         
                    
                    // Radix-4 Booth encoding: examine QR[1:0] and Q_minus1
                    booth_bits = {QR[1:0], Q_minus1};

                    /*
                     *  Gently ask to quartus to use a chain of selectors rather than a big fat mux.
                     *  We gained some propagation time here !
                     */
                    tmp_p_1 = (!booth_bits[0]) ? 32'b0      : M;
                    tmp_p_2 = (!booth_bits[0]) ? M 		    : M_x2;
                    tmp_n_1 = (!booth_bits[0]) ? m_M_x2     : m_M;
                    tmp_n_2 = (!booth_bits[0]) ? m_M 		: 32'b0;
                    
                    // tmp1 : positive factors
                    // tmp2 : negatives factors
                    tmp1 = (!booth_bits[1]) ? tmp_p_1       : tmp_p_2;
                    tmp2 = (!booth_bits[1]) ? tmp_n_1 :      tmp_n_2;
                    
                    // Combine boths
                    add_value = (!booth_bits[2]) ? tmp1     : tmp2;
              
                    // Performing the operation (always add, since A + -B ==> A - B)
                    temp_ac = $signed(AC) + $signed(add_value);
                    
                    // Computing the padded bits
                    if (signed_multiplicand || signed_multiplier) begin
                        padd = {2{temp_ac[WIDTH]}};
                    end
                    else begin
                        padd = 0;
                    end
                    
                    // Applying the shifts and pads
                    AC <= {padd, temp_ac[WIDTH:2]};
                    QR <= {temp_ac[1:0], QR[WIDTH-1:2]};
                    Q_minus1 <= QR[1];
                    
                    // Incrementing the counter, to quit when needed
                    counter <= counter + 1;
                    if (counter == max_iterations - 1) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin

                    // AC contains high 32 bits (for MULH variants)
                    // QR contains low 32 bits (for MUL)
                    res <= (highlow) ? AC : QR;
                    done <= 1'b1;
                    state <= IDLE;

                end
            endcase
        end
    end

endmodule
