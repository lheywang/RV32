library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity register_file_tb is
end entity;

architecture sim of register_file_tb is

    constant XLEN   : integer := 32;
    constant REG_NB : integer := 32;

    -- DUT ports
    signal clock : std_logic := '0';
    signal nRST  : std_logic := '0';

    signal we  : std_logic := '0';
    signal wa  : integer range 0 to REG_NB-1 := 0;
    signal wd  : std_logic_vector(XLEN-1 downto 0) := (others => '0');

    signal ra1 : integer range 0 to REG_NB-1 := 0;
    signal rd1 : std_logic_vector(XLEN-1 downto 0);

    signal ra2 : integer range 0 to REG_NB-1 := 0;
    signal rd2 : std_logic_vector(XLEN-1 downto 0);

begin

    -----------------------------------------------------------------------
    -- DUT instance
    -----------------------------------------------------------------------
    UUT: entity work.register_file(rtl)
        generic map (
            XLEN   => XLEN,
            REG_NB => REG_NB
        )
        port map (
            clock => clock,
            nRST  => nRST,
            we    => we,
            wa    => wa,
            wd    => wd,
            ra1   => ra1,
            rd1   => rd1,
            ra2   => ra2,
            rd2   => rd2
        );

    -----------------------------------------------------------------------
    -- clock generation (10 ns period)
    -----------------------------------------------------------------------
    clock <= not clock after 5 ns;

    -----------------------------------------------------------------------
    -- stimulus
    -----------------------------------------------------------------------
    process
    begin
        -- hold reset
        nRST <= '0';
        wait for 20 ns;
        nRST <= '1';
        wait for 10 ns;

        -- write some values
        for i in 1 to 5 loop
            wa <= i;
            wd <= std_logic_vector(to_unsigned(i*16#10#, XLEN));
            we <= '1';
            wait until rising_edge(clock);
        end loop;
        we <= '0';

        -- read them back
        for i in 0 to 5 loop
            ra1 <= i;
            ra2 <= (i+1) mod REG_NB;
            wait for 10 ns;
            report "ra1=" & integer'image(i) &
                   " rd1=" & integer'image(to_integer(unsigned(rd1))) &
                   " | ra2=" & integer'image((i+1) mod REG_NB) &
                   " rd2=" & integer'image(to_integer(unsigned(rd2)));
        end loop;

        wait;
    end process;

end architecture;