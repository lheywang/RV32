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
        opcode :        out     std_logic_vector(16 downto 0);              -- ISA use an up to 17 bit opcode.
        -- signals
        nILLEGAL :      out     std_logic;

        -- Clocks
        clock :         in      std_logic;
        nRST :          in      std_logic
    );
end entity;

architecture behavioral of decoder is

        -- Defining the different decoders
        type decoders is (U, I, R, B, S, J, default);

        -- signals
        signal nILLEGAL_internal :      std_logic           := '0';
        signal decoder :                decoders            := default;

    begin

        -- Basic checks
        P1 : process(clock, nRST) 
            begin

                if (nRST = '0') then
                    nILLEGAL_internal <= '1';
                    rs1 <= (others => '0');
                    rs2 <= (others => '0');
                    imm <= (others => '0');
                    rd <= (others => '0');
                    opcode <= (others => '0');

                    decoder <= default;

                elsif rising_edge(clock) then

                    case instruction(6 downto 0) is

                        when "0110111" => 
                            decoder <= U;
                            nILLEGAL_internal <= '1';
                        when "0010111" =>
                            decoder <= U;
                            nILLEGAL_internal <= '1';

                        when "0010011" =>
                            decoder <= I;
                            nILLEGAL_internal <= '1';
                        when "0001111" =>
                            decoder <= I;
                            nILLEGAL_internal <= '1';
                        when "1100111" =>
                            decoder <= I;
                            nILLEGAL_internal <= '1';
                        when "1110011" =>
                            decoder <= I;
                            nILLEGAL_internal <= '1';

                        when "0110011" => 
                            decoder <= R;
                            nILLEGAL_internal <= '1';
                        
                        when "1100011" =>
                            decoder <= B;
                            nILLEGAL_internal <= '1';
                        
                        when "0100011" =>
                            decoder <= S;
                            nILLEGAL_internal <= '1';
                        when "0000011" =>
                            decoder <= S;
                            nILLEGAL_internal <= '1';

                        when "1101111" =>
                            decoder <= J;
                            nILLEGAL_internal <= '1';

                        when others =>
                            decoder <= default;
                            nILLEGAL_internal <= '0';

                    end case;
                end if;
                
            end process;

        -- Always bounded
        nILLEGAL <= nILLEGAL_internal;

    end architecture;