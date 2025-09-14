-- Recommended sim length : 5 us
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity register_file_tb is 
end entity;

architecture behavioral of register_file_tb is

        signal clock_t :    std_logic                       := '0';         
        signal nRST_t :     std_logic                       := '0';
        signal in1_t :      std_logic_vector(31 downto 0)   := (others => '0');
        signal in2_t :      std_logic_vector(31 downto 0)   := (others => '0');
        signal out1_t :     std_logic_vector(31 downto 0)   := (others => '0');
        signal out2_t :     std_logic_vector(31 downto 0)   := (others => '0');
        signal sel_in1_t :  std_logic_vector(31 downto 0)   := (others => '0');
        signal sel_in2_t :  std_logic_vector(31 downto 0)   := (others => '0');
        signal sel_out1_t : std_logic_vector(31 downto 0)   := (others => '0');
        signal sel_out2_t : std_logic_vector(31 downto 0)   := (others => '0');

    begin

        U1 : entity work.register_file(behavioral)
            generic map (
                XLEN        => 32,
                REG_NB      => 32
            )
            port map (
                clock       => clock_t,
                nRST        => nRST_t,
                in1         => in1_t,
                in2         => in2_t,
                out1        => out1_t,
                out2        => out2_t,
                sel_in1     => sel_in1_t,
                sel_in2     => sel_in2_t,
                sel_out1    => sel_out1_t,
                sel_out2    => sel_out2_t
            );

        -- Clock
        P1 : process
        begin
            wait for 10 ns;
            clock_t <= not clock_t;
        end process;

        -- Reset controller
        P2 : process
        begin
            nRST_t <= '0';
            wait for 15 ns;
            nRST_t <= '1';
            wait for 100 sec;
        end process;

        -- Manage data input
        P3 : process
        begin
            in1_t <= X"deadbeef";
            in2_t <= X"beefdead";
            wait for 40 ns;
            in1_t <= X"aaaaaaaa";
            in2_t <= X"bbbbbbbb";
            wait for 40 ns;
            in1_t <= X"cccccccc";
            in2_t <= X"dddddddd";
            wait for 40 ns;
            in1_t <= X"eeeeeeee";
            in2_t <= X"ffffffff";
            wait for 40 ns;
            in1_t <= X"55555555";
            in2_t <= X"11111111";
            wait for 40 ns;
            in1_t <= X"22222222";
            in2_t <= X"99999999";
            wait for 40 ns;
            in1_t <= X"77777777";
            in2_t <= X"33333333";
            wait for 40 ns;
            in1_t <= X"66666666";
            in2_t <= X"44444444";
            wait for 40 ns;
        end process;

        -- Registers writes
        P4 : process
        begin
            sel_in1_t <= X"00000001";
            sel_in2_t <= X"00000002";
            wait for 20 ns;
            sel_in1_t <= X"00000004";
            sel_in2_t <= X"00000008";
            wait for 20 ns;
            sel_in1_t <= X"00000010";
            sel_in2_t <= X"00000020";
            wait for 20 ns;
            sel_in1_t <= X"00000040";
            sel_in2_t <= X"00000080";
            wait for 20 ns;
            sel_in1_t <= X"00000100";
            sel_in2_t <= X"00000200";
            wait for 20 ns;
            sel_in1_t <= X"00000400";
            sel_in2_t <= X"00000800";
            wait for 20 ns;
            sel_in1_t <= X"00001000";
            sel_in2_t <= X"00002000";
            wait for 20 ns;
            sel_in1_t <= X"00004000";
            sel_in2_t <= X"00008000";
            wait for 20 ns;
            sel_in1_t <= X"00010000";
            sel_in2_t <= X"00020000";
            wait for 20 ns;
            sel_in1_t <= X"00040000";
            sel_in2_t <= X"00080000";
            wait for 20 ns;
            sel_in1_t <= X"00100000";
            sel_in2_t <= X"00200000";
            wait for 20 ns;
            sel_in1_t <= X"00400000";
            sel_in2_t <= X"00800000";
            wait for 20 ns;
            sel_in1_t <= X"01000000";
            sel_in2_t <= X"02000000";
            wait for 20 ns;
            sel_in1_t <= X"04000000";
            sel_in2_t <= X"08000000";
            wait for 20 ns;
            sel_in1_t <= X"10000000";
            sel_in2_t <= X"20000000";
            wait for 20 ns;
            sel_in1_t <= X"40000000";
            sel_in2_t <= X"80000000";
            wait for 20 ns;
        end process;

        -- Registers reads
        P5 : process
        begin
            sel_out1_t <= X"40000000";
            sel_out2_t <= X"80000000" ;          
            wait for 20 ns;
            sel_out1_t <= X"00000004";
            sel_out2_t <= X"00000008";
            wait for 20 ns;
            sel_out1_t <= X"00000010";
            sel_out2_t <= X"00000020";
            wait for 20 ns;
            sel_out1_t <= X"00000040";
            sel_out2_t <= X"00000080";
            wait for 20 ns;
            sel_out1_t <= X"00000100";
            sel_out2_t <= X"00000200";
            wait for 20 ns;
            sel_out1_t <= X"00000400";
            sel_out2_t <= X"00000800";
            wait for 20 ns;
            sel_out1_t <= X"00001000";
            sel_out2_t <= X"00002000";
            wait for 20 ns;
            sel_out1_t <= X"00400000";
            sel_out2_t <= X"02000000";
            wait for 20 ns;
            sel_out1_t <= X"00010000";
            sel_out2_t <= X"00020000";
            wait for 20 ns;
            sel_out1_t <= X"00040000";
            sel_out2_t <= X"00080000";
            wait for 20 ns;
            sel_out1_t <= X"20000000";
            sel_out2_t <= X"00200000";
            wait for 20 ns;
            sel_out1_t <= X"00004000";
            sel_out2_t <= X"00800000";
            wait for 20 ns;
            sel_out1_t <= X"01000000";
            sel_out2_t <= X"80000000";
            wait for 20 ns;
            sel_out1_t <= X"04000000";
            sel_out2_t <= X"08000000";
            wait for 20 ns;
            sel_out1_t <= X"10000000";
            sel_out2_t <= X"00100000";
            wait for 20 ns;
            sel_out1_t <= X"40000000";
            sel_out2_t <= X"00008000";
            wait for 20 ns;
            sel_out1_t <= X"00000001";
            sel_out2_t <= X"00000002";
            wait for 20 ns;
        end process;


    end architecture;