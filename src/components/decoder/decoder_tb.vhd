library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity decoder_tb is 
end entity;

architecture behavioral of decoder_tb is

        signal instruction_t :  std_logic_vector(31 downto 0)       := X"00000000";
        signal rs1_t :          std_logic_vector(32 downto 0);
        signal rs2_t :          std_logic_vector(31 downto 0);
        signal rd_t :           std_logic_vector(31 downto 0);
        signal imm_t :          std_logic_vector(31 downto 0);
        signal opcode_t :       std_logic_vector(16 downto 0);
        signal nILLEGAL_t :     std_logic;
        signal counter_en_t :   std_logic;
        signal clock_t :        std_logic                           := '0';
        signal nRST_t :         std_logic                           := '0';

    begin

        U1 : entity work.decoder(behavioral)
            generic map (
                XLEN        => 32,
                REG_NB      => 32
            )
            port map (
                instruction => instruction_t,
                rs1         => rs1_t,
                rs2         => rs2_t,
                rd          => rd_t,
                imm         => imm_t,
                opcode      => opcode_t,
                nILLEGAL    => nILLEGAL_t,
                counter_en  => counter_en_t,
                clock       => clock_t,
                nRST        => nRST_t
            );

            P1 : process
                begin
                    clock_t <= not clock_t;
                    wait for 10 ns;
                end process;

            P2 : process
                begin
                    nRST_t <= '0';
                    wait for 30 ns;
                    nRST_t <= '1';
                    wait for 1 sec;
                end process;

            P3 : process
                begin
                    wait for 40 ns;

                    --==================================================
                    -- RV32I
                    --==================================================

                    ----------------------------------------------------
                    -- Load immediates
                    ----------------------------------------------------

                    -- LUI (load upper immediate) 01110100101001101010 (value) 01111 (15) 01101 (lui) 11 (32 bits)
                    -- U Type format
                    instruction_t <= B"01110100101001101010011110110111"; 
                    wait for 40 ns;

                    -- AUIPC (add upper immediate to PC) 01110100101001101010 (value) 01111 (15) 00101 (lui) 11 (32 bits)
                    -- U Type format
                    instruction_t <= B"01110100101001101010011110010111"; 
                    wait for 40 ns;

                    ----------------------------------------------------
                    -- Immediates instructions
                    ----------------------------------------------------

                    -- ADDI (add immediate) 011111111111 (imm) 00011 (3) 000 (funct3) 10000 (16) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"01111111111100011000100000010011"; 
                    wait for 40 ns;

                    -- SLTI (Set less than immediate) 011111111111 (imm) 00011 (3) 010 (funct3) 10000 (16) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"01111111111101011000100000010011"; 
                    wait for 40 ns;

                    -- SLTIU (Set less than immediate unsigned) 011111111111 (imm) 00011 (3) 011 (funct3) 10000 (16) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"01111111111101111000100000010011"; 
                    wait for 40 ns;

                    -- XORI (XOR immediate) 011111111111 (imm) 00011 (3) 100 (funct3) 10000 (16) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"01111111111110011000100000010011"; 
                    wait for 40 ns;

                    -- ORI (OR immediate) 011111111111 (imm) 00011 (3) 110 (funct3) 10000 (16) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"01111111111111011000100000010011"; 
                    wait for 40 ns;

                    -- ANDI (AND immediate) 011111111111 (imm) 00011 (3) 111 (funct3) 10000 (16) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"01111111111111111000100000010011"; 
                    wait for 40 ns;

                    -- SLLI (Shift left immediate) 011111111111 (imm) 00011 (3) 001 (funct3) 10000 (16) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"01111111111100111000100000010011"; 
                    wait for 40 ns;

                    -- SRLI (Shift right immediate) 01000 (imm) 01 (0X) 01111 (imm (15)) 00011 (12) 101 (funct3) 01111 (15) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"01000010111101010101011110010011"; 
                    wait for 40 ns;

                    -- SRAI (Shift right arithemetic immediate) 00000 (imm) 01 (0X) 01111 (imm (15)) 00011 (12) 101 (funct3) 01111 (15) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"00000010111101010101011110010011"; 
                    wait for 40 ns;

                    ----------------------------------------------------
                    -- Register operations
                    ----------------------------------------------------

                    -- ADD 00000 (funct7) 00 (0) 01111 (15) 10001 (17) 000 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000000111110001000111110110011"; 
                    wait for 40 ns;

                    -- SUB 01000 (funct7) 00 (0) 01111 (15) 10001 (17) 000 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"01000000111110001000111110110011"; 
                    wait for 40 ns;

                    -- SLL 00000 (funct7) 00 (0) 01111 (15) 10001 (17) 001 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000000111110011000111110110011"; 
                    wait for 40 ns;

                    -- SLT 00000 (funct7) 00 (0) 01111 (15) 10001 (17) 010 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000000111110101000111110110011"; 
                    wait for 40 ns;

                    -- SLTU 00000 (funct7) 00 (0) 01111 (15) 10001 (17) 011 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000000111110111000111110110011"; 
                    wait for 40 ns;

                    -- XOR 00000 (funct7) 00 (0) 01111 (15) 10001 (17) 100 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000000111111001000111110110011"; 
                    wait for 40 ns;

                    -- SRL 00000 (funct7) 00 (0) 01111 (15) 10001 (17) 101 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000000111111011000111110110011"; 
                    wait for 40 ns;

                    -- SRA 01000 (funct7) 00 (0) 01111 (15) 10001 (17) 101 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"01000000111111011000111110110011"; 
                    wait for 40 ns;

                    -- OR 00000 (funct7) 00 (0) 01111 (15) 10001 (17) 110 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000000111111101000111110110011"; 
                    wait for 40 ns;

                    -- AND 00000 (funct7) 00 (0) 01111 (15) 10001 (17) 111 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000000111111111000111110110011"; 
                    wait for 40 ns;

                    ----------------------------------------------------
                    -- Fences instructions
                    ----------------------------------------------------

                    -- FENCE 0000 1001 1001 00000 000 00000 00011 11
                    -- I type
                    instruction_t <= B"00001001100100000000000000001111"; 
                    wait for 40 ns;

                    -- FENCE.I 00000 00 00000 00000 001 00000 00011 11
                    -- I Type
                    instruction_t <= B"00000000000000000001000000001111"; 
                    wait for 40 ns;

                    ----------------------------------------------------
                    -- Conditionnals jumps
                    ----------------------------------------------------

                    -- BEQ (Branch if equal) 0111111 00111 (rs2) 00110 (rs1) 000 (funct3) 11111 (offset) 11000 (branch) 11 (32 bits)
                    -- B Type
                    instruction_t <= B"01111110011100110000111111100011"; 
                    wait for 40 ns;

                    -- BNE (Branch if not equal) 0111111 00111 (rs2) 00110 (rs1) 001 (funct3) 11111 (offset) 11000 (branch) 11 (32 bits)
                    -- B Type
                    instruction_t <= B"01111110011100110001111111100011"; 
                    wait for 40 ns;

                    -- BLT (Branch if less than) 0111111 00111 (rs2) 00110 (rs1) 100 (funct3) 11111 (offset) 11000 (branch) 11 (32 bits)
                    -- B Type
                    instruction_t <= B"01111110011100110100111111100011"; 
                    wait for 40 ns;

                    -- BGE (Branch if greater than) 0111111 00111 (rs2) 00110 (rs1) 101 (funct3) 11111 (offset) 11000 (branch) 11 (32 bits)
                    -- B Type
                    instruction_t <= B"01111110011100110101111111100011"; 
                    wait for 40 ns;

                    -- BLTU (Branch if less than (unsigned)) 0111111 00111 (rs2) 00110 (rs1) 110 (funct3) 11111 (offset) 11000 (branch) 11 (32 bits)
                    -- B Type
                    instruction_t <= B"01111110011100110110111111100011"; 
                    wait for 40 ns;

                    -- BGEU (Branch if greater than (unsigned) 0111111 00111 (rs2) 00110 (rs1) 111 (funct3) 11111 (offset) 11000 (branch) 11 (32 bits)
                    -- B Type
                    instruction_t <= B"01111110011100110111111111100011"; 
                    wait for 40 ns;

                    ----------------------------------------------------
                    -- Memory operations
                    ----------------------------------------------------

                    -- SB (Store byte) 1111111 (offset 1) 00001 (rs2) 00011 (rs1) 000 (funct3) 11111 (offset 2) 01000 (op) 11 (32 bits)
                    -- S type
                    instruction_t <= B"11111110000100011000111110100011"; 
                    wait for 40 ns;

                    -- SH (Store halfword) 1111111 (offset 1) 00001 (rs2) 00011 (rs1) 001 (funct3) 11111 (offset 2) 01000 (op) 11 (32 bits)
                    -- S type
                    instruction_t <= B"11111110000100011001111110100011"; 
                    wait for 40 ns;

                    -- SW (Store word) 1111111 (offset 1) 00001 (rs2) 00011 (rs1) 010 (funct3) 11111 (offset 2) 01000 (op) 11 (32 bits)
                    -- S type
                    instruction_t <= B"11111110000100011010111110100011"; 
                    wait for 40 ns;

                    -- LB (Load byte) 111111111111 (offset) 00011 (rs1) 000 (funct3) 00001 (rd) 00000 (op) 11 (32 bits)
                    -- I Type
                    instruction_t <= B"11111111111100011000000010000011"; 
                    wait for 40 ns;

                    -- LH (Load halfword) 111111111111 (offset) 00011 (rs1) 001 (funct3) 00001 (rd) 00000 (op) 11 (32 bits)
                    -- I Type
                    instruction_t <= B"11111111111100011001000010000011"; 
                    wait for 40 ns;

                    -- LW (Load word) 111111111111 (offset) 00011 (rs1) 010 (funct3) 00001 (rd) 00000 (op) 11 (32 bits)
                    -- I Type
                    instruction_t <= B"11111111111100011010000010000011"; 
                    wait for 40 ns;

                    -- LBU (Load byte unsigned) 111111111111 (offset) 00011 (rs1) 100 (funct3) 00001 (rd) 00000 (op) 11 (32 bits)
                    -- I Type
                    instruction_t <= B"11111111111100011100000010000011"; 
                    wait for 40 ns;

                    -- LHU (Load halfword unsigned) 111111111111 (offset) 00011 (rs1) 101 (funct3) 00001 (rd) 00000 (op) 11 (32 bits)
                    -- I Type
                    instruction_t <= B"11111111111100011101000010000011"; 
                    wait for 40 ns;

                    ----------------------------------------------------
                    -- Jumps
                    ----------------------------------------------------

                    -- JAL (Jump and Link) 11111111111111111111 (offset) 00011 (rd) 11011 (op) 11 (32 bits)
                    -- J Type
                    instruction_t <= B"11111111111111111111000111101111"; 
                    wait for 40 ns;

                    -- JALR (Jump and Link Register) 111111111111 (offset) 00001 (rs1) 000 (funct3) 00011 (rd) 11001 (op) 11 (32 bits)
                    -- I Type
                    instruction_t <= B"11111111111100001000000111100111"; 
                    wait for 40 ns;

                    ----------------------------------------------------
                    -- Syscalls
                    ----------------------------------------------------

                    -- ECALL (Syscall)
                    -- I Type
                    instruction_t <= B"00000000000000000000000001110011"; 
                    wait for 40 ns;

                    -- EBREAK (sysret)
                    -- I Type
                    instruction_t <= B"00000000000100000000000001110011"; 
                    wait for 40 ns;

                    --==================================================
                    -- RV32M
                    --==================================================

                    -- MUL 00000 01 00001 (rs2) 00011 (rs1) 000 (funct3) 11111 (rd) 01100 (op) 11 (32 bits)
                    -- R Type format 
                    instruction_t <= B"00000010000100011000111110110011"; 
                    wait for 40 ns;

                    -- MULH 00000 01 00001 (rs2) 00011 (rs1) 001 (funct3) 11111 (rd) 01100 (op) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000010000100011001111110110011"; 
                    wait for 40 ns;


                    -- MULHSU 00000 01 00001 (rs2) 00011 (rs1) 010 (funct3) 11111 (rd) 01100 (op) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000010000100011010111110110011"; 
                    wait for 40 ns;

                    -- MULHU 00000 01 00001 (rs2) 00011 (rs1) 011 (funct3) 11111 (rd) 01100 (op) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000010000100011011111110110011"; 
                    wait for 40 ns;

                    -- DIV 00000 01 00001 (rs2) 00011 (rs1) 100 (funct3) 11111 (rd) 01100 (op) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000010000100011100111110110011"; 
                    wait for 40 ns;

                    -- DIVU 00000 01 00001 (rs2) 00011 (rs1) 101 (funct3) 11111 (rd) 01100 (op) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000010000100011101111110110011"; 
                    wait for 40 ns;

                    -- REM 00000 01 00001 (rs2) 00011 (rs1) 110 (funct3) 11111 (rd) 01100 (op) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000010000100011110111110110011"; 
                    wait for 40 ns;

                    -- REMU 00000 01 00001 (rs2) 00011 (rs1) 111 (funct3) 11111 (rd) 01100 (op) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000010000100011111111110110011"; 
                    wait for 40 ns;

                    -- End
                    wait for 1 sec;

                end process;

        end architecture;


-- Instructions lists

-- Type	    Opcode	    Funct3	Funct7	        Instruction	    Description

-- U-Type	0110111	    N/A	    N/A	            LUI	            Load Upper Immediate
-- U-Type	0010111	    N/A	    N/A	            AUIPC	        Add Upper Immediate to PC

-- I-Type	0010011	    000	    N/A	            ADDI	        Add Immediate
-- I-Type	0010011	    010	    N/A	            SLTI	        Set if Less Than Immediate
-- I-Type	0010011	    011	    N/A	            SLTIU	        Set if < Immediate (Unsigned)
-- I-Type	0010011	    100	    N/A	            XORI	        XOR Immediate
-- I-Type	0010011	    110	    N/A	            ORI	            OR Immediate
-- I-Type	0010011	    111	    N/A	            ANDI	        AND Immediate
-- I-Type	0010011	    001	    0000000	        SLLI	        Shift Left Logical Immediate
-- I-Type	0010011	    101	    0000000	        SRLI	        Shift Right Logical Immediate
-- I-Type	0010011	    101	    0100000	        SRAI	        Shift Right Arithmetic Immediate

-- R-Type	0110011	    000	    0000000	        ADD	            Add
-- R-Type	0110011	    000	    0100000	        SUB	            Subtract
-- R-Type	0110011	    001	    0000000	        SLL	            Shift Left Logical
-- R-Type	0110011	    010	    0000000	        SLT	            Set if Less Than
-- R-Type	0110011	    011	    0000000	        SLTU	        Set if < (Unsigned)
-- R-Type	0110011	    100	    0000000	        XOR	            XOR
-- R-Type	0110011	    101	    0000000	        SRL	            Shift Right Logical
-- R-Type	0110011	    101	    0100000	        SRA	            Shift Right Arithmetic
-- R-Type	0110011	    110	    0000000	        OR	            OR
-- R-Type	0110011	    111	    0000000	        AND	            AND

-- I-Type	0001111	    000	    N/A	            FENCE	        Fence
-- ??????   ???????     ???     ???             FENCE.i         Fence

-- B-Type	1100011	    000	    N/A	            BEQ	            Branch if Equal
-- B-Type	1100011	    001	    N/A	            BNE	            Branch if Not Equal
-- B-Type	1100011	    100	    N/A	            BLT	            Branch if Less Than
-- B-Type	1100011	    101	    N/A	            BGE	            Branch if Greater Than or Equal
-- B-Type	1100011	    110	    N/A	            BLTU	        Branch if Less Than (Unsigned)
-- B-Type	1100011	    111	    N/A	            BGEU	        Branch if >= (Unsigned)

-- S-Type	0100011	    000	    N/A	            SB	            Store Byte
-- S-Type	0100011	    001	    N/A	            SH	            Store Halfword
-- S-Type	0100011	    010	    N/A	            SW	            Store Word
-- I-Type	0000011	    000	    N/A	            LB	            Load Byte
-- I-Type	0000011	    001	    N/A	            LH	            Load Halfword
-- I-Type	0000011	    010	    N/A	            LW	            Load Word
-- I-Type	0000011	    100	    N/A	            LBU	            Load Byte (Unsigned)
-- I-Type	0000011	    101	    N/A	            LHU	            Load Halfword (Unsigned)

-- J-Type	1101111	    N/A	    N/A	            JAL	            Jump and Link
-- I-Type	1100111	    000	    N/A	            JALR	        Jump and Link Register

-- I-Type	1110011	    000	    000000000000	ECALL	        Environment Call
-- I-Type	1110011	    000	    000000000001	EBREAK	        Environment Breakpoint

-- R-Type	0110011	    000	    0000001	        MUL	            Multiply
-- R-Type	0110011	    001	    0000001	        MULH	        Multiply High (Signed)
-- R-Type	0110011	    010	    0000001	        MULHSU	        Multiply High (Signed x Unsigned)
-- R-Type	0110011	    011	    0000001	        MULHU	        Multiply High (Unsigned)
-- R-Type	0110011	    100	    0000001	        DIV	            Divide (Signed)
-- R-Type	0110011	    101	    0000001	        DIVU	        Divide (Unsigned)
-- R-Type	0110011	    110	    0000001	        REM	            Remainder (Signed)
-- R-Type	0110011	    111	    0000001	        REMU	        Remainder (Unsigned)