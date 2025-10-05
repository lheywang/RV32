--------------------------------------------------------------------
--------------------------------------------------------------------

--! @brief Package to define some wirings types to make easier the transfer between modules, by using names rather than obscur std_logic_vector values.
PACKAGE common IS

    --! @brief Type listings to define the decoder outputs, per opcodes.
    TYPE instructions IS (
        i_NOP,

        i_LUI, i_AUIPC,

        i_ADDI, i_SLTI, i_SLTIU, i_XORI,
        i_ANDI, i_SLLI, i_SRLI, i_SRAI,
        i_ORI,

        i_ADD, i_SUB, i_SLL, i_SLT,
        i_SLTU, i_XOR, i_SRL, i_SRA,
        i_OR, i_AND,

        i_FENCE,

        i_BEQ, i_BNE, i_BLT, i_BGE,
        i_BLTU, i_BGEU,

        i_SB, i_SH, i_SW, i_LB,
        i_LH, i_LW, i_LBU, i_LHU,

        i_JAL, i_JALR,

        i_ECALL, i_EBREAK, i_MRET,

        i_CSRRW, i_CSRRS, i_CSRRC, i_CSRRWI,
        i_CSRRSI, i_CSRRCI
    );

    --! @brief Type listings to define the controller outputs feed into the ALU.
    TYPE commands IS (
        c_ADD, c_SUB,

        c_SLL, c_SRL, c_SRA,

        c_SLT, c_SLTU,

        c_AND, c_OR, c_XOR,

        c_NONE
    );

    --! @brief Type listings to define the names of the different CSR registers names.
    TYPE csr_register IS (
        r_MSTATUS,
        r_MISA,
        r_MIE,
        r_MTVEC,
        r_MSCRATCH,
        r_MEPC,
        r_MCAUSE,
        r_MTVAL,
        r_MIP
    );

END common;

PACKAGE BODY common IS
END common;