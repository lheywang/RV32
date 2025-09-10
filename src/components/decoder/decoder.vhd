library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity decoder is 
    generic (
        XLEN :      integer := 32;                                          -- Width of the data outputs. 
                                                                            -- Warning : This does not change the number of registers not instruction lenght
        REG_NB :    integer := 32                                           -- Number of processors registers.
    );
    port (
        -- instruction input
        instruction :   in      std_logic_vector(31 downto 0);

        -- outputs
        -- buses
        rs1 :           out     std_logic_vector((REG_NB + 1) downto 0);    -- Two more register here, for the selection of immediate value and PC respectively.
        rs2 :           out     std_logic_vector((REG_NB - 1) downto 0);    
        rd :            out     std_logic_vector((REG_NB - 1) downto 0);
        imm :           out     std_logic_vector((XLEN - 1) downto 0);
        opcode :        out     std_logic_vector(14 downto 0);              -- ISA use an up to 14 bit opcode.
        -- signals
        illegal :      out     std_logic;

        -- Clocks
        clock :         in      std_logic;
        nRST :          in      std_logic
    );
end entity;

architecture behavioral of decoder is

        -- Defining the different selected_decoders
        type decocders_type is (U, I, R, B, S, J, default_t, illegal_t);

        -- signals
        signal illegal_internal :      std_logic                 := '0';
        signal selected_decoder :      decocders_type            := default_t;

        -- function to convert a 5 bit register ID (0 to 31) into it's correct representation for control
        function f_regID_to_ctrl (
            inp : in std_logic_vector(4 downto 0))
            return std_logic_vector is
                variable retval : std_logic_vector(31 downto 0) := (others => '0');
                variable pos_int    : integer range 0 to 31;
                begin
                    pos_int := to_integer(unsigned(inp));
                    retval(pos_int) := '1';
                return retval;
            end function;


    begin

        -- Basic checks
        P1 : process(clock, nRST) 
            begin

                if (nRST = '0') then
                    illegal_internal <= '0';
                    selected_decoder <= default_t;

                elsif rising_edge(clock) then

                    -- Select the opcode, and perform an instruction size check (last two bits must be "11").
                    case instruction(6 downto 0) is

                        when "0110111" => 
                            selected_decoder <= U;
                            illegal_internal <= '0';
                        when "0010111" =>
                            selected_decoder <= U;
                            illegal_internal <= '0';

                        when "0010011" =>
                            selected_decoder <= I;
                            illegal_internal <= '0';
                        when "0001111" =>
                            selected_decoder <= I;
                            illegal_internal <= '0';
                        when "1100111" =>
                            selected_decoder <= I;
                            illegal_internal <= '0';
                        when "1110011" =>
                            selected_decoder <= I;
                            illegal_internal <= '0';

                        when "0110011" => 
                            selected_decoder <= R;
                            illegal_internal <= '0';
                        
                        when "1100011" =>
                            selected_decoder <= B;
                            illegal_internal <= '0';
                        
                        when "0100011" =>
                            selected_decoder <= S;
                            illegal_internal <= '0';
                        when "0000011" =>
                            selected_decoder <= S;
                            illegal_internal <= '0';

                        when "1101111" =>
                            selected_decoder <= J;
                            illegal_internal <= '0';

                        when others =>
                            selected_decoder <= illegal_t;
                            illegal_internal <= '1';

                    end case;
                end if;
                
            end process;

        -- Hardware selected_decoder selection logic
        P2 : process(selected_decoder, nRST)
            begin
                if (nRST = '0') then
                    rs1 <= (others => '0');
                    rs2 <= (others => '0');
                    imm <= (others => '0');
                    rd <= (others => '0');
                    opcode <= (others => '0');

                else

                    -- Todo : Parse sub-opcode instruction and check for validity.
                    case selected_decoder is 

                        -- Register to register operation
                        when R =>
                            rd <=                                   f_regID_to_ctrl(instruction(11 downto 7));
                            rs1 <=      "00" &                      f_regID_to_ctrl(instruction(19 downto 15));
                            rs2 <=                                  f_regID_to_ctrl(instruction(24 downto 20));
                            imm <=                                  (others => '0');
                            opcode <=                               instruction(31 downto 25)                       & instruction(14 downto 12)     & instruction(6 downto 2);

                        -- Immediate to register operation
                        when I =>
                            rd <=                                   f_regID_to_ctrl(instruction(11 downto 7));
                            rs1 <=      "00" &                      f_regID_to_ctrl(instruction(19 downto 15));
                            rs2 <=                                  (others => '0');
                            imm <=                                  (others => instruction(31));
                            imm(11 downto 0) <=                     instruction(31 downto 20);
                            opcode <=   "0000000" &                 instruction(14 downto 12)                       & instruction(6 downto 2);

                        -- Memory operation
                        when S =>
                            rd <=                                   (others => '0');
                            rs1 <=      "00" &                      f_regID_to_ctrl(instruction(19 downto 15));
                            rs2 <=                                  f_regID_to_ctrl(instruction(24 downto 20));
                            imm <=                                  (others => instruction(31));
                            imm(11 downto 0) <=                     instruction(31 downto 25)                       & instruction(11 downto 7);
                            opcode <=   "0000000" &                 instruction(14 downto 12)                       & instruction(6 downto 2);

                        -- Branches
                        when B =>
                            rd <=                                   (others => '0');
                            rs1 <=      "00" &                      f_regID_to_ctrl(instruction(19 downto 15));
                            rs2 <=                                  f_regID_to_ctrl(instruction(24 downto 20));
                            imm <=                                  (others => instruction(31));
                            imm(11 downto 0) <=                     instruction(31)                                 & instruction(7)                & instruction(30 downto 25)         & instruction(11 downto 8);
                            opcode <=   "0000000" &                 instruction(14 downto 12)                       & instruction(6 downto 2);

                        -- Immediates values loading
                        when U =>
                            rd <=                                   f_regID_to_ctrl(instruction(11 downto 7));
                            rs1 <=                                  (others => '0');
                            rs2 <=                                  (others => '0');
                            imm <=                                  instruction(31 downto 12)                       & "000000000000";
                            opcode <=   "0000000000" &              instruction(6 downto 2);

                        -- Jumps
                        when J =>
                            rd <=                                   (others => '0');
                            rs1 <=      "00" &                      f_regID_to_ctrl(instruction(19 downto 15));
                            rs2 <=                                  f_regID_to_ctrl(instruction(24 downto 20));
                            imm <=                                  (others => instruction(31));
                            imm(20 downto 1) <=                     instruction(31)                                 & instruction(19 downto 12)     & instruction(20)                   & instruction(30 downto 21);
                            imm(0) <=                               '0';
                            opcode <=   "0000000000" &              instruction(6 downto 2);
                            
                        when illegal_t =>
                            rd <=                                   (others => '0');
                            rs1 <=                                  (others => '0');
                            rs2 <=                                  (others => '0');
                            imm <=                                  (others => '0');
                            opcode <=                               (others => '1');

                        when others =>
                            rd <=                                   (others => '0');
                            rs1 <=                                  (others => '0');
                            rs2 <=                                  (others => '0');
                            imm <=                                  (others => '0');
                            opcode <=                               (others => '0');

                    end case;
            
                end if;

            end process;

        -- Always bounded
        illegal <= illegal_internal;

    end architecture;