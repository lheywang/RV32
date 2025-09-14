-- recommended sim lenght : 200 ns

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity dualreg_tb is
end entity;

architecture behavioral of dualreg_tb is

        signal datain1_t :      std_logic_vector(31 downto 0)           := X"bbbbbbbb";
        signal datain2_t :      std_logic_vector(31 downto 0)           := X"aaaaaaaa";
        signal dataout1_t :     std_logic_vector(31 downto 0)           := (others => '0');
        signal dataout2_t :     std_logic_vector(31 downto 0)           := (others => '0');
        signal clock_t :        std_logic                               := '0';
        signal nRST_t :         std_logic                               := '0';
        signal WREN1_t :         std_logic                              := '0';
        signal WREN2_t :         std_logic                              := '0';
        signal INPU1_t :         std_logic                              := '0';
        signal INPU2_t :         std_logic                              := '0';

    begin

        U1 : entity work.dualreg(behavioral)
            generic map (
                XLEN    =>  32
            )
            port map (
                datain1 =>  datain1_t,
                datain2 =>  datain2_t,
                dataout1=>  dataout1_t,
                dataout2=>  dataout2_t,
                clock   =>  clock_t,
                nRST    =>  nRST_t,
                WREN1   =>  WREN1_t,
                INPU1   =>  INPU1_t,
                WREN2   =>  WREN2_t,
                INPU2   =>  INPU2_t
            );

        P1 : process
            begin
                clock_t <= not clock_t;
                wait for 10 ns;
            end process;

        P2 : process
            begin
                wait for 100 ns;
                nRST_t <= '1';
            end process;

        P3 : process
            begin
                -- strobe to ensure nothing happen while reset
                wait for 1 ns;
                INPU1_t <= '1';
                wait for 14 ns;
                INPU1_t <= '0';
                wait for 5 ns;
                
                -- wait for real, and copy the data
                wait for 100 ns;
                INPU1_t <= '1';
                INPU2_t <= '0';
                wait for 50 ns;
                INPU1_t <= '0';
                INPU2_t <= '1';
                wait for 50 ns;
                INPU1_t <= '1';
                INPU2_t <= '1';

                wait for 10 ms;
            end process;

        P4 : process
            begin
                wait for 120 ns;
                WREN1_t <= '1';
                wait for 50 ns;
                WREN1_t <= '0';
                WREN2_t <= '1';
                wait for 50 ns;
                WREN1_t <= '1';
                WREN2_t <= '1';
                wait for 50 ns;
            end process;

    end architecture;