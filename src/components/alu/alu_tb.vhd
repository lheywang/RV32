-- recommended sim lenght : 5 us

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.common.all;

entity alu_tb is 
end entity;

architecture behavioral of alu_tb is

        signal arg1_t :     std_logic_vector(31 downto 0)               := (others => '0');
        signal arg2_t :     std_logic_vector(31 downto 0)               := (others => '0');
        signal result_t :   std_logic_vector(31 downto 0)               := (others => '0');
        signal command_t :  commands                                    := c_NONE;
        signal outen_t :    std_logic                                   := '0';
        signal overflow_t : std_logic                                   := '0';
        signal beq_t :      std_logic                                   := '0';
        signal bne_t :      std_logic                                   := '0';
        signal blt_t :      std_logic                                   := '0';
        signal bge_t :      std_logic                                   := '0';
        signal bltu_t :     std_logic                                   := '0';
        signal bgeu_t :     std_logic                                   := '0';

    begin

        U1 : entity work.alu(behavioral)
            generic map (
                XLEN        => 32
            )
            port map (
                arg1        =>  arg1_t,
                arg2        =>  arg2_t,
                result      =>  result_t,
                command     =>  command_t,
                outen       =>  outen_t,
                overflow    =>  overflow_t,
                beq         =>  beq_t,
                bne         =>  bne_t,
                bge         =>  bge_t,
                blt         =>  blt_t,
                bltu        =>  bltu_t,
                bgeu        =>  bgeu_t
            );

        -- Instructions cycles
        P1 : process
        begin
            command_t <=    c_ADD;
            wait for 140 ns;
            command_t <=    c_SUB;
            wait for 140 ns;
            command_t <=    c_AND;
            wait for 140 ns;
            command_t <=    c_OR;
            wait for 140 ns;
            command_t <=    c_XOR;
            wait for 140 ns;
            command_t <=    c_SLL;
            wait for 140 ns;
            command_t <=    c_SRL;
            wait for 140 ns;
            command_t <=    c_SRA;
            wait for 140 ns;
            command_t <=    c_SLT;
            wait for 140 ns;
            command_t <=    c_SLTU;
            wait for 140 ns;
            command_t <=    c_NONE;
            wait for 140 ns;
        end process;

        -- Input controls
        P2 : process
        begin
            -- Standard operations
            arg1_t <=     std_logic_vector(to_signed(12,            arg1_t'length));
            arg2_t <=     std_logic_vector(to_signed(5,             arg2_t'length));
            wait for 20 ns;
            arg1_t <=     std_logic_vector(to_signed(-10,           arg1_t'length));
            arg2_t <=     std_logic_vector(to_signed(-5,            arg2_t'length));
            wait for 20 ns;
            -- Zero crossing
            arg1_t <=     std_logic_vector(to_signed(3,             arg1_t'length));
            arg2_t <=     std_logic_vector(to_signed(-5,            arg2_t'length));
            wait for 20 ns;
            arg1_t <=     std_logic_vector(to_signed(-3,            arg1_t'length));
            arg2_t <=     std_logic_vector(to_signed(-5,            arg2_t'length));
            wait for 20 ns;
            -- Overflows
            arg1_t <=     std_logic_vector(to_signed(2147483640,    arg1_t'length));
            arg2_t <=     std_logic_vector(to_signed(64,            arg2_t'length));
            wait for 20 ns;
            arg1_t <=     std_logic_vector(to_signed(-64,           arg1_t'length));
            arg2_t <=     std_logic_vector(to_signed(2147483640,    arg2_t'length));
            wait for 20 ns;
            arg1_t <=     std_logic_vector(to_signed(128,           arg1_t'length));
            arg2_t <=     std_logic_vector(to_signed(128,           arg2_t'length));
            wait for 20 ns;            

        end process;

        -- Output enable control
        P3 : process
        begin
            outen_t <= '1';
            wait for 1540 ns;
            outen_t <= '0';
            wait for 1540 ns;
        end process;

    end architecture;

