`timescale 1ns / 1ps
import core_config_pkg::XLEN;
import core_config_pkg::MAX_SHIFT_PER_CYCLE;

module shift (
    input   logic                                           clk,
    input   logic                                           rst_n,
    input   logic                                           start,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       data_in,
    input   logic   [($clog2(core_config_pkg::XLEN)-1) : 0] shift_amount,
    input   logic                                           shift_left,
    input   logic                                           arithmetic,
    output  logic   [(core_config_pkg::XLEN - 1) : 0]       data_out,
    output  logic                                           done
);
    /*
     *  Parameters
     */
    localparam SHIFT_SIZE = ($clog2(core_config_pkg::XLEN) - 1);

    /*
     *  Enums
     */
    typedef enum logic [0:0] {
        IDLE    = 1'b0,
        SHIFT   = 1'b1
    } state_t;

    state_t                                                 pres_state;
    state_t                                                 next_state;

    /*
     *  Registers
     */
    logic   [(core_config_pkg::XLEN - 1) : 0]               r_shifted;
    logic   [SHIFT_SIZE : 0]                                r_remaining;
    logic                                                   r_shift_left;
    logic                                                   r_arithmetic;
    
    /* 
     *  Temp storage
     */
    logic   [(core_config_pkg::XLEN - 1) : 0]               next_shifted;
    logic   [SHIFT_SIZE : 0]                                next_remaining;   
    logic                                                   next_shift_left;
    logic                                                   next_arithmetic;
    logic                                                   next_done;
    logic   [(core_config_pkg::XLEN - 1) : 0]               next_out;

    /*
     *  Synchronous logic
     */
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            r_shifted       <= 'b0;
            r_remaining     <= 'b0;

            r_shift_left    <= 1'b0;
            r_arithmetic    <= 1'b0;

            pres_state      <= IDLE;

            data_out        <= '0;
            done            <= 1'b0;

        end
        else begin

            r_remaining     <= next_remaining;
            r_shifted       <= next_shifted;

            r_shift_left    <= next_shift_left;
            r_arithmetic    <= next_arithmetic;

            pres_state      <= next_state;

            data_out        <= next_out;
            done            <= next_done;

        end
    end 

    /*
     *  Combinational logic
     */
    always_comb begin

        unique case (pres_state)

            IDLE : begin

                if (start) begin

                    next_shifted        = data_in;
                    next_remaining      = shift_amount;

                    next_shift_left     = shift_left;
                    next_arithmetic     = arithmetic;

                    next_state          = SHIFT;

                    next_done           = 1'b0;
                    next_out            = 'b0;

                end
                else begin

                    next_shifted        = 'b0;
                    next_remaining      = 'b0;

                    next_shift_left     = 1'b0;
                    next_arithmetic     = 1'b0;

                    next_state          = IDLE;

                    next_done           = done;
                    next_out            = data_out;

                end
            end

            SHIFT : begin

                /*
                 *  Improvements ideas : 
                 *
                 *  Actually, the limiting factor of the ALU2 is right here, the shifts logics.
                 *  To ensure a maximal operating frequency, the shift is limited to 3 bits (
                 *  see core_config_pkg.sv).
                 *  
                 *  That's fine in most case, but for some, it may be cool to fasten up the 
                 *  process. Thus, a bypass shift with a fixed 8 bits could be imagined, and
                 *  called when r_remaining is greater than this value.
                 *
                 *  Will be *perhaps* be done in a future revision, when the testing profiled
                 *  the right values.
                 */
                
                logic [SHIFT_SIZE : 0] step;

                next_shift_left     = r_shift_left;
                next_arithmetic     = r_arithmetic;
                     
                step = (r_remaining > core_config_pkg::MAX_SHIFT_PER_CYCLE) ? 
                        core_config_pkg::MAX_SHIFT_PER_CYCLE : 
                        r_remaining;

                next_remaining  = (r_remaining > core_config_pkg::MAX_SHIFT_PER_CYCLE) ? 
                        (r_remaining - core_config_pkg::MAX_SHIFT_PER_CYCLE) :
                        (0);
                
                unique case ({r_shift_left, r_arithmetic})

                    2'b00 : next_shifted    = r_shifted >> step;
                    2'b01 : next_shifted    = $signed(r_shifted) >>> step;
                    2'b10,
                    2'b11 : next_shifted    = r_shifted << step;

                endcase

                if (r_remaining == 0) begin

                    next_state          = IDLE;
                    next_done           = 1'b1;
                    next_out            = r_shifted;

                end
                else begin

                    next_state          = SHIFT;
                    next_done           = 1'b0;
                    next_out            = 'b0;

                end
            end
        endcase
    end

endmodule
