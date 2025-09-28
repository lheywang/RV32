package common is
    
    type instructions is (
        i_NOP,

        i_LUI,  i_AUIPC,

        i_ADDI,     i_SLTI,     i_SLTIU,    i_XORI,
        i_ANDI,     i_SLLI,     i_SRLI,     i_SRAI,
        i_ORI,

        i_ADD,      i_SUB,      i_SLL,      i_SLT,
        i_SLTU,     i_XOR,      i_SRL,      i_SRA,
        i_OR,       i_AND,

        i_FENCE,

        i_BEQ,      i_BNE,      i_BLT,      i_BGE,
        i_BLTU,     i_BGEU,

        i_SB,       i_SH,       i_SW,       i_LB,
        i_LH,       i_LW,       i_LBU,      i_LHU,

        i_JAL,      i_JALR,

        i_ECALL,    i_EBREAK,   i_MRET,

        i_CSRRW,    i_CSRRS,    i_CSRRC,    i_CSRRWI,
        i_CSRRSI,   i_CSRRCI
    );

    type commands is (
        c_ADD,      c_SUB,

        c_SLL,      c_SRL,      c_SRA,

        c_SLT,      c_SLTU,

        c_AND,      c_OR,       c_XOR,

        c_NONE
    );

end common;

package body common is 
end common;