-- recommended simulation duration : 2us
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.common.all;

entity decoder_tb is 
end entity;

architecture behavioral of decoder_tb is

        signal instruction_t :  std_logic_vector(31 downto 0)       := X"00000000";
        signal rs1_t :          std_logic_vector(33 downto 0);
        signal rs2_t :          std_logic_vector(31 downto 0);
        signal rd_t :           std_logic_vector(31 downto 0);
        signal imm_t :          std_logic_vector(31 downto 0);
        signal opcode_t :       instructions;
        signal illegal_t :      std_logic;
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
                illegal     => illegal_t,
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
                    wait for 10 ns;
                    nRST_t <= '1';
                    wait for 1 sec;
                end process;

            P3 : process
                begin
                    wait for 20 ns;

                    --==================================================
                    -- RV32I
                    --==================================================

                    -- Invalid instruction
                    instruction_t <= B"01110100101001101010011110111101"; 
                    wait for 20 ns;

                    ----------------------------------------------------
                    -- Load immediates
                    ----------------------------------------------------

                    -- LUI (load upper immediate) 01110100101001101010 (value) 01111 (15) 01101 (lui) 11 (32 bits)
                    -- U Type format
                    instruction_t <= B"01110100101001101010_01111_01101_11"; 
                    wait for 20 ns;

                    -- AUIPC (add upper immediate to PC) 01110100101001101010 (value) 01111 (15) 00101 (auipc) 11 (32 bits)
                    -- U Type format
                    instruction_t <= B"01110100101001101010_01111_00101_11"; 
                    wait for 20 ns;

                    ----------------------------------------------------
                    -- Immediates instructions
                    ----------------------------------------------------

                    -- ADDI (add immediate) 011111111111 (imm) 00011 (3) 000 (funct3) 10000 (16) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"011111111111_00011_000_00001_00100_11"; 
                    wait for 20 ns;

                    -- SLTI (Set less than immediate) 111111111111 (imm) 00011 (3) 010 (funct3) 10000 (16) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"111111111111_01011_010_10000_00100_11"; 
                    wait for 20 ns;

                    -- SLTIU (Set less than immediate unsigned) 011111111111 (imm) 00011 (3) 011 (funct3) 10000 (16) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"011111111111_11111_011_10000_00100_11"; 
                    wait for 20 ns;

                    -- XORI (XOR immediate) 111111111111 (imm) 00011 (19) 100 (funct3) 10000 (16) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"111111111111_10011_100_10000_00100_11"; 
                    wait for 20 ns;

                    -- ORI (OR immediate) 111111111111 (imm) 00011 (3) 110 (funct3) 10000 (16) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"111111111111_00011_110_10000_00100_11"; 
                    wait for 20 ns;

                    -- ANDI (AND immediate) 011111111111 (imm) 00011 (3) 111 (funct3) 10000 (16) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"011111111111_00011_111_10000_00100_11"; 
                    wait for 20 ns;

                    -- SLLI (Shift left immediate) 111111111111 (imm) 00011 (3) 001 (funct3) 10000 (16) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"111111111111_00011_001_10000_00100_11"; 
                    wait for 20 ns;

                    -- SRLI (Shift right immediate) 01000 (imm) 01 (0X) 01111 (imm (15)) 00011 (12) 101 (funct3) 01111 (15) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"00000_01_01111_01010_101_01111_00100_11"; 
                    wait for 20 ns;

                    -- SRAI (Shift right arithemetic immediate) 00000 (imm) 01 (0X) 01111 (imm (15)) 00011 (12) 101 (funct3) 01111 (15) 00100 (imm) 11 (32 bits)
                    -- I Type format
                    instruction_t <= B"01000_01_01111_01010_101_01111_00100_11"; 
                    wait for 20 ns;

                    ----------------------------------------------------
                    -- Register operations
                    ----------------------------------------------------

                    -- ADD 00000 (funct7) 00 (0) 01111 (15) 10001 (17) 000 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000_00_01111_10001_000_11111_01100_11"; 
                    wait for 20 ns;

                    -- SUB 01000 (funct7) 00 (0) 01111 (15) 10001 (17) 000 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"01000_00_01111_10001_000_11111_01100_11"; 
                    wait for 20 ns;

                    -- SLL 00000 (funct7) 00 (0) 01111 (15) 10001 (17) 001 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000_00_01111_10011_001_11111_01100_11"; 
                    wait for 20 ns;

                    -- SLT 00000 (funct7) 00 (0) 01111 (15) 10001 (17) 010 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000_00_01111_10001_010_11111_01100_11"; 
                    wait for 20 ns;

                    -- SLTU 00000 (funct7) 00 (0) 01111 (15) 10001 (17) 011 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000_00_01111_10001_011_11111_01100_11"; 
                    wait for 20 ns;

                    -- XOR 00000 (funct7) 00 (0) 01111 (15) 10001 (17) 100 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000_00_01111_10001_100_11111_01100_11"; 
                    wait for 20 ns;

                    -- SRL 00000 (funct7) 00 (0) 01111 (15) 10001 (17) 101 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000_00_01111_10001_101_11111_01100_11"; 
                    wait for 20 ns;

                    -- SRA 01000 (funct7) 00 (0) 01111 (15) 10001 (17) 101 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"01000_00_01111_10001_101_11111_01100_11"; 
                    wait for 20 ns;

                    -- OR 00000 (funct7) 00 (0) 01111 (15) 10001 (17) 110 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000_00_01111_10001_110_11111_01100_11"; 
                    wait for 20 ns;

                    -- AND 00000 (funct7) 00 (0) 01111 (15) 10001 (17) 111 (funct3) 11111 (31) 01100 (code) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"00000_00_01111_10001_111_11111_01100_11"; 
                    wait for 20 ns;

                    ----------------------------------------------------
                    -- Fences instructions
                    ----------------------------------------------------

                    -- FENCE 0000 1001 1001 00000 000 00000 00011 11
                    -- I type
                    instruction_t <= B"0000_1001_1001_00000_000_00000_00011_11"; 
                    wait for 20 ns;

                    ----------------------------------------------------
                    -- Conditionnals jumps
                    ----------------------------------------------------

                    -- BEQ (Branch if equal) 0111111 00111 (rs2) 00110 (rs1) 000 (funct3) 11111 (offset) 11000 (branch) 11 (32 bits)
                    -- B Type
                    instruction_t <= B"0111111_00111_00110_000_11111_11000_11"; 
                    wait for 20 ns;

                    -- BNE (Branch if not equal) 1111111 00111 (rs2) 00110 (rs1) 001 (funct3) 11111 (offset) 11000 (branch) 11 (32 bits)
                    -- B Type
                    instruction_t <= B"1111111_00111_00110_001_11111_11000_11"; 
                    wait for 20 ns;

                    -- BLT (Branch if less than) 0111111 00111 (rs2) 00110 (rs1) 100 (funct3) 11111 (offset) 11000 (branch) 11 (32 bits)
                    -- B Type
                    instruction_t <= B"0111111_00111_00110_100_11111_11000_11"; 
                    wait for 20 ns;

                    -- BGE (Branch if greater than) 1111111 00111 (rs2) 00110 (rs1) 101 (funct3) 11111 (offset) 11000 (branch) 11 (32 bits)
                    -- B Type
                    instruction_t <= B"1111111_00111_00110_101_11111_11000_11"; 
                    wait for 20 ns;

                    -- BLTU (Branch if less than (unsigned)) 0111111 00111 (rs2) 00110 (rs1) 110 (funct3) 11111 (offset) 11000 (branch) 11 (32 bits)
                    -- B Type
                    instruction_t <= B"0111111_00111_00110_110_11111_11000_11"; 
                    wait for 20 ns;

                    -- BGEU (Branch if greater than (unsigned) 1111111 00111 (rs2) 00110 (rs1) 111 (funct3) 11111 (offset) 11000 (branch) 11 (32 bits)
                    -- B Type
                    instruction_t <= B"1111111_00111_00110_111_11111_11000_11"; 
                    wait for 20 ns;

                    ----------------------------------------------------
                    -- Memory operations
                    ----------------------------------------------------

                    -- SB (Store byte) 1111111 (offset 1) 00001 (rs2) 00011 (rs1) 000 (funct3) 11111 (offset 2) 01000 (op) 11 (32 bits)
                    -- S type
                    instruction_t <= B"1111111_00001_00011_000_11111_01000_11"; 
                    wait for 20 ns;

                    -- SH (Store halfword) 1111111 (offset 1) 00001 (rs2) 00011 (rs1) 001 (funct3) 11111 (offset 2) 01000 (op) 11 (32 bits)
                    -- S type
                    instruction_t <= B"1111111_00001_00011_001_11111_01000_11"; 
                    wait for 20 ns;

                    -- SW (Store word) 1111111 (offset 1) 00001 (rs2) 00011 (rs1) 010 (funct3) 11111 (offset 2) 01000 (op) 11 (32 bits)
                    -- S type
                    instruction_t <= B"1111111_00001_00011_010_11111_01000_11"; 
                    wait for 20 ns;

                    -- LB (Load byte) 111111111111 (offset) 00011 (rs1) 000 (funct3) 00001 (rd) 00000 (op) 11 (32 bits)
                    -- I Type
                    instruction_t <= B"111111111111_00011_000_00001_00000_11"; 
                    wait for 20 ns;

                    -- LH (Load halfword) 111111111111 (offset) 00011 (rs1) 001 (funct3) 00001 (rd) 00000 (op) 11 (32 bits)
                    -- I Type
                    instruction_t <= B"111111111111_00011_001_00001_00000_11"; 
                    wait for 20 ns;

                    -- LW (Load word) 111111111111 (offset) 00011 (rs1) 010 (funct3) 00001 (rd) 00000 (op) 11 (32 bits)
                    -- I Type
                    instruction_t <= B"111111111111_00011_010_00001_00000_11"; 
                    wait for 20 ns;

                    -- LBU (Load byte unsigned) 111111111111 (offset) 00011 (rs1) 100 (funct3) 00001 (rd) 00000 (op) 11 (32 bits)
                    -- I Type
                    instruction_t <= B"111111111111_00011_100_00001_00000_11"; 
                    wait for 20 ns;

                    -- LHU (Load halfword unsigned) 111111111111 (offset) 00011 (rs1) 101 (funct3) 00001 (rd) 00000 (op) 11 (32 bits)
                    -- I Type
                    instruction_t <= B"111111111111_00011_101_00001_00000_11"; 
                    wait for 20 ns;

                    ----------------------------------------------------
                    -- Jumps
                    ----------------------------------------------------

                    -- JAL (Jump and Link) 11111111111111111111 (offset) 00011 (rd) 11011 (op) 11 (32 bits)
                    -- J Type
                    instruction_t <= B"11111111111111111111_00011_11011_11"; 
                    wait for 20 ns;

                    -- JALR (Jump and Link Register) 111111111111 (offset) 00001 (rs1) 000 (funct3) 00011 (rd) 11001 (op) 11 (32 bits)
                    -- I Type
                    instruction_t <= B"111111111111_00001_000_00011_11001_11"; 
                    wait for 20 ns;

                    ----------------------------------------------------
                    -- Syscalls
                    ----------------------------------------------------

                    -- ECALL (Syscall)
                    -- I Type
                    instruction_t <= B"000000000000000000000000011100_11"; 
                    wait for 20 ns;

                    -- EBREAK (sysret)
                    -- I Type
                    instruction_t <= B"000000000001000000000000011100_11"; 
                    wait for 20 ns;

                    --==================================================
                    -- RV32M
                    --==================================================

                    -- MUL 0000001 (funct7) 00001 (rs2) 00011 (rs1) 000 (funct3) 11111 (rd) 01100 (op) 11 (32 bits)
                    -- R Type format 
                    instruction_t <= B"0000001_00001_00011_000_11111_01100_11"; 
                    wait for 20 ns;

                    -- MULH 0000001 (funct7) 00001 (rs2) 00011 (rs1) 001 (funct3) 11111 (rd) 01100 (op) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"0000001_00001_00011_001_11111_01100_11"; 
                    wait for 20 ns;


                    -- MULHSU 0000001 (funct7) 00001 (rs2) 00011 (rs1) 010 (funct3) 11111 (rd) 01100 (op) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"0000001_00001_00011_010_11111_01100_11"; 
                    wait for 20 ns;

                    -- MULHU 0000001 (funct7) 00001 (rs2) 00011 (rs1) 011 (funct3) 11111 (rd) 01100 (op) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"0000001_00001_00011_011_11111_01100_11"; 
                    wait for 20 ns;

                    -- DIV 0000001 (funct7) 00001 (rs2) 00011 (rs1) 100 (funct3) 11111 (rd) 01100 (op) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"0000001_00001_00011_100_11111_01100_11"; 
                    wait for 20 ns;

                    -- DIVU 0000001 (funct7) 00001 (rs2) 00011 (rs1) 101 (funct3) 11111 (rd) 01100 (op) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"0000001_00001_00011_101_11111_01100_11"; 
                    wait for 20 ns;

                    -- REM 0000001 (funct7) 00001 (rs2) 00011 (rs1) 110 (funct3) 11111 (rd) 01100 (op) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"0000001_00001_00011_110_11111_01100_11"; 
                    wait for 20 ns;

                    -- REMU 0000001 (funct7) 00001 (rs2) 00011 (rs1) 111 (funct3) 11111 (rd) 01100 (op) 11 (32 bits)
                    -- R Type format
                    instruction_t <= B"0000001_00001_00011_111_11111_01100_11"; 
                    wait for 20 ns;

                    ----------------------------------------------------
                    -- ILLEGALS
                    ----------------------------------------------------

                    -- (ILLEGAL) SH (Store halfword) 1111111 (offset 1) 00001 (rs2) 00011 (rs1) 010 (funct3) 11111 (offset 2) 01000 (op) 11 (32 bits)
                    -- S type
                    instruction_t <= B"1111111_00001_00011_011_11111_01000_11"; 
                    wait for 20 ns;

                    -- (ILLEGAL) BGE (Branch if greater than) 0111111 00111 (rs2) 00110 (rs1) 101 (funct3) 11111 (offset) 11000 (branch) 11 (32 bits)
                    -- B Type
                    instruction_t <= B"0111111_00111_00110_010_11111_11000_11"; 
                    wait for 20 ns;

                    -- End
                    wait for 1 sec;

                end process;

        end architecture;


-- Instructions lists

-- Type	    Opcode	    Funct3	Funct7	        Instruction	    Description                             Cycles Numbers  Remarks

-- U-Type	0110111	    N/A	    N/A	            LUI	            Load Upper Immediate                    1               N/A
-- U-Type	0010111	    N/A	    N/A	            AUIPC	        Add Upper Immediate to PC               1               N/A

-- I-Type	0010011	    000	    N/A	            ADDI	        Add Immediate                           1               N/A
-- I-Type	0010011	    010	    N/A	            SLTI	        Set if Less Than Immediate              1               N/A       
-- I-Type	0010011	    011	    N/A	            SLTIU	        Set if < Immediate (Unsigned)           1               N/A
-- I-Type	0010011	    100	    N/A	            XORI	        XOR Immediate                           1               N/A
-- I-Type	0010011	    110	    N/A	            ORI	            OR Immediate                            1               N/A
-- I-Type	0010011	    111	    N/A	            ANDI	        AND Immediate                           1               N/A
-- I-Type	0010011	    001	    0000000	        SLLI	        Shift Left Logical Immediate            1               N/A
-- I-Type	0010011	    101	    0000000	        SRLI	        Shift Right Logical Immediate           1               N/A
-- I-Type	0010011	    101	    0100000	        SRAI	        Shift Right Arithmetic Immediate        1               N/A

-- R-Type	0110011	    000	    0000000	        ADD	            Add                                     1               N/A
-- R-Type	0110011	    000	    0100000	        SUB	            Subtract                                1               N/A
-- R-Type	0110011	    001	    0000000	        SLL	            Shift Left Logical                      1               N/A
-- R-Type	0110011	    010	    0000000	        SLT	            Set if Less Than                        1               N/A
-- R-Type	0110011	    011	    0000000	        SLTU	        Set if < (Unsigned)                     1               N/A
-- R-Type	0110011	    100	    0000000	        XOR	            XOR                                     1               N/A
-- R-Type	0110011	    101	    0000000	        SRL	            Shift Right Logical                     1               N/A
-- R-Type	0110011	    101	    0100000	        SRA	            Shift Right Arithmetic                  1               N/A
-- R-Type	0110011	    110	    0000000	        OR	            OR                                      1               N/A
-- R-Type	0110011	    111	    0000000	        AND	            AND                                     

-- I-Type	0001111	    000	    N/A	            FENCE	        Fence                                   ?               Block any unterminated IO operation

-- B-Type	1100011	    000	    N/A	            BEQ	            Branch if Equal                         ?               N/A
-- B-Type	1100011	    001	    N/A	            BNE	            Branch if Not Equal                     ?               N/A
-- B-Type	1100011	    100	    N/A	            BLT	            Branch if Less Than                     ?               N/A
-- B-Type	1100011	    101	    N/A	            BGE	            Branch if Greater Than or Equal         ?               N/A
-- B-Type	1100011	    110	    N/A	            BLTU	        Branch if Less Than (Unsigned)          ?               N/A
-- B-Type	1100011	    111	    N/A	            BGEU	        Branch if >= (Unsigned)                 ?               N/A

-- S-Type	0100011	    000	    N/A	            SB	            Store Byte                              ?               May take time (how much ?). Does not block by default, FENCE op if needed.
-- S-Type	0100011	    001	    N/A	            SH	            Store Halfword                          ?               May take time (how much ?). Does not block by default, FENCE op if needed.
-- S-Type	0100011	    010	    N/A	            SW	            Store Word                              ?               May take time (how much ?). Does not block by default, FENCE op if needed.
-- I-Type	0000011	    000	    N/A	            LB	            Load Byte                               ?               May take time (how much ?). Does not block by default, FENCE op if needed.
-- I-Type	0000011	    001	    N/A	            LH	            Load Halfword                           ?               May take time (how much ?). Does not block by default, FENCE op if needed.
-- I-Type	0000011	    010	    N/A	            LW	            Load Word                               ?               May take time (how much ?). Does not block by default, FENCE op if needed.
-- I-Type	0000011	    100	    N/A	            LBU	            Load Byte (Unsigned)                    ?               May take time (how much ?). Does not block by default, FENCE op if needed.
-- I-Type	0000011	    101	    N/A	            LHU	            Load Halfword (Unsigned)                ?               May take time (how much ?). Does not block by default, FENCE op if needed.

-- J-Type	1101111	    N/A	    N/A	            JAL	            Jump and Link                           1               Stall the pipeline
-- I-Type	1100111	    000	    N/A	            JALR	        Jump and Link Register                  1               Stall the pipeline

-- I-Type	1110011	    000	    000000000000	ECALL	        Environment Call                        4               Stall the pipeline + execution mode to priviledged
-- I-Type	1110011	    000	    000000000001	EBREAK	        Environment Breakpoint                  4               Stall the pipeline + execution mode to user

-- R-Type	0110011	    000	    0000001	        MUL	            Multiply                                1               N/A
-- R-Type	0110011	    001	    0000001	        MULH	        Multiply High (Signed)                  1               N/A
-- R-Type	0110011	    010	    0000001	        MULHSU	        Multiply High (Signed x Unsigned)       1               N/A
-- R-Type	0110011	    011	    0000001	        MULHU	        Multiply High (Unsigned)                1               N/A
-- R-Type	0110011	    100	    0000001	        DIV	            Divide (Signed)                         1               N/A
-- R-Type	0110011	    101	    0000001	        DIVU	        Divide (Unsigned)                       1               N/A
-- R-Type	0110011	    110	    0000001	        REM	            Remainder (Signed)                      1               N/A
-- R-Type	0110011	    111	    0000001	        REMU	        Remainder (Unsigned)                    1               N/A