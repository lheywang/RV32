-- recommended sim lenght : 200 ns

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity reg_tb is
end entity;

architecture behavioral of reg_tb is

    signal datain_t :       std_logic_vector(31 downto 0)           := X"deadbeef";
    signal dataout_t :      std_logic_vector(31 downto 0)           := (others => '0');
    signal clock_t :        std_logic                               := '0';
    signal nRST_t :         std_logic                               := '0';
    signal WREN_t :         std_logic                              := '0';
    signal INPU_t :         std_logic                               := '0';

    begin

        U1 : entity work.reg(behavioral)
            generic map (
                XLEN    =>  32
            )
            port map (
                datain  =>  datain_t,
                dataout =>  dataout_t,
                clock   =>  clock_t,
                nRST    =>  nRST_t,
                WREN    =>  WREN_t,
                INPU    =>  INPU_t
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
                INPU_t <= '1';
                wait for 14 ns;
                INPU_t <= '0';
                wait for 5 ns;
                
                -- wait for real, and copy the data
                wait for 100 ns;
                datain_t <= X"beefdead";
                INPU_t <= '1';
                wait for 20 ns;
                INPU_t <= '0';

                wait for 10 ms;
            end process;

        P4 : process
            begin
                wait for 100 ns;
                WREN_t <= '1';
                wait for 40 ns;
                WREN_t <= '0';
                wait for 40 ns;
            end process;


    end architecture;