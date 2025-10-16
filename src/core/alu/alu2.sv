`timescale 1ns / 1ps

import core_config_pkg::XLEN;
import core_config_pkg::REG_ADDR_W;
import core_config_pkg::alu_commands_t;

/* 
 *  ALU 2 & 3 : Used for calculating advanced maths 
        - Multiplications
        - Divisions
        - Bits shifts (multiple cycles to reduce logic cost)
 */


module alu2 (
    // Standard interface
    input   logic                                           clk,
    input   logic                                           rst_n,

    // Issuer interface
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       arg0,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       arg1,
    /* verilator lint_off UNUSEDSIGNAL */
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       addr,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       imm,
    /* verilator lint_off UNUSEDSIGNAL */
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
        IDLE,
        WAIT,
        OUT
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

    // Multiplier signals
    logic                                                   mul_start;
    logic                                                   mul_done;
    logic                                                   mul_signed_a;
    logic                                                   mul_signed_b;
    logic   [((2 * core_config_pkg::XLEN) - 1) : 0]         mul_product;
    logic   [(core_config_pkg::XLEN - 1) : 0]               mul_low;
    logic   [(core_config_pkg::XLEN - 1) : 0]               mul_high;
    
    // Divider signals
    logic                                                   div_start;
    logic                                                   div_done;
    logic                                                   div_signed;
    logic   [(core_config_pkg::XLEN - 1) : 0]               div_quotient;
    logic   [(core_config_pkg::XLEN - 1) : 0]               div_remainder;
    logic                                                   div_by_zero;
    
    // Shifter signals
    logic                                                   shift_start;
    logic                                                   shift_done;
    logic                                                   shift_left;
    logic                                                   shift_arithmetic;
    logic   [(core_config_pkg::XLEN - 1) : 0]               shift_result;

    // Operation decoder
    always_comb begin
        mul_start                   = 1'b0;
        div_start                   = 1'b0;
        shift_start                 = 1'b0;
        mul_signed_a                = 1'b0;
        mul_signed_b                = 1'b0;
        div_signed                  = 1'b0;
        shift_left                  = 1'b0;
        shift_arithmetic            = 1'b0;
        unknown_instr               = 1'b0;

        unique case (cmd)
            // Multiplication operations
            core_config_pkg::c_MUL: begin
                mul_start           = 1'b1;
                mul_signed_a        = 1'b1;
                mul_signed_b        = 1'b1;
                unknown_instr       = 1'b0;

            end
            core_config_pkg::c_MULH: begin
                mul_start           = 1'b1;
                mul_signed_a        = 1'b1;
                mul_signed_b        = 1'b1;
                unknown_instr       = 1'b0;

            end
            core_config_pkg::c_MULHSU: begin
                mul_start           = 1'b1;
                mul_signed_a        = 1'b1;
                mul_signed_b        = 1'b0;
                unknown_instr       = 1'b0;

            end
            core_config_pkg::c_MULHU: begin
                mul_start           = 1'b1;
                mul_signed_a        = 1'b0;
                mul_signed_b        = 1'b0;
                unknown_instr       = 1'b0;

            end
            // Division operations
            core_config_pkg::c_DIV: begin
                div_start           = 1'b1;
                div_signed          = 1'b1;
                unknown_instr       = 1'b0;

            end
            core_config_pkg::c_DIVU: begin
                div_start           = 1'b1;
                div_signed          = 1'b0;
                unknown_instr       = 1'b0;

            end
            core_config_pkg::c_REM: begin
                div_start           = 1'b1;
                div_signed          = 1'b1;
                unknown_instr       = 1'b0;

            end
            core_config_pkg::c_REMU: begin
                div_start           = 1'b1;
                div_signed          = 1'b0;
                unknown_instr       = 1'b0;

            end
            // Shift operations
            core_config_pkg::c_SLL: begin
                shift_start         = 1'b1;
                shift_left          = 1'b1;
                shift_arithmetic    = 1'b0;
                unknown_instr       = 1'b0;

            end
            core_config_pkg::c_SRL: begin
                shift_start         = 1'b1;
                shift_left          = 1'b0;
                shift_arithmetic    = 1'b0;
                unknown_instr       = 1'b0;

            end
            core_config_pkg::c_SRA: begin
                shift_start         = 1'b1;
                shift_left          = 1'b0;
                shift_arithmetic    = 1'b1;
                unknown_instr       = 1'b0;

            end
            default: 
                unknown_instr       = 1'b1;
        endcase
    end

    // Need to add a small logic handling FSM to start / rd and so
    /*
     *  Some sync logic to handle the FSM states and evolution
     */
    always_ff @( posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state       <= IDLE;
            r_arg0      <= 32'b0;
            r_arg1      <= 32'b0;
            r_i_rd      <= 5'b0;
            r_cmd       <= core_config_pkg::c_NONE;

        end
        else begin

            state <= next_state;

            // Register the inputs to ensure they're stable for the sub-alus.
            if (state == IDLE) begin

                r_arg0      <= arg0;
                r_arg1      <= arg1;
                r_i_rd      <= i_rd;
                r_cmd       <= cmd;

            end
        end
    end

    always_comb begin

        i_error = 0;

        unique case (state)

            IDLE :  begin
                if (!unknown_instr) begin

                    next_state  = WAIT;
                    i_error = 0;

                end
                else begin

                    next_state  = IDLE;
                    i_error = 1;

                end
            end 
            WAIT : begin

                unique case (r_cmd)

                    // Change state when we've finished the operation.
                    core_config_pkg::i_MUL,
                    core_config_pkg::i_MULH,
                    core_config_pkg::i_MULHSU,
                    core_config_pkg::i_MULHU :  next_state = (mul_done) ? OUT : WAIT;
                    core_config_pkg::i_DIV,
                    core_config_pkg::i_DIVU,
                    core_config_pkg::i_REM,
                    core_config_pkg::i_REMU :   next_state = (div_done) ? OUT : WAIT;
                    core_config_pkg::i_SLL,
                    core_config_pkg::i_SRA,
                    core_config_pkg::i_SRL :    next_state = (shift_done) ? OUT : WAIT;
                    default:                    next_state = OUT;

                endcase  
            end 
            OUT : begin
                if (clear) begin

                    next_state  = IDLE;

                end
                else begin

                    next_state  = OUT;

                end
            end

        endcase
    end

    always_comb begin

        unique case (state) 

            IDLE : begin

                busy            = 1'b0;
                o_error         = 1'b0;
                res             = 32'b0;
                valid           = 1'b0;
                req             = 1'b0;
                o_rd            = 5'b0;
                     
            end
            WAIT : begin

                busy            = 1'b1;
                o_error         = 1'b0;
                res             = 32'b0;
                valid           = 1'b0;
                req             = 1'b0;
                o_rd            = 5'b0;

            end
            OUT : begin

                busy            = 1'b1;
                valid           = 1'b1;
                req             = 1'b0;
                o_rd            = r_i_rd;

                unique case (r_cmd) 

                    core_config_pkg::i_DIV,
                    core_config_pkg::i_DIVU,
                    core_config_pkg::i_REM,
                    core_config_pkg::i_REMU :   o_error = div_by_zero;
                    default:                    o_error = 1'b0;

                endcase

                unique case (r_cmd)

                    core_config_pkg::i_MUL :    res = mul_low;
                    core_config_pkg::i_MULH,
                    core_config_pkg::i_MULHSU,
                    core_config_pkg::i_MULHU :  res = mul_high;
                    core_config_pkg::i_DIV,
                    core_config_pkg::i_DIVU :   res = div_quotient;
                    core_config_pkg::i_REM,
                    core_config_pkg::i_REMU :   res = div_remainder;
                    core_config_pkg::i_SLL,
                    core_config_pkg::i_SRA,
                    core_config_pkg::i_SRL :    res = shift_result;
                    default:                    res  = 32'b0;

                endcase

            end
        endcase
    end

    // Instantiate multiplier
    booth multiplier0 (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .start                  (mul_start),
        .multiplicand           (r_arg0),
        .multiplier             (r_arg1),
        .signed_multiplicand    (mul_signed_a),
        .signed_multiplier      (mul_signed_b),
        .product                (mul_product),
        .product_low            (mul_low),
        .product_high           (mul_high),
        .done                   (mul_done)
    );
    
    // Instantiate divider
    srt divider0 (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .start                  (div_start),
        .dividend               (r_arg0),
        .divisor                (r_arg1),
        .is_signed              (div_signed),
        .quotient               (div_quotient),
        .remainder              (div_remainder),
        .done                   (div_done),
        .div_by_zero            (div_by_zero)
    );
    
    // Instantiate barrel shifter (shifts up to 8 bits per cycle)
    shift shifter0 (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .start                  (shift_start),
        .data_in                (r_arg0),
        .shift_amount           (r_arg1[5:0]),  // RISC-V uses lower 5 bits for shift amount
        .shift_left             (shift_left),
        .arithmetic             (shift_arithmetic),
        .data_out               (shift_result),
        .done                   (shift_done)
    );

endmodule
