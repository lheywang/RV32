`timescale 1ns / 1ps
import core_config_pkg::XLEN;
import core_config_pkg::MAX_SHIFT_PER_CYCLE;

module shift (
    input   logic                                           clk,
    input   logic                                           rst_n,
    input   logic                                           start,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       data_in,
    input   logic   [5:0]                                   shift_amount,
    input   logic                                           shift_left,
    input   logic                                           arithmetic,
    output  logic   [(core_config_pkg::XLEN - 1) : 0]       data_out,
    output  logic                                           done
);

    typedef enum logic [1:0] {
        IDLE,
        INIT,
        SHIFT,
        DONE
    } state_t;

    state_t                                                 state;
    
    logic   [(core_config_pkg::XLEN - 1) : 0]               shift_reg;
    logic   [5:0]                                           remaining_shift;
    logic   [5:0]                                           current_shift;
    logic                                                   stored_left;
    logic                                                   stored_arith;
    
    function automatic logic [(core_config_pkg::XLEN - 1) : 0] barrel_shift_comb(
        input   logic   [(core_config_pkg::XLEN - 1) : 0]   data,
        input   logic   [2:0]                               amount,
        input   logic                                       left,
        input   logic                                       arith
    );
        logic [(core_config_pkg::XLEN - 1) : 0]             result;
        
        if (left) begin

            result = data << amount;

        end else begin

            if (arith) begin

                result = $signed(data) >>> amount;

            end
            else begin

                result = data >> amount;

            end
        end
        
        return result;
    endfunction
    
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state                       <= IDLE;
            shift_reg                   <= '0;
            remaining_shift             <= '0;
            current_shift               <= '0;
            stored_left                 <= '0;
            stored_arith                <= '0;
            data_out                    <= '0;
            done                        <= 1'b0;

        end else begin

            case (state)

                IDLE: begin

                    done                <= 1'b0;

                    if (start) begin

                        state           <= INIT;

                    end
                end
                
                INIT: begin

                    shift_reg           <= data_in;
                    remaining_shift     <= shift_amount;
                    stored_left         <= shift_left;
                    stored_arith        <= arithmetic;
                    
                    if (shift_amount == 0) begin

                        state           <= DONE;

                    end else begin

                        state           <= SHIFT;

                    end
                end
                
                SHIFT: begin

                    if (remaining_shift > core_config_pkg::MAX_SHIFT_PER_CYCLE) begin

                        current_shift   <= core_config_pkg::MAX_SHIFT_PER_CYCLE;

                    end 
                    else begin

                        current_shift   <= remaining_shift;

                    end
                    
                    shift_reg           <= barrel_shift_comb(
                                            shift_reg, 
                                            current_shift[2:0],
                                            stored_left,
                                            stored_arith
                                        );
                    
                    remaining_shift <= remaining_shift - current_shift;
                    
                    if (remaining_shift == MAX_SHIFT_PER_CYCLE) begin

                        state           <= DONE;

                    end
                end
                
                DONE: begin

                    data_out            <= shift_reg;
                    done                <= 1'b1;
                    state               <= IDLE;

                end
            endcase
        end
    end

endmodule
