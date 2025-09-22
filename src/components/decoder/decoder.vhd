library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.common.all;

entity decoder is 
    generic (
        XLEN :      integer := 32                                           -- Width of the data outputs. 
                                                                            -- Warning : This does not change the number of registers not instruction lenght
    );
    port (
        -- instruction input
        instruction :   in      std_logic_vector(31 downto 0);

        -- outputs
        -- buses
        rs1 :           out     std_logic_vector(4 downto 0)                            := (others => '0');
        rs2 :           out     std_logic_vector(4 downto 0)                            := (others => '0');   
        rd :            out     std_logic_vector(4 downto 0)                            := (others => '0');
        imm :           out     std_logic_vector((XLEN - 1) downto 0)                   := (others => '0');
        opcode :        out     instructions;                         
        -- signals
        illegal :      out     std_logic;

        -- Clocks
        clock :         in      std_logic;
        nRST :          in      std_logic
    );
end entity;

architecture behavioral of decoder is

        -- Defining the different selected_decoders
        type decocders_type is (U, I, R, B, S, J, default_t, illegal_t, NOP);

        -- signals
        signal illegal_internal :      std_logic                                        := '0';
        signal illegal_internal2 :     std_logic                                        := '0';
        signal illegal_internal_out :  std_logic                                        := '0';

        -- Internal states
        signal selected_decoder :      decocders_type                                   := default_t;

        -- Latchs outputs
        signal  rs1_internal :          std_logic_vector(4 downto 0)                    := (others => '0');
        signal  rs2_internal :          std_logic_vector(4 downto 0)                    := (others => '0');
        signal  rd_internal :           std_logic_vector(4 downto 0)                    := (others => '0');
        signal  imm_internal :          std_logic_vector((XLEN - 1) downto 0)           := (others => '0');

    begin

        -- Basic checks
        P1 : process(clock, nRST) 
            begin

                if (nRST = '0') then
                    illegal_internal    <= '0';
                    selected_decoder    <= default_t;

                elsif rising_edge(clock) then

                    -- Select the opcode, and perform an instruction size check (last two bits must be "11").
                    case instruction(6 downto 0) is

                        when "0110111" =>               -- LUI
                            selected_decoder <= U;
                            illegal_internal <= '0';
                        when "0010111" =>               -- AUIPC
                            selected_decoder <= U;
                            illegal_internal <= '0';

                        when "0010011" =>               -- Immediates
                            selected_decoder <= I;
                            illegal_internal <= '0';
                        when "0001111" =>               -- FENCE
                            selected_decoder <= I;
                            illegal_internal <= '0';
                        when "1100111" =>               --(JALR)
                            selected_decoder <= I;
                            illegal_internal <= '0';
                        when "1110011" =>               -- Calls
                            selected_decoder <= I;
                            illegal_internal <= '0';
                        when "0000011" =>               -- Store
                            selected_decoder <= I;
                            illegal_internal <= '0';

                        when "0110011" =>               -- Register operations
                            selected_decoder <= R;
                            illegal_internal <= '0';
                        
                        when "1100011" =>               -- Branchs
                            selected_decoder <= B;
                            illegal_internal <= '0';
                        
                        when "0100011" =>               -- Loads
                            selected_decoder <= S;
                            illegal_internal <= '0';

                        when "1101111" =>               -- Jumps
                            selected_decoder <= J;
                            illegal_internal <= '0';

                        when "0000000" =>               -- All zero, seen as NOP
                            selected_decoder <= NOP;
                            illegal_internal <= '0';

                        when others =>
                            selected_decoder <= illegal_t;
                            illegal_internal <= '1';

                    end case;
                end if;
                
            end process;

        -- Hardware selected_decoder selection logic
        P2 : process(instruction, selected_decoder, nRST)
            begin
                if (nRST = '0') then
                    rs1_internal <= (others => '0');
                    rs2_internal <= (others => '0');
                    imm_internal <= (others => '0');
                    rd_internal <= (others => '0');
                    opcode <= i_NOP;
                    illegal_internal2 <= '0';

                else

                    case selected_decoder is 

                        -- Register to register operation
                        when R =>
                            rd_internal <=                                  instruction(11 downto 7);
                            rs1_internal <=                                 instruction(19 downto 15);
                                                                           
                            rs2_internal <=                                 instruction(24 downto 20);
                            imm_internal <=                                 (others => '0');
                        
                            -- Instruction identification
                            case instruction(31 downto 25) is 

                                when "0000000" => -- ADD SLL SLT XOR SRL OR AND

                                    case instruction(14 downto 12) is

                                        when "000" =>
                                            opcode <= i_ADD;
                                            illegal_internal2 <= '0';
                                        when "001" =>
                                            opcode <= i_SLL;
                                            illegal_internal2 <= '0';
                                        when "010" =>
                                            opcode <= i_SLT;
                                            illegal_internal2 <= '0';
                                        when "011" =>
                                            opcode <= i_SLTU;
                                            illegal_internal2 <= '0';
                                        when "100" =>
                                            opcode <= i_XOR;
                                            illegal_internal2 <= '0';
                                        when "101" =>
                                            opcode <= i_SRL;
                                            illegal_internal2 <= '0';
                                        when "110" => 
                                            opcode <= i_OR;
                                            illegal_internal2 <= '0';
                                        when "111" =>
                                            opcode <= i_AND; 
                                            illegal_internal2 <= '0';
                                        when others =>
                                            opcode <= i_NOP;
                                            illegal_internal2 <= '1';

                                    end case;

                                when "0100000" => -- SUB SRA

                                    case instruction(14 downto 12) is

                                        when "000" =>
                                            opcode <= i_SUB;
                                            illegal_internal2 <= '0';
                                        when "101" =>
                                            opcode <= i_SRA;
                                            illegal_internal2 <= '0';
                                        when others =>
                                            opcode <= i_NOP;
                                            illegal_internal2 <= '1';

                                    end case;

                                -- when "0000001" => -- RV32M extension

                                --     case instruction(14 downto 12) is

                                --         when "000" =>
                                --             opcode <= i_MUL;
                                --             illegal_internal2 <= '0';
                                --         when "001" =>
                                --             opcode <= i_MULH;
                                --             illegal_internal2 <= '0';
                                --         when "010" =>
                                --             opcode <= i_MULHSU;
                                --             illegal_internal2 <= '0';
                                --         when "011" =>
                                --             opcode <= i_MULHU;
                                --             illegal_internal2 <= '0';
                                --         when "100" =>
                                --             opcode <= i_DIV;
                                --             illegal_internal2 <= '0';
                                --         when "101" =>
                                --             opcode <= i_DIVU;
                                --             illegal_internal2 <= '0';
                                --         when "110" => 
                                --             opcode <= i_REM;
                                --             illegal_internal2 <= '0';
                                --         when "111" =>
                                --             opcode <= i_REMU; 
                                --             illegal_internal2 <= '0';
                                --         when others =>
                                --             opcode <= i_NOP;
                                --             illegal_internal2 <= '1';

                                --   end case;

                                when others => 
                                    opcode <= i_NOP;
                                    illegal_internal2 <= '1';

                            end case;

                        -- Immediate to register operation
                        when I =>
                            rd_internal <=                                  instruction(11 downto 7);
                            rs1_internal <=                                 instruction(19 downto 15); 
                            rs2_internal <=                                 (others => '0');
                            imm_internal <=                                 (others => instruction(31));
                            imm_internal(11 downto 0) <=                    instruction(31 downto 20);
                            
                            -- Instruction identification
                            case instruction(6 downto 2) is

                                when "00100" => 
                            
                                    case instruction(14 downto 12) is

                                        when "000" =>
                                            opcode <= i_ADDI;
                                            illegal_internal2 <= '0';
                                        when "001" =>
                                            opcode <= i_SLLI;
                                            illegal_internal2 <= '0';
                                        when "010" =>
                                            opcode <= i_SLTI;
                                            illegal_internal2 <= '0';
                                        when "011" =>
                                            opcode <= i_SLTIU;
                                            illegal_internal2 <= '0';
                                        when "100" =>
                                            opcode <= i_XORI;
                                            illegal_internal2 <= '0';
                                        when "110" =>
                                            opcode <= i_ORI;
                                            illegal_internal2 <= '0';
                                        when "101" => 
                                            if (instruction(30) = '1') then
                                                opcode <= i_SRAI;
                                                illegal_internal2 <= '0';
                                            else
                                                opcode <= i_SRLI;
                                                illegal_internal2 <= '0';
                                            end if;

                                        when "111" =>
                                            opcode <= i_ANDI; 
                                            illegal_internal2 <= '0';
                                        when others =>
                                            opcode <= i_NOP;
                                            illegal_internal2 <= '0';

                                    end case;
                                
                                when "00011" =>
                                    opcode <= i_FENCE; 
                                    illegal_internal2 <= '0';

                                when "00000" =>

                                    case instruction(14 downto 12) is

                                        when "000" =>
                                            opcode <= i_LB;
                                            illegal_internal2 <= '0';
                                        when "001" =>
                                            opcode <= i_LH;
                                            illegal_internal2 <= '0';
                                        when "010" =>
                                            opcode <= i_LW;
                                            illegal_internal2 <= '0';
                                        when "100" =>
                                            opcode <= i_LBU;
                                            illegal_internal2 <= '0';
                                        when "101" =>
                                            opcode <= i_LHU;
                                            illegal_internal2 <= '0';
                                        when others =>
                                            opcode <= i_NOP; 
                                            illegal_internal2 <= '1';

                                    end case;
                                        
                                when "11001" => 
                                    if (instruction(14 downto 12) = "000") then
                                        opcode <= i_JALR; 
                                        illegal_internal2 <= '0';
                                    else
                                        opcode <= i_NOP;
                                        illegal_internal2 <= '1';
                                    end if;

                                when "11100" =>
                                    if (instruction(20) = '1') then
                                        opcode <= i_ECALL; 
                                        illegal_internal2 <= '0';      
                                    else
                                        opcode <= i_EBREAK; 
                                        illegal_internal2 <= '0';
                                    end if;

                                when others => 
                                    opcode <= i_NOP;
                                    illegal_internal2 <= '1';

                            end case;


                        -- Memory operation
                        when S =>
                            rd_internal <=                                  (others => '0');
                            rs1_internal <=                                 instruction(19 downto 15); 
                            rs2_internal <=                                 instruction(24 downto 20);
                            imm_internal <=                                 (others => instruction(31));
                            imm_internal(11 downto 0) <=                    instruction(31 downto 25)                       
                                                                          & instruction(11 downto 7);

                            -- Instruction identification
                            case instruction(14 downto 12) is

                                when "000" =>
                                    opcode <= i_SB; 
                                    illegal_internal2 <= '0';
                                when "001" =>
                                    opcode <= i_SH; 
                                    illegal_internal2 <= '0';
                                when "010" =>
                                    opcode <= i_SW; 
                                    illegal_internal2 <= '0';
                                when others =>

                            end case;

                        -- Branches
                        when B =>
                            rd_internal <=                                  (others => '0');
                            rs1_internal <=                                 instruction(19 downto 15);
                            rs2_internal <=                                 instruction(24 downto 20);
                            imm_internal <=                                 (others => instruction(31));
                            imm_internal(11 downto 0) <=                    instruction(31)                                 
                                                                          & instruction(7)                
                                                                          & instruction(30 downto 25)         
                                                                          & instruction(11 downto 8);

                            -- Instruction identification
                            case instruction(14 downto 12) is

                                when "000" =>
                                    opcode <= i_BEQ; 
                                    illegal_internal2 <= '0';
                                when "001" =>
                                    opcode <= i_BNE; 
                                    illegal_internal2 <= '0';
                                when "100" =>
                                    opcode <= i_BLT; 
                                    illegal_internal2 <= '0';
                                when "101" =>
                                    opcode <= i_BGE; 
                                    illegal_internal2 <= '0';
                                when "110" =>
                                    opcode <= i_BLTU; 
                                    illegal_internal2 <= '0';
                                when "111" =>
                                    opcode <= i_BGEU; 
                                    illegal_internal2 <= '0';
                                when others =>
                                    opcode <= i_NOP; 
                                    illegal_internal2 <= '1';

                            end case;

                        -- Immediates values loading
                        when U =>
                            rd_internal <=                                   instruction(11 downto 7);
                            rs1_internal <=                                  (others => '0');
                            rs2_internal <=                                  (others => '0');
                            imm_internal <=                                  instruction(31 downto 12)                       
                                                                           & "000000000000";
                            
                            -- Instruction identification
                            case instruction(6 downto 2) is

                                when "01101" =>
                                    opcode <= i_LUI; 
                                    illegal_internal2 <= '0';
                                when "00101" =>
                                    opcode <= i_AUIPC; 
                                    illegal_internal2 <= '0';
                                when others =>
                                    opcode <= i_NOP; 
                                    illegal_internal2 <= '1';
                            
                            end case;

                        -- Jumps
                        when J =>
                            rd_internal <=                                  (others => '0');
                            rs1_internal <=                                 instruction(19 downto 15); 
                            rs2_internal <=                                 instruction(24 downto 20);
                            imm_internal <=                                 (others => instruction(31));
                            imm_internal(20 downto 1) <=                    instruction(31)                                 
                                                                          & instruction(19 downto 12)     
                                                                          & instruction(20)                   
                                                                          & instruction(30 downto 21);
                            imm_internal(0) <=                              '0';
                            
                            -- Instruction identification
                            case instruction(6 downto 2) is

                                when "11011" =>
                                    opcode <= i_JAL; 
                                    illegal_internal2 <= '0';
                                when others =>
                                    opcode <= i_NOP; 
                                    illegal_internal2 <= '1';
                            
                            end case;

                        when NOP =>
                            rd_internal <=                                  (others => '0');
                            rs1_internal <=                                 (others => '0');
                            rs2_internal <=                                 (others => '0');
                            imm_internal <=                                 (others => '0');
                            opcode <=                                       i_NOP;  
                            illegal_internal2 <=                            '0';                     
                        
                        when others =>
                            rd_internal <=                                  (others => '0');
                            rs1_internal <=                                 (others => '0');
                            rs2_internal <=                                 (others => '0');
                            imm_internal <=                                 (others => '0');
                            opcode <=                                       i_NOP;
                            illegal_internal2 <=                            '1'; 

                    end case;
            
                end if;

            end process;

        -- Compute the illegal status
        illegal_internal_out <= illegal_internal or illegal_internal2;

        -- Output signals, while encouting for illegal state.
        illegal <= illegal_internal_out;

        rs1 <= rs1_internal when illegal_internal_out = '0' else
            std_logic_vector(to_unsigned(0, rs1'length));
        rs2 <= rs2_internal when illegal_internal_out = '0' else
            std_logic_vector(to_unsigned(0, rs2'length));
        rd <= rd_internal when illegal_internal_out = '0' else
            std_logic_vector(to_unsigned(0, rd'length));
        imm <= imm_internal when illegal_internal_out = '0' else
            std_logic_vector(to_unsigned(0, imm'length));

    end architecture;

    -- Instructions lists

-- Type	    Opcode	    Funct3	Funct7	        Instruction	    Description                             Cycles Numbers  Remarks

-- R-Type	0110011	    000	    0000000	        ADD	            Add                                     1               N/A
-- R-Type	0110011	    001	    0000000	        SLL	            Shift Left Logical                      1               N/A
-- R-Type	0110011	    010	    0000000	        SLT	            Set if Less Than                        1               N/A
-- R-Type	0110011	    011	    0000000	        SLTU	        Set if < (Unsigned)                     1               N/A
-- R-Type	0110011	    100	    0000000	        XOR	            XOR                                     1               N/A
-- R-Type	0110011	    101	    0000000	        SRL	            Shift Right Logical                     1               N/A
-- R-Type	0110011	    110	    0000000	        OR	            OR                                      1               N/A
-- R-Type	0110011	    111	    0000000	        AND	            AND                                     1               N/A

-- R-Type	0110011	    000	    0100000	        SUB	            Subtract                                1               N/A
-- R-Type	0110011	    101	    0100000	        SRA	            Shift Right Arithmetic                  1               N/A

-- I-Type	0010011	    000	    N/A	            ADDI	        Add Immediate                           1               N/A
-- I-Type	0010011	    010	    N/A	            SLTI	        Set if Less Than Immediate              1               N/A       
-- I-Type	0010011	    011	    N/A	            SLTIU	        Set if < Immediate (Unsigned)           1               N/A
-- I-Type	0010011	    100	    N/A	            XORI	        XOR Immediate                           1               N/A
-- I-Type	0010011	    110	    N/A	            ORI	            OR Immediate                            1               N/A
-- I-Type	0010011	    111	    N/A	            ANDI	        AND Immediate                           1               N/A
-- I-Type	0010011	    001	    0000000	        SLLI	        Shift Left Logical Immediate            1               N/A
-- I-Type	0010011	    101	    0000000	        SRLI	        Shift Right Logical Immediate           1               N/A
-- I-Type	0010011	    101	    0100000	        SRAI	        Shift Right Arithmetic Immediate        1               N/A

-- I-Type	0001111	    000	    N/A	            FENCE	        Fence                                   ?               Block any unterminated IO operation --> NOP

-- I-Type	0000011	    000	    N/A	            LB	            Load Byte                               ?               May take time (how much ?). Does not block by default, FENCE op if needed.
-- I-Type	0000011	    001	    N/A	            LH	            Load Halfword                           ?               May take time (how much ?). Does not block by default, FENCE op if needed.
-- I-Type	0000011	    010	    N/A	            LW	            Load Word                               ?               May take time (how much ?). Does not block by default, FENCE op if needed.
-- I-Type	0000011	    100	    N/A	            LBU	            Load Byte (Unsigned)                    ?               May take time (how much ?). Does not block by default, FENCE op if needed.
-- I-Type	0000011	    101	    N/A	            LHU	            Load Halfword (Unsigned)                ?               May take time (how much ?). Does not block by default, FENCE op if needed.

-- I-Type	1100111	    000	    N/A	            JALR	        Jump and Link Register                  1               Stall the pipeline

-- I-Type	1110011	    000	    000000000000	ECALL	        Environment Call                        4               Stall the pipeline + execution mode to priviledged
-- I-Type	1110011	    000	    000000000001	EBREAK	        Environment Breakpoint                  4               Stall the pipeline + execution mode to user
-- Unused ECALL / EBREAK for simple implementation

-- S-Type	0100011	    000	    N/A	            SB	            Store Byte                              ?               May take time (how much ?). Does not block by default, FENCE op if needed.
-- S-Type	0100011	    001	    N/A	            SH	            Store Halfword                          ?               May take time (how much ?). Does not block by default, FENCE op if needed.
-- S-Type	0100011	    010	    N/A	            SW	            Store Word                              ?               May take time (how much ?). Does not block by default, FENCE op if needed.

-- B-Type	1100011	    000	    N/A	            BEQ	            Branch if Equal                         ?               N/A
-- B-Type	1100011	    001	    N/A	            BNE	            Branch if Not Equal                     ?               N/A
-- B-Type	1100011	    100	    N/A	            BLT	            Branch if Less Than                     ?               N/A
-- B-Type	1100011	    101	    N/A	            BGE	            Branch if Greater Than or Equal         ?               N/A
-- B-Type	1100011	    110	    N/A	            BLTU	        Branch if Less Than (Unsigned)          ?               N/A
-- B-Type	1100011	    111	    N/A	            BGEU	        Branch if >= (Unsigned)                 ?               N/A

-- U-Type	0110111	    N/A	    N/A	            LUI	            Load Upper Immediate                    1               N/A
-- U-Type	0010111	    N/A	    N/A	            AUIPC	        Add Upper Immediate to PC               1               N/A

-- J-Type	1101111	    N/A	    N/A	            JAL	            Jump and Link                           1               Stall the pipeline


