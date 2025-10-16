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
    // Generics
    logic                                                   done;

    // Multiplier signals
    logic                                                   mul_start;
    logic                                                   mul_done;
    logic                                                   mul_signed_a;
    logic                                                   mul_signed_b;
    logic [((2 * core_config_pkg::XLEN) - 1) : 0]           mul_product;
    logic [(core_config_pkg::XLEN - 1):0]                   mul_low;
    logic [(core_config_pkg::XLEN - 1):0]                   mul_high;
    
    // Divider signals
    logic                                                   div_start;
    logic                                                   div_done;
    logic                                                   div_signed;
    logic [(core_config_pkg::XLEN - 1):0]                   div_quotient;
    logic [(core_config_pkg::XLEN - 1):0]                   div_remainder;
    
    // Shifter signals
    logic                                                   shift_start;
    logic                                                   shift_done;
    logic                                                   shift_left;
    logic                                                   shift_arithmetic;
    logic [(core_config_pkg::XLEN - 1):0]                   shift_result;

    // Operation decoder
    always_comb begin
        mul_start = 1'b0;
        div_start = 1'b0;
        shift_start = 1'b0;
        mul_signed_a = 1'b0;
        mul_signed_b = 1'b0;
        div_signed = 1'b0;
        shift_left = 1'b0;
        shift_arithmetic = 1'b0;

        case (cmd)
            // Multiplication operations
            core_config_pkg::i_MUL: begin
                mul_start = 1'b1;
                mul_signed_a = 1'b1;
                mul_signed_b = 1'b1;
            end
            core_config_pkg::i_MULH: begin
                mul_start = 1'b1;
                mul_signed_a = 1'b1;
                mul_signed_b = 1'b1;
            end
            core_config_pkg::i_MULHSU: begin
                mul_start = 1'b1;
                mul_signed_a = 1'b1;
                mul_signed_b = 1'b0;
            end
            core_config_pkg::i_MULHU: begin
                mul_start = 1'b1;
                mul_signed_a = 1'b0;
                mul_signed_b = 1'b0;
            end
            // Division operations
            core_config_pkg::i_DIV: begin
                div_start = 1'b1;
                div_signed = 1'b1;
            end
            core_config_pkg::i_DIVU: begin
                div_start = 1'b1;
                div_signed = 1'b0;
            end
            core_config_pkg::i_REM: begin
                div_start = 1'b1;
                div_signed = 1'b1;
            end
            core_config_pkg::i_REMU: begin
                div_start = 1'b1;
                div_signed = 1'b0;
            end
            // Shift operations
            core_config_pkg::i_SLL: begin
                shift_start = 1'b1;
                shift_left = 1'b1;
                shift_arithmetic = 1'b0;
            end
            core_config_pkg::i_SRL: begin
                shift_start = 1'b1;
                shift_left = 1'b0;
                shift_arithmetic = 1'b0;
            end
            core_config_pkg::i_SRA: begin
                shift_start = 1'b1;
                shift_left = 1'b0;
                shift_arithmetic = 1'b1;
            end
            default: ;
        endcase
    end

    // Done signal (mux based on operation type)
    always_comb begin
        case (cmd)
            core_config_pkg::i_MUL, 
            core_config_pkg::i_MULH, 
            core_config_pkg::i_MULHSU, 
            core_config_pkg::i_MULHU:
                done = mul_done;
            core_config_pkg::i_DIV, 
            core_config_pkg::i_DIVU, 
            core_config_pkg::i_REM, 
            core_config_pkg::i_REMU:
                done = div_done;
            core_config_pkg::i_SLL, 
            core_config_pkg::i_SRL, 
            core_config_pkg::i_SRA:
                done = shift_done;
            default:
                done = 1'b1;
        endcase
    end

    // Need to add a small logic handling FSM to start / rd and so

    // Instantiate multiplier
    booth multiplier0 (
        .clk(clk),
        .rst_n(rst_n),
        .start(mul_start),
        .multiplicand(rs1),
        .multiplier(rs2),
        .signed_multiplicand(mul_signed_a),
        .signed_multiplier(mul_signed_b),
        .product(mul_product),
        .product_low(mul_low),
        .product_high(mul_high),
        .done(mul_done)
    );
    
    // Instantiate divider
    srt divider0 (
        .clk(clk),
        .rst_n(rst_n),
        .start(div_start),
        .dividend(rs1),
        .divisor(rs2),
        .is_signed(div_signed),
        .quotient(div_quotient),
        .remainder(div_remainder),
        .done(div_done),
        .div_by_zero(div_by_zero)
    );
    
    // Instantiate barrel shifter (shifts up to 8 bits per cycle)
    shift shifter0 (
        .clk(clk),
        .rst_n(rst_n),
        .start(shift_start),
        .data_in(rs1),
        .shift_amount(rs2[4:0]),  // RISC-V uses lower 5 bits for shift amount
        .shift_left(shift_left),
        .arithmetic(shift_arithmetic),
        .data_out(shift_result),
        .done(shift_done)
    );

endmodule
