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

        i_ECALL,    i_EBREAK,

        i_MUL,      i_MULH,     i_MULHSU,   i_MULHU,
        i_DIV,      i_DIVU,     i_REM,      i_REMU
    );

end common;

package body common is 
end common;