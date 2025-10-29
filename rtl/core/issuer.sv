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

import core_config_pkg::XLEN;
import core_config_pkg::alu_commands_t;

module issuer (
    input logic clk,
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
    output logic                                                  alu1_predict_in,
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
     *  Storage types : 
     */
    typedef enum logic [3:0] {
        ALU0,
        ALU1,
        ALU2,
        ALU4,
        ALU5,
        NONE
    } alu_t;

    /*
     *  Flows controls
     */
    alu_t                            next_alu;

    logic                            prog_enabled;

    /*
     *  Storage registers
     */
    logic     [(REG_ADDR_W - 1) : 0] r_dec_rs1;
    logic     [(REG_ADDR_W - 1) : 0] r_dec_rs2;
    logic     [(REG_ADDR_W - 1) : 0] r_dec_rd;
    logic     [      (XLEN - 1) : 0] r_dec_imm;
    logic     [      (XLEN - 1) : 0] r_dec_address;
    opcodes_t                        r_dec_opcode;
    logic                            r_dec_branch_taken;


    /*
     *  First, some logic to store the input from the decoder into the waiting stage
     */
    always_ff @(posedge clk or negedge rst_n or negedge flush_needed) begin

        if (!rst_n || !flush_needed) begin

            r_dec_rs1          <= '0;
            r_dec_rs2          <= '0;
            r_dec_rd           <= '0;
            r_dec_imm          <= '0;
            r_dec_address      <= '0;
            r_dec_opcode       <= core_config_pkg::i_NOP;
            r_dec_branch_taken <= 1'b0;

        end else if (occupancy_exec && prog_enabled) begin

            r_dec_rs1          <= dec_rs1;
            r_dec_rs2          <= dec_rs2;
            r_dec_rd           <= dec_rd;
            r_dec_imm          <= dec_imm;
            r_dec_address      <= dec_address;
            r_dec_opcode       <= dec_opcode;
            r_dec_branch_taken <= dec_branch_taken;

        end
    end

    /*
     *  Registers for the output stage :
     */
    logic          [      (core_config_pkg::XLEN - 1) : 0] next_alu_addr;
    logic          [      (core_config_pkg::XLEN - 1) : 0] next_alu_imm;
    alu_commands_t                                         next_alu_cmd;
    logic          [(core_config_pkg::REG_ADDR_W - 1) : 0] next_alu_rd;
    logic                                                  arg1_imm;

    /*
     *  Then, some logic to remove any conflicts. This is done within the
     *  occupancy module, and return a bit : occupancy_exec that we directly
     *  use a evolution enabled bit.
     */
    always_comb begin

        // Asking the occupancy tracker the next required bit.
        occupancy_lock = 1'b1;
        occupancy_rd = r_dec_rd;
        occupancy_rs1 = r_dec_rs1;
        occupancy_rs2 = r_dec_rs2;

        // Asking the register file to output the right data
        reg_ra0 = r_dec_rs1;
        reg_ra1 = r_dec_rs2;

        // Defaults :
        next_alu_cmd = core_config_pkg::c_NONE;
        next_alu_addr = r_dec_address;
        next_alu_rd = r_dec_rd;
        next_alu_imm = r_dec_imm;
        next_alu = NONE;

        arg1_imm = 1'b0;  // We select the arg1 by default.

        // Decide which ALU is the next : 
        unique case (r_dec_opcode)

            core_config_pkg::i_NOP,
            core_config_pkg::i_FENCE,
            core_config_pkg::i_JAL,
            core_config_pkg::i_JALR : begin

            end

            /*
             *  ALU 0 
             */
            core_config_pkg::i_LUI,
            core_config_pkg::i_AUIPC,
            core_config_pkg::i_ADDI,
            core_config_pkg::i_XORI,
            core_config_pkg::i_ANDI :  begin

                next_alu = ALU0;
                arg1_imm = 1'b1;

            end
            core_config_pkg::i_ORI, 
            core_config_pkg::i_ADD,
            core_config_pkg::i_SUB,
            core_config_pkg::i_OR,
            core_config_pkg::i_AND,
            core_config_pkg::i_XOR :
            next_alu = ALU0;

            /*
             *  ALU 1
             */
            core_config_pkg::i_SLTI, core_config_pkg::i_SLTIU: begin

                next_alu = ALU1;
                arg1_imm = 1'b1;

            end
            core_config_pkg::i_SLT,
            core_config_pkg::i_SLTU,
            core_config_pkg::i_BEQ,
            core_config_pkg::i_BNE,
            core_config_pkg::i_BLT,
            core_config_pkg::i_BGE,
            core_config_pkg::i_BLTU,
            core_config_pkg::i_BGEU :
            next_alu = ALU0;


            /*
             *  ALU 2 & 3 
             */
            core_config_pkg::i_SLLI, core_config_pkg::i_SRAI, core_config_pkg::i_SRLI: begin

                next_alu = ALU2;
                arg1_imm = 1'b1;

            end

            core_config_pkg::i_SLL,
            core_config_pkg::i_SRL,
            core_config_pkg::i_SRA ,
            core_config_pkg::i_MUL,
            core_config_pkg::i_MULH,
            core_config_pkg::i_MULHU,
            core_config_pkg::i_MULHSU,
            core_config_pkg::i_DIV,
            core_config_pkg::i_DIVU,
            core_config_pkg::i_REM,
            core_config_pkg::i_REMU :
            next_alu = ALU2;


            /*
             *  ALU 4
             */
            core_config_pkg::i_CSRRWI, core_config_pkg::i_CSRRSI, core_config_pkg::i_CSRRCI: begin

                next_alu = ALU4;
                arg1_imm = 1'b1;

            end
            core_config_pkg::i_CSRRW, core_config_pkg::i_CSRRS, core_config_pkg::i_CSRRC:
            next_alu = ALU4;

            /*
             *  ALU 5
             */
            core_config_pkg::i_LB,
            core_config_pkg::i_LH,
            core_config_pkg::i_LW,
            core_config_pkg::i_LBU,
            core_config_pkg::i_LHU,
            core_config_pkg::i_SB,
            core_config_pkg::i_SH,
            core_config_pkg::i_SW :
            next_alu = ALU4;

            // Ucode :
            core_config_pkg::i_ECALL, core_config_pkg::i_EBREAK, core_config_pkg::i_MRET: begin

            end
        endcase

        // Decide the next alu command : 

        /*
         *  Since the ENUMS aren't the same, this cause a lot of logic. Could vastly be
         *  optimized away by changing the alu_commands_t to the raw instruction into the 
         *  ALUs, and then, just copy.
         *  For a first version, it's done like that, and if that don't cause timing issues,
         *  well'see.
         */
        unique case (r_dec_opcode)

            core_config_pkg::i_NOP,
            core_config_pkg::i_FENCE,
            core_config_pkg::i_JAL,
            core_config_pkg::i_JALR :
            next_alu_cmd = core_config_pkg::c_NONE;

            /*
             *  ALU 0 
             */
            core_config_pkg::i_LUI,
            core_config_pkg::i_AUIPC,
            core_config_pkg::i_ADDI,
            core_config_pkg::i_ADD :
            next_alu_cmd = core_config_pkg::c_ADD;
            core_config_pkg::i_XORI, core_config_pkg::i_XOR: next_alu_cmd = core_config_pkg::c_XOR;
            core_config_pkg::i_ANDI, core_config_pkg::i_AND: next_alu_cmd = core_config_pkg::c_AND;
            core_config_pkg::i_ORI, core_config_pkg::i_OR: next_alu_cmd = core_config_pkg::c_OR;
            core_config_pkg::i_SUB: next_alu_cmd = core_config_pkg::c_SUB;

            /*
             *  ALU 1
             */
            core_config_pkg::i_SLT, core_config_pkg::i_SLTI: next_alu_cmd = core_config_pkg::c_SLT;
            core_config_pkg::i_SLTU, core_config_pkg::i_SLTIU:
            next_alu_cmd = core_config_pkg::c_SLTU;
            core_config_pkg::i_BEQ: next_alu_cmd = core_config_pkg::c_BEQ;
            core_config_pkg::i_BNE: next_alu_cmd = core_config_pkg::c_BNE;
            core_config_pkg::i_BLT: next_alu_cmd = core_config_pkg::c_BLT;
            core_config_pkg::i_BGE: next_alu_cmd = core_config_pkg::c_BGE;
            core_config_pkg::i_BLTU: next_alu_cmd = core_config_pkg::c_BLTU;
            core_config_pkg::i_BGEU: next_alu_cmd = core_config_pkg::c_BGEU;

            /*
             *  ALU 2 & 3
             */
            core_config_pkg::i_SLL, core_config_pkg::i_SLLI: next_alu_cmd = core_config_pkg::c_SLL;
            core_config_pkg::i_SRL, core_config_pkg::i_SRLI: next_alu_cmd = core_config_pkg::c_SRL;
            core_config_pkg::i_SRA, core_config_pkg::i_SRAI: next_alu_cmd = core_config_pkg::c_SRA;
            core_config_pkg::i_MUL: next_alu_cmd = core_config_pkg::c_MUL;
            core_config_pkg::i_MULH: next_alu_cmd = core_config_pkg::c_MULH;
            core_config_pkg::i_MULHU: next_alu_cmd = core_config_pkg::c_MULHU;
            core_config_pkg::i_MULHSU: next_alu_cmd = core_config_pkg::c_MULHSU;
            core_config_pkg::i_DIV: next_alu_cmd = core_config_pkg::c_DIV;
            core_config_pkg::i_DIVU: next_alu_cmd = core_config_pkg::c_DIVU;
            core_config_pkg::i_REM: next_alu_cmd = core_config_pkg::c_REM;
            core_config_pkg::i_REMU: next_alu_cmd = core_config_pkg::c_REMU;
            /*
             *  ALU 4
             */
            core_config_pkg::i_CSRRW, core_config_pkg::i_CSRRWI:
            next_alu_cmd = core_config_pkg::c_CSRRW;
            core_config_pkg::i_CSRRS, core_config_pkg::i_CSRRSI:
            next_alu_cmd = core_config_pkg::c_CSRRS;
            core_config_pkg::i_CSRRC, core_config_pkg::i_CSRRCI:
            next_alu_cmd = core_config_pkg::c_CSRRC;

            /*
             *  ALU 5
             */
            core_config_pkg::i_LB:  next_alu_cmd = core_config_pkg::c_LB;
            core_config_pkg::i_LH:  next_alu_cmd = core_config_pkg::c_LH;
            core_config_pkg::i_LW:  next_alu_cmd = core_config_pkg::c_LW;
            core_config_pkg::i_LBU: next_alu_cmd = core_config_pkg::c_LBU;
            core_config_pkg::i_LHU: next_alu_cmd = core_config_pkg::c_LHU;
            core_config_pkg::i_SB:  next_alu_cmd = core_config_pkg::c_SB;
            core_config_pkg::i_SH:  next_alu_cmd = core_config_pkg::c_SH;
            core_config_pkg::i_SW:  next_alu_cmd = core_config_pkg::c_SW;

            // Ucode :
            core_config_pkg::i_ECALL, core_config_pkg::i_EBREAK, core_config_pkg::i_MRET:
            next_alu_cmd = core_config_pkg::c_NONE;

        endcase
    end

    /*
     *  Latching the alu commands into the right bus : 
     */
    always_ff @(posedge clk or negedge rst_n or negedge flush_needed) begin

        if (!rst_n || !flush_needed) begin

            alu0_arg0 <= '0;
            alu0_arg1 <= '0;
            alu0_addr <= '0;
            alu0_imm  <= '0;
            alu0_cmd  <= core_config_pkg::c_NONE;
            alu0_rd   <= '0;
            alu1_arg0 <= '0;
            alu1_arg1 <= '0;
            alu1_addr <= '0;
            alu1_imm  <= '0;
            alu1_cmd  <= core_config_pkg::c_NONE;
            alu1_rd   <= '0;
            alu2_arg0 <= '0;
            alu2_arg1 <= '0;
            alu2_addr <= '0;
            alu2_imm  <= '0;
            alu2_cmd  <= core_config_pkg::c_NONE;
            alu2_rd   <= '0;
            alu3_arg0 <= '0;
            alu3_arg1 <= '0;
            alu3_addr <= '0;
            alu3_imm  <= '0;
            alu3_cmd  <= core_config_pkg::c_NONE;
            alu3_rd   <= '0;
            alu4_arg0 <= '0;
            alu4_arg1 <= '0;
            alu4_addr <= '0;
            alu4_imm  <= '0;
            alu4_cmd  <= core_config_pkg::c_NONE;
            alu4_rd   <= '0;
            alu5_arg0 <= '0;
            alu5_arg1 <= '0;
            alu5_addr <= '0;
            alu5_imm  <= '0;
            alu5_cmd  <= core_config_pkg::c_NONE;
            alu5_rd   <= '0;

            prog_enabled <= 1'b1;

        end else if (occupancy_exec) begin

            alu1_predict_in <= r_dec_branch_taken;

            if (next_alu == ALU0) begin

                if (!alu0_busy) begin

                    alu0_arg0 <= reg_rd0;
                    alu0_arg1 <= (arg1_imm) ? next_alu_imm : reg_rd1;
                    alu0_addr <= next_alu_addr;
                    alu0_imm <= next_alu_imm;
                    alu0_cmd <= next_alu_cmd;
                    alu0_rd <= next_alu_rd;

                    prog_enabled <= 1'b1;

                end else begin

                    alu0_arg0 <= '0;
                    alu0_arg1 <= '0;
                    alu0_addr <= '0;
                    alu0_imm <= '0;
                    alu0_cmd <= core_config_pkg::c_NONE;
                    alu0_rd <= '0;

                    prog_enabled <= 1'b0;

                end
            end

            if (next_alu == ALU1) begin

                if (!alu1_busy) begin

                    alu1_arg0 <= reg_rd0;
                    alu1_arg1 <= (arg1_imm) ? next_alu_imm : reg_rd1;
                    alu1_addr <= next_alu_addr;
                    alu1_imm <= next_alu_imm;
                    alu1_cmd <= next_alu_cmd;
                    alu1_rd <= next_alu_rd;

                    prog_enabled <= 1'b1;

                end else begin

                    alu1_arg0 <= '0;
                    alu1_arg1 <= '0;
                    alu1_addr <= '0;
                    alu1_imm <= '0;
                    alu1_cmd <= core_config_pkg::c_NONE;
                    alu1_rd <= '0;

                    prog_enabled <= 1'b0;

                end
            end

            if (next_alu == ALU2) begin // This case also include ALU3, which don't exist as an enum member.

                if (!alu2_busy) begin

                    alu2_arg0 <= reg_rd0;
                    alu2_arg1 <= (arg1_imm) ? next_alu_imm : reg_rd1;
                    alu2_addr <= next_alu_addr;
                    alu2_imm <= next_alu_imm;
                    alu2_cmd <= next_alu_cmd;
                    alu2_rd <= next_alu_rd;

                    prog_enabled <= 1'b1;

                end else if (!alu3_busy) begin

                    alu3_arg0 <= reg_rd0;
                    alu3_arg1 <= (arg1_imm) ? next_alu_imm : reg_rd1;
                    alu3_addr <= next_alu_addr;
                    alu3_imm <= next_alu_imm;
                    alu3_cmd <= next_alu_cmd;
                    alu3_rd <= next_alu_rd;

                    prog_enabled <= 1'b1;

                end else begin

                    alu2_arg0 <= '0;
                    alu2_arg1 <= '0;
                    alu2_addr <= '0;
                    alu2_imm <= '0;
                    alu2_cmd <= core_config_pkg::c_NONE;
                    alu2_rd <= '0;
                    alu3_arg0 <= '0;
                    alu3_arg1 <= '0;
                    alu3_addr <= '0;
                    alu3_imm <= '0;
                    alu3_cmd <= core_config_pkg::c_NONE;
                    alu3_rd <= '0;

                    prog_enabled <= 1'b0;

                end
            end

            if (next_alu == ALU4) begin

                if (!alu4_busy) begin

                    alu4_arg0 <= reg_rd0;
                    alu4_arg1 <= (arg1_imm) ? next_alu_imm : reg_rd1;
                    alu4_addr <= next_alu_addr;
                    alu4_imm <= next_alu_imm;
                    alu4_cmd <= next_alu_cmd;
                    alu4_rd <= next_alu_rd;

                    prog_enabled <= 1'b1;

                end else begin

                    alu4_arg0 <= '0;
                    alu4_arg1 <= '0;
                    alu4_addr <= '0;
                    alu4_imm <= '0;
                    alu4_cmd <= core_config_pkg::c_NONE;
                    alu4_rd <= '0;

                    prog_enabled <= 1'b0;

                end
            end

            if (next_alu == ALU5) begin

                if (!alu5_busy) begin

                    alu5_arg0 <= reg_rd0;
                    alu5_arg1 <= (arg1_imm) ? next_alu_imm : reg_rd1;
                    alu5_addr <= next_alu_addr;
                    alu5_imm <= next_alu_imm;
                    alu5_cmd <= next_alu_cmd;
                    alu5_rd <= next_alu_rd;

                    prog_enabled <= 1'b1;

                end else begin

                    alu5_arg0 <= '0;
                    alu5_arg1 <= '0;
                    alu5_addr <= '0;
                    alu5_imm <= '0;
                    alu5_cmd <= core_config_pkg::c_NONE;
                    alu5_rd <= '0;

                    prog_enabled <= 1'b0;

                end
            end
        end
    end

    assign dec_busy = ~prog_enabled;
    assign halt_needed = |{alu0_error, alu1_error, alu2_error, alu3_error, alu4_error, alu5_error, halt_pending, dec_illegal};
    assign dec_flush = flush_needed;

endmodule
