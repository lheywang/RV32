`timescale 1ns / 1ps

import core_config_pkg::IF_LEN;
import core_config_pkg::XLEN;
import core_config_pkg::REG_ADDR_W;
import core_config_pkg::opcodes;
import core_config_pkg::decoders;

module decoder (
    input   logic                           clk,
    input   logic                           clk_en,
    input   logic                           rst_n,

    input   logic   [(IF_LEN - 1) : 0]      instruction,
    input   logic   [(XLEN - 1) : 0]        i_address,

    input   logic                           i_busy, // Busy input from later stages.
    output  logic                           o_busy, // Busy output for previous stages.

    output  logic   [(REG_ADDR_W - 1) : 0]  rs1,
    output  logic   [(REG_ADDR_W - 1) : 0]  rs2,
    output  logic   [(REG_ADDR_W - 1) : 0]  rd,
    output  logic   [(XLEN - 1) : 0]        imm,

    output  logic   [(XLEN - 1) : 0]        o_address,

    output  opcodes                         opcode,
    output  logic                           illegal
);

    /*
     * First latches, registering the inputs, on each rising edges of the clock.
     */

    logic           [(XLEN - 1) : 0]        r0_instruction;
    logic           [(XLEN - 1) : 0]        r0_addr;
    logic           [(XLEN - 1) : 0]        r1_addr;
    logic                                   first_flag;

    always_ff @( posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            
            r0_instruction  <= 0; 

            r0_addr         <= 0;
            r1_addr         <= 0;

            first_flag      <= 1;

        end
        else if (clk_en) begin

            if (!first_flag) begin

                r0_instruction <= instruction;

                r0_addr     <= i_address;
                r1_addr     <= r0_addr;
                o_address   <= r1_addr;

            end
            else begin

                first_flag  <= 0;

            end
        end    
    end

    /*
     * Second, combinational logic to choose the right decoder
     */

    logic                                   decoder_illegal;
    decoders                                selected_decoder;

    always_comb begin

        decoder_illegal = 0;
        
        unique case (r0_instruction[6:0])

            7'b0110111, 
            7'b0010111 : selected_decoder = core_config_pkg::DEC_U;     // LUI or AUIPC
            7'b0010011, 
            7'b0001111, 
            7'b1100111, 
            7'b1110011, 
            7'b0000011 : selected_decoder = core_config_pkg::DEC_I;     // Immediates operands
            7'b0110011 : selected_decoder = core_config_pkg::DEC_R;     // Register operations
            7'b1100011 : selected_decoder = core_config_pkg::DEC_B;     // Branchs
            7'b0100011 : selected_decoder = core_config_pkg::DEC_S;     // Loads
            7'b1101111 : selected_decoder = core_config_pkg::DEC_J;     // Jumps
            7'b0000000 : selected_decoder = core_config_pkg::DEC_NONE;  // Others
            default : begin
                selected_decoder = core_config_pkg::DEC_NONE;
                decoder_illegal = 1;
            end

        endcase
    end

    /*
     * Second registration stage, for the second decoding stage
     */

    logic           [(XLEN - 1) : 0]        r1_instruction;
    decoders                                r_selected_decoder;
    logic                                   r_decoder_illegal;

    always_ff @( posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            r1_instruction  <= 0;
            r_selected_decoder <= core_config_pkg::DEC_NONE;
            r_decoder_illegal <= 0;

        end
        else if (clk_en) begin

            r1_instruction <= r0_instruction;
            r_selected_decoder <= selected_decoder;
            r_decoder_illegal <= decoder_illegal;

        end
    end

    /*
     * Second combinational stage, and direct output to the remaining circuits.
     */

    logic                                   decoder_illegal_2;

    always_comb begin

        // Default assignments (avoid latch inference)
        opcode              = core_config_pkg::i_NOP;
        decoder_illegal_2   = 1'b0;
        rd                  = 0;
        rs1                 = 0;
        rs2                 = 0;
        imm                 = 0;

        // Using the right decoder...
        unique case (r_selected_decoder)

            core_config_pkg::DEC_R : begin

                rd      = r1_instruction[core_config_pkg::RD_MSB : core_config_pkg::RD_LSB];
                rs1     = r1_instruction[core_config_pkg::RS1_MSB : core_config_pkg::RS1_LSB];
                rs2     = r1_instruction[core_config_pkg::RS2_MSB : core_config_pkg::RS2_LSB];

                unique case (r1_instruction[core_config_pkg::FUNCT7_MSB : core_config_pkg::FUNCT7_LSB])

                    7'b0000000 : begin

                        unique case (r1_instruction[core_config_pkg::FUNCT3_MSB : core_config_pkg::FUNCT3_LSB])

                            3'b000 : opcode = core_config_pkg::i_ADD;
                            3'b001 : opcode = core_config_pkg::i_SLL;
                            3'b010 : opcode = core_config_pkg::i_SLT;
                            3'b011 : opcode = core_config_pkg::i_SLTU;
                            3'b100 : opcode = core_config_pkg::i_XOR;
                            3'b101 : opcode = core_config_pkg::i_SRL;
                            3'b110 : opcode = core_config_pkg::i_OR;
                            3'b111 : opcode = core_config_pkg::i_AND;

                        endcase
                    end

                    7'b0100000 : begin

                        unique case (r1_instruction[core_config_pkg::FUNCT3_MSB : core_config_pkg::FUNCT3_LSB])

                            3'b000 : opcode = core_config_pkg::i_SUB;
                            3'b101 : opcode = core_config_pkg::i_SRA;
                            default : decoder_illegal_2 = 1;

                        endcase
                    end

                    7'b0000001 : begin

                        unique case (r1_instruction[core_config_pkg::FUNCT3_MSB : core_config_pkg::FUNCT3_LSB])

                            3'b000 : opcode = core_config_pkg::i_MUL;
                            3'b001 : opcode = core_config_pkg::i_MULH;
                            3'b010 : opcode = core_config_pkg::i_MULHSU;
                            3'b011 : opcode = core_config_pkg::i_MULHU;
                            3'b100 : opcode = core_config_pkg::i_DIV;
                            3'b101 : opcode = core_config_pkg::i_DIVU;
                            3'b110 : opcode = core_config_pkg::i_REM;
                            3'b111 : opcode = core_config_pkg::i_REMU;

                        endcase
                    end

                    default :  decoder_illegal_2 = 1;

                endcase

            end

            core_config_pkg::DEC_I : begin

                rd      = r1_instruction[core_config_pkg::RD_MSB : core_config_pkg::RD_LSB];
                rs1     = r1_instruction[core_config_pkg::RS1_MSB : core_config_pkg::RS1_LSB];
                imm     = { 
                            {32-12{r1_instruction[31]}}, 
                            r1_instruction[31:20] 
                        };

                unique case (r1_instruction[core_config_pkg::OPCODE_MSB : core_config_pkg::OPCODE_LSB])

                    7'b0010011 : begin

                         unique case (r1_instruction[core_config_pkg::FUNCT3_MSB : core_config_pkg::FUNCT3_LSB])

                            3'b000 : opcode = core_config_pkg::i_ADDI;
                            3'b001 : opcode = core_config_pkg::i_SLLI;
                            3'b010 : opcode = core_config_pkg::i_SLTI;
                            3'b011 : opcode = core_config_pkg::i_SLTIU;
                            3'b100 : opcode = core_config_pkg::i_XORI;
                            3'b101 : begin
                                if (r1_instruction[30]) begin
                                    opcode = core_config_pkg::i_SRAI;
                                end
                                else begin
                                    opcode = core_config_pkg::i_SRLI;
                                end
                            end
                            3'b110 : opcode = core_config_pkg::i_ORI;
                            3'b111 : opcode = core_config_pkg::i_ANDI;

                        endcase

                    end

                    7'b0001111 : opcode = core_config_pkg::i_FENCE;

                    7'b0000011 : begin

                        unique case (r1_instruction[core_config_pkg::FUNCT3_MSB : core_config_pkg::FUNCT3_LSB])

                            3'b000 : opcode = core_config_pkg::i_LB;
                            3'b001 : opcode = core_config_pkg::i_LH;
                            3'b010 : opcode = core_config_pkg::i_LW;
                            3'b100 : opcode = core_config_pkg::i_LBU;
                            3'b101 : opcode = core_config_pkg::i_LHU;
                            default : decoder_illegal_2 = 1;

                        endcase

                    end

                    7'b1100111 : begin

                        unique case (r1_instruction[core_config_pkg::FUNCT3_MSB : core_config_pkg::FUNCT3_LSB])

                            3'b000 : opcode = core_config_pkg::i_JALR;
                            default : decoder_illegal_2 = 1;

                        endcase
                    
                    end

                    7'b1110011 : begin

                        unique case (r1_instruction[core_config_pkg::FUNCT3_MSB : core_config_pkg::FUNCT3_LSB])

                            3'b000 : begin

                                /*
                                 * Theses values aren't used by the encoding, and more importantly : They 
                                 * shall not appear on the ouputs.
                                 */
                                imm = 0;
                                rs1 = 0; 
                                rd = 0;

                                unique case (r1_instruction[core_config_pkg::XLEN - 1 : core_config_pkg::RS2_LSB])
                                    12'h000 : opcode = core_config_pkg::i_ECALL;
                                    12'h001 : opcode = core_config_pkg::i_EBREAK;
                                    12'h302 : opcode = core_config_pkg::i_MRET;
                                    default : decoder_illegal_2 = 1;
                                endcase

                            end
                            3'b001 : opcode = core_config_pkg::i_CSRRW;
                            3'b010 : opcode = core_config_pkg::i_CSRRS;
                            3'b011 : opcode = core_config_pkg::i_CSRRC;
                            3'b101 : opcode = core_config_pkg::i_CSRRWI;
                            3'b110 : opcode = core_config_pkg::i_CSRRSI;
                            3'b111 : opcode = core_config_pkg::i_CSRRCI;
                            default : decoder_illegal_2 = 1;

                        endcase
                        
                    end
                    
                    default : decoder_illegal_2 = 1;

                endcase

            end

            core_config_pkg::DEC_S : begin

                rs1     = r1_instruction[core_config_pkg::RS1_MSB : core_config_pkg::RS1_LSB];
                rs2     = r1_instruction[core_config_pkg::RS2_MSB : core_config_pkg::RS2_LSB];
                imm     = { 
                            {32-12{r1_instruction[31]}}, 
                            r1_instruction[core_config_pkg::FUNCT7_MSB : core_config_pkg::FUNCT7_LSB], 
                            r1_instruction[core_config_pkg::RD_MSB : core_config_pkg::RD_LSB] 
                        };

                unique case (r1_instruction[core_config_pkg::FUNCT3_MSB : core_config_pkg::FUNCT3_LSB])

                    3'b000 : opcode = core_config_pkg::i_SB;
                    3'b001 : opcode = core_config_pkg::i_SH;
                    3'b010 : opcode = core_config_pkg::i_SW;
                    default : decoder_illegal_2 = 1;

                endcase
            end

            core_config_pkg::DEC_B : begin

                rs1     = r1_instruction[core_config_pkg::RS1_MSB : core_config_pkg::RS1_LSB];
                rs2     = r1_instruction[core_config_pkg::RS2_MSB : core_config_pkg::RS2_LSB];
                imm     = { 
                            {32-12{r1_instruction[31]}}, 
                            r1_instruction[7],
                            r1_instruction[30 : 25], 
                            r1_instruction[11 : 8],
                            1'b0 
                        };

                unique case (r1_instruction[core_config_pkg::FUNCT3_MSB : core_config_pkg::FUNCT3_LSB])

                    3'b000 : opcode = core_config_pkg::i_BEQ;
                    3'b001 : opcode = core_config_pkg::i_BNE;
                    3'b100 : opcode = core_config_pkg::i_BLT;
                    3'b101 : opcode = core_config_pkg::i_BGE;
                    3'b110 : opcode = core_config_pkg::i_BLTU;
                    3'b111 : opcode = core_config_pkg::i_BGEU;
                    default : decoder_illegal_2 = 1;

                endcase

            end

            core_config_pkg::DEC_U : begin

                rd      = r1_instruction[core_config_pkg::RD_MSB : core_config_pkg::RD_LSB];
                imm     = {
                            r1_instruction[31 : core_config_pkg::FUNCT3_LSB],
                            12'b0
                        };

                unique case (r1_instruction[core_config_pkg::OPCODE_MSB : core_config_pkg::OPCODE_LSB])

                    7'b0110111 : opcode = core_config_pkg::i_LUI;
                    7'b0010111 : opcode = core_config_pkg::i_AUIPC;
                    default : decoder_illegal_2 = 1;

                endcase

            end

            core_config_pkg::DEC_J : begin

                rd      = r1_instruction[core_config_pkg::RD_MSB : core_config_pkg::RD_LSB];
                opcode  = core_config_pkg::i_JAL;
                imm     = {
                            {32-20{r1_instruction[31]}},
                            r1_instruction[19 : 12],
                            r1_instruction[20],
                            r1_instruction[30 : 21],
                            1'b0
                        };
            end

            core_config_pkg::DEC_NONE : decoder_illegal_2 = 1;

        endcase
    end

    assign illegal = r_decoder_illegal | decoder_illegal_2;
    assign o_busy = i_busy;

endmodule
