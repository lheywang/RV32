/*
 *  File :      rtl/core/alu/alu2.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file define the ALU2 module, the one
 *              who's charged to compute multiplication, 
 *              divisions and bit shifts. It's result may
 *              take multiple cycles to get finished, up to
 *              ~80 for the division !
 *
 *              This ALU depends on three module, each handling
 *              one operation, due to the relative complexity of
 *              theses.
 */

`timescale 1ns / 1ps

import core_config_pkg::XLEN;
import core_config_pkg::REG_ADDR_W;
import core_config_pkg::alu_commands_t;

module alu2 (
    // Standard interface
    input   logic                                           clk,
    input   logic                                           rst_n,

    // Issuer interface
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       arg0,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       arg1,
    input   alu_commands_t                                  cmd,
    input   logic   [(core_config_pkg::REG_ADDR_W - 1) : 0] i_rd,
    output  logic                                           busy,
    output  logic                                           i_error,

    // Commiter interface
    output  logic   [(core_config_pkg::XLEN - 1) : 0]       res,
    output  logic   [(core_config_pkg::REG_ADDR_W - 1) : 0] o_rd,
    output  logic                                           valid,
    output  logic                                           o_error,
    output  logic                                           req,
    input   logic                                           clear

    // Additionnal interface (optionnal)
    // None for this ALU.                  
);
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        WAIT1 = 2'b01,
        WAIT2 = 2'b10,
        OUT   = 2'b11
    } state_t;

    state_t                                                 state;
    state_t                                                 next_state;

    // Registered data
    logic   [(core_config_pkg::XLEN - 1) : 0]               r_arg0;
    logic   [(core_config_pkg::XLEN - 1) : 0]               r_arg1;
    logic   [(core_config_pkg::REG_ADDR_W - 1) : 0]         r_i_rd;
    alu_commands_t                                          r_cmd;

    // Generics
    logic                                                   unknown_instr;
    logic                                                   next_o_error;
    logic   [(core_config_pkg::XLEN - 1) : 0]               next_res;
    logic   [(core_config_pkg::XLEN - 1) : 0]               res_int;

    // Multiplier signals
    logic                                                   mul_start;
    logic                                                   mul_done;
    logic                                                   mul_signed_a;
    logic                                                   mul_signed_b;
    logic   [((2 * core_config_pkg::XLEN) - 1) : 0]         mul_product;

    logic                                                   next_mul_start;
    logic                                                   next_mul_signed_a;
    logic                                                   next_mul_signed_b;
    logic                                                   out_mul_start;
    logic                                                   out_mul_signed_a;
    logic                                                   out_mul_signed_b;
    
    // Divider signals
    logic                                                   div_start;
    logic                                                   div_done;
    logic                                                   div_signed;
    logic   [(core_config_pkg::XLEN - 1) : 0]               div_quotient;
    logic   [(core_config_pkg::XLEN - 1) : 0]               div_remainder;
    logic                                                   div_by_zero;

    logic                                                   next_div_start;
    logic                                                   next_div_signed;
    logic                                                   out_div_start;
    logic                                                   out_div_signed;
       
    // Shifter signals
    logic                                                   shift_start;
    logic                                                   shift_done;
    logic                                                   shift_left;
    logic                                                   shift_arithmetic;
    logic   [(core_config_pkg::XLEN - 1) : 0]               shift_result;

    logic                                                   next_shift_start;
    logic                                                   next_shift_left;
    logic                                                   next_shift_arithmetic;
    logic                                                   out_shift_start;
    logic                                                   out_shift_left;
    logic                                                   out_shift_arithmetic;

    // Operation decoder
    always_comb begin
        next_mul_start                  = 1'b0;
        next_div_start                  = 1'b0;
        next_shift_start                = 1'b0;
        next_mul_signed_a               = 1'b0;
        next_mul_signed_b               = 1'b0;
        next_div_signed                 = 1'b0;
        next_shift_left                 = 1'b0;
        next_shift_arithmetic           = 1'b0;
        unknown_instr                   = 1'b0;

        unique case (cmd)
            // Multiplication operations
            core_config_pkg::c_MUL: begin
                next_mul_start          = 1'b1;
                next_mul_signed_a       = 1'b1;
                next_mul_signed_b       = 1'b1;
                unknown_instr           = 1'b0;

            end
            core_config_pkg::c_MULH: begin
                next_mul_start          = 1'b1;
                next_mul_signed_a       = 1'b1;
                next_mul_signed_b       = 1'b1;
                unknown_instr           = 1'b0;

            end
            core_config_pkg::c_MULHSU: begin
                next_mul_start          = 1'b1;
                next_mul_signed_a       = 1'b1;
                next_mul_signed_b       = 1'b0;
                unknown_instr           = 1'b0;

            end
            core_config_pkg::c_MULHU: begin
                next_mul_start          = 1'b1;
                next_mul_signed_a       = 1'b0;
                next_mul_signed_b       = 1'b0;
                unknown_instr           = 1'b0;

            end
            // Division operations
            core_config_pkg::c_DIV: begin
                next_div_start          = 1'b1;
                next_div_signed         = 1'b1;
                unknown_instr           = 1'b0;

            end
            core_config_pkg::c_DIVU: begin
                next_div_start          = 1'b1;
                next_div_signed         = 1'b0;
                unknown_instr           = 1'b0;

            end
            core_config_pkg::c_REM: begin
                next_div_start          = 1'b1;
                next_div_signed         = 1'b1;
                unknown_instr           = 1'b0;

            end
            core_config_pkg::c_REMU: begin
                next_div_start          = 1'b1;
                next_div_signed         = 1'b0;
                unknown_instr           = 1'b0;

            end
            // Shift operations
            core_config_pkg::c_SLL: begin
                next_shift_start        = 1'b1;
                next_shift_left         = 1'b1;
                next_shift_arithmetic   = 1'b0;
                unknown_instr           = 1'b0;

            end
            core_config_pkg::c_SRL: begin
                next_shift_start        = 1'b1;
                next_shift_left         = 1'b0;
                next_shift_arithmetic   = 1'b0;
                unknown_instr           = 1'b0;

            end
            core_config_pkg::c_SRA: begin
                next_shift_start        = 1'b1;
                next_shift_left         = 1'b0;
                next_shift_arithmetic   = 1'b1;
                unknown_instr           = 1'b0;

            end
            default: 
                unknown_instr           = 1'b1;
        endcase
    end

    /*
     *  Some sync logic to handle the FSM states and evolution
     */
    always_ff @( posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            // State
            state                       <= IDLE;

            // Registering inputs
            r_arg0                      <= 32'b0;
            r_arg1                      <= 32'b0;
            r_cmd                       <= core_config_pkg::c_NONE;
            r_i_rd                      <= 5'b0;

            // Registering the outputs of the first decoder
            mul_start                   <= 1'b0;
            div_start                   <= 1'b0;
            shift_start                 <= 1'b0;

            mul_signed_a                <= 1'b0;
            mul_signed_b                <= 1'b0;

            div_signed                  <= 1'b0;

            shift_left                  <= 1'b0;
            shift_arithmetic            <= 1'b0; 

            res_int                     <= 32'b0;

        end 
        else begin

            state                       <= next_state;
            res_int                     <= next_res;

            if (state == IDLE) begin

                // Registering inputs
                r_arg0                      <= arg0;
                r_arg1                      <= arg1;
                r_cmd                       <= cmd;
                r_i_rd                      <= i_rd;

                // Registering the outputs of the first decoder
                mul_start                   <= next_mul_start;
                div_start                   <= next_div_start;
                shift_start                 <= next_shift_start;

                mul_signed_a                <= next_mul_signed_a;
                mul_signed_b                <= next_mul_signed_b;

                div_signed                  <= next_div_signed;

                shift_left                  <= next_shift_left;
                shift_arithmetic            <= next_shift_arithmetic;  

            end
        end
    end

    /*
     *  State evolution logic
     */
    always_comb begin

        unique case (state)

            IDLE : next_state = (unknown_instr) ? IDLE : WAIT1;

            WAIT1: next_state = WAIT2;
            WAIT2: begin

                unique case (r_cmd)

                    core_config_pkg::c_MUL,
                    core_config_pkg::c_MULH,
                    core_config_pkg::c_MULHSU,
                    core_config_pkg::c_MULHU:   next_state = (mul_done)     ? OUT : state;

                    core_config_pkg::c_DIV,
                    core_config_pkg::c_DIVU,
                    core_config_pkg::c_REM,
                    core_config_pkg::c_REMU:    next_state = (div_done)     ? OUT : state;

                    core_config_pkg::c_SLL,
                    core_config_pkg::c_SRL,
                    core_config_pkg::c_SRA:     next_state = (shift_done)   ? OUT : state;
                    default :                   next_state = IDLE;

                endcase

            end

            OUT : next_state = (clear) ? IDLE : state;

        endcase

    end

    /*
     *  Controlling the output logic
     */
    always_comb begin

        unique case (state)

            IDLE : begin

                out_mul_start           = 1'b0;
                out_div_start           = 1'b0;
                out_shift_start         = 1'b0;

                out_div_signed          = 1'b0;
                out_mul_signed_a        = 1'b0;
                out_mul_signed_b        = 1'b0;
                out_shift_arithmetic    = 1'b0;
                out_shift_left          = 1'b0;

                next_res                = 32'b0;
                res                     = 32'b0;

                busy                    = 1'b0;
                o_rd                    = 5'b0;
                valid                   = 1'b0;

            end
            WAIT1 : begin

                out_mul_start           = mul_start;
                out_div_start           = div_start;
                out_shift_start         = shift_start;

                out_div_signed          = div_signed;
                out_mul_signed_a        = mul_signed_a;
                out_mul_signed_b        = mul_signed_b;
                out_shift_arithmetic    = shift_arithmetic;
                out_shift_left          = shift_left;

                next_res                = 32'b0;
                res                     = 32'b0;

                busy                    = 1'b1;
                o_rd                    = 5'b0;
                valid                   = 1'b0;

            end
            WAIT2 : begin

                out_mul_start           = 1'b0;
                out_div_start           = 1'b0;
                out_shift_start         = 1'b0;

                // We hold theses signals all along the computation
                out_div_signed          = div_signed;
                out_mul_signed_a        = mul_signed_a;
                out_mul_signed_b        = mul_signed_b;
                out_shift_arithmetic    = shift_arithmetic;
                out_shift_left          = shift_left;

                busy                    = 1'b1;
                o_rd                    = 5'b0;
                valid                   = 1'b0;

                res                     = 32'b0;

                unique case (r_cmd)

                    core_config_pkg::c_MUL:     next_res    = mul_product[(core_config_pkg::XLEN - 1) : 0];
                    core_config_pkg::c_MULH,
                    core_config_pkg::c_MULHSU,
                    core_config_pkg::c_MULHU:   next_res    = mul_product[((2 * core_config_pkg::XLEN) - 1) : core_config_pkg::XLEN];

                    core_config_pkg::c_DIV,
                    core_config_pkg::c_DIVU:    next_res    = div_quotient;
                    core_config_pkg::c_REM,
                    core_config_pkg::c_REMU:    next_res    = div_remainder;

                    core_config_pkg::c_SLL,
                    core_config_pkg::c_SRL,
                    core_config_pkg::c_SRA:     next_res    = shift_result;
                    default :                   next_res    = 32'b0;

                endcase

            end
            OUT : begin

                out_mul_start           = 1'b0;
                out_div_start           = 1'b0;
                out_shift_start         = 1'b0;

                // We hold theses signals all along the computation
                out_div_signed          = 1'b0;
                out_mul_signed_a        = 1'b0;
                out_mul_signed_b        = 1'b0;
                out_shift_arithmetic    = 1'b0;
                out_shift_left          = 1'b0;

                busy                    = 1'b1;
                o_rd                    = r_i_rd;
                valid                   = 1'b1;

                next_res                = res_int;
                res                     = res_int;

            end 
        endcase
    end

    /*
     *  Static assignements
     */

    assign i_error = unknown_instr & ~busy;
    assign o_error = div_by_zero;   // This is the only source of error in the ALU.
    assign req = 1'b0;              // Unused signal here

    /*
     *  Then, instantiate the different sub-elements, for each operations.
     */

    booth multiplier (
        .clk                (clk),
        .rst_n              (rst_n),
        .start              (out_mul_start),
        .X_signed           (out_mul_signed_a),
        .Y_signed           (out_mul_signed_b),
        .X                  (r_arg0),
        .Y                  (r_arg1),
        .valid              (mul_done),
        .Z                  (mul_product)
    );

    srt divider (
        .clk                (clk),
        .rst_n              (rst_n),
        .start              (out_div_start),
        .dividend_signed    (out_div_signed),
        .divisor_signed     (out_div_signed),
        .dividend           (r_arg0),
        .divisor            (r_arg1),
        .valid              (div_done),
        .quotient           (div_quotient),
        .remainder          (div_remainder),
        .div_by_zero        (div_by_zero)
    );

    shift shifter (
        .clk                (clk),
        .rst_n              (rst_n),
        .start              (out_shift_start),
        .data_in            (r_arg0),
        .shift_amount       (r_arg1[($clog2(core_config_pkg::XLEN)-1) : 0]),
        .shift_left         (out_shift_left),
        .arithmetic         (out_shift_arithmetic),
        .data_out           (shift_result),
        .done               (shift_done)
    );

endmodule
