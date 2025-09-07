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
        
        end architecture;
