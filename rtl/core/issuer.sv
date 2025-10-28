/*
 *  File :      rtl/core/issuer.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file define the issuer module, the one charged to 
 *              split incomming instructions into the right ALU, and start
 *              as many instruction as it can to get the maximal performance
 *              available from the core.
 */

module issuer (
    input logic clk,
    input logic clk_en,
    input logic rst_n,

    // Decoders IOs
    input  logic     [(REG_ADDR_W - 1) : 0] dec_rs1,
    input  logic     [(REG_ADDR_W - 1) : 0] dec_rs2,
    input  logic     [(REG_ADDR_W - 1) : 0] dec_rd,
    input  logic     [      (XLEN - 1) : 0] dec_imm,
    input  logic     [      (XLEN - 1) : 0] dec_address,
    input  opcodes_t                        dec_opcode,
    input  logic                            dec_illegal,
    input  logic                            dec_branch_taken,
    output logic                            dec_busy,
    output logic                            dec_flush,

    // Occupancy tracker IOs
    output logic occupancy_lock,
    input logic occupancy_exec,
    output logic [(core_config_pkg::REG_ADDR_W - 1) : 0] occupancy_rd,
    output logic [(core_config_pkg::REG_ADDR_W - 1) : 0] occupancy_rs1,
    output logic [(core_config_pkg::REG_ADDR_W - 1) : 0] occupancy_rs2,

    // Register file IO
    output logic [(core_config_pkg::REG_ADDR_W - 1) : 0] reg_ra0,
    output logic [(core_config_pkg::REG_ADDR_W - 1) : 0] reg_ra1,
    input  logic [      (core_config_pkg::XLEN - 1) : 0] reg_rd0,
    input  logic [      (core_config_pkg::XLEN - 1) : 0] reg_rd1,

    // Bypass IO
    input logic [      (core_config_pkg::XLEN - 1) : 0] bypass_data,
    input logic [(core_config_pkg::REG_ADDR_W - 1) : 0] bypass_addr,

    // ALU IOs
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu0_arg0,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu0_arg1,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu0_addr,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu0_imm,
    output alu_commands_t                                         alu0_cmd,
    output logic          [(core_config_pkg::REG_ADDR_W - 1) : 0] alu0_rd,
    input  logic                                                  alu0_busy,
    input  logic                                                  alu0_error,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu1_arg0,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu1_arg1,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu1_addr,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu1_imm,
    output alu_commands_t                                         alu1_cmd,
    output logic          [(core_config_pkg::REG_ADDR_W - 1) : 0] alu1_rd,
    input  logic                                                  alu1_busy,
    input  logic                                                  alu1_error,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu2_arg0,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu2_arg1,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu2_addr,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu2_imm,
    output alu_commands_t                                         alu2_cmd,
    output logic          [(core_config_pkg::REG_ADDR_W - 1) : 0] alu2_rd,
    input  logic                                                  alu2_busy,
    input  logic                                                  alu2_error,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu3_arg0,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu3_arg1,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu3_addr,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu3_imm,
    output alu_commands_t                                         alu3_cmd,
    output logic          [(core_config_pkg::REG_ADDR_W - 1) : 0] alu3_rd,
    input  logic                                                  alu3_busy,
    input  logic                                                  alu3_error,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu4_arg0,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu4_arg1,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu4_addr,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu4_imm,
    output alu_commands_t                                         alu4_cmd,
    output logic          [(core_config_pkg::REG_ADDR_W - 1) : 0] alu4_rd,
    input  logic                                                  alu4_busy,
    input  logic                                                  alu4_error,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu5_arg0,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu5_arg1,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu5_addr,
    output logic          [      (core_config_pkg::XLEN - 1) : 0] alu5_imm,
    output alu_commands_t                                         alu5_cmd,
    output logic          [(core_config_pkg::REG_ADDR_W - 1) : 0] alu5_rd,
    input  logic                                                  alu5_busy,
    input  logic                                                  alu5_error,

    // To commiter
    output logic halt_needed,
    input  logic flush_needed,

    // TRAP handling
    input logic halt_pending
);
    /*
     *  Flow control signals
     */
    logic                            next_instr;

    /*
     *  Storage registers
     */
    logic     [(REG_ADDR_W - 1) : 0] r_dec_rs1;
    logic     [(REG_ADDR_W - 1) : 0] r_dec_rs2;
    logic     [(REG_ADDR_W - 1) : 0] r_dec_rd;
    logic     [      (XLEN - 1) : 0] r_dec_imm;
    logic     [      (XLEN - 1) : 0] r_dec_address;
    opcodes_t                        r_dec_opcode;
    logic                            r_dec_illegal;
    logic                            r_dec_branch_taken;


    /*
     *  First, some logic to store the input from the decoder into the waiting stage
     */
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            r_dec_rs1          <= '0;
            r_dec_rs1          <= '0;
            r_dec_rd           <= '0;
            r_dec_imm          <= '0;
            r_dec_address      <= '0;
            r_dec_opcode       <= core_config_pkg::i_NOP;
            r_dec_illegal      <= 1'b0;
            r_dec_branch_taken <= 1'b0;

        end else if (next_instr) begin

            r_dec_rs1          <= dec_rs1;
            r_dec_rs1          <= dec_rs1;
            r_dec_rd           <= dec_rd;
            r_dec_imm          <= dec_imm;
            r_dec_address      <= dec_address;
            r_dec_opcode       <= dec_opcode;
            r_dec_illegal      <= dec_illegal;
            r_dec_branch_taken <= dec_branch_taken;

        end
    end

endmodule
