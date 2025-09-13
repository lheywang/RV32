library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pcounter is 
    generic (
        XLEN :      integer := 32;                                      -- Width of the data address.
        RESET_ADDR :integer := 0;                                       -- Address immediately outputed on reset
        INCREMENT : integer := 4                                        -- Increment step of the program counter.
    );
    port (
        -- IO ports
        address :   out      std_logic_vector((XLEN - 1) downto 0);     -- Output of the address
        address_in :in       std_logic_vector((XLEN - 1) downto 0);     -- Input of the address, for jumps

        -- Status
        nOVER :     out     std_logic;                                  -- Signals an overflow of the counter (shall trigger an exception)

        -- Clocks
        clock :     in      std_logic;                                  -- Main clock

        -- Control signals
        nRST :      in      std_logic;                                  -- Reset. Force a 0'b00--000 value
        load :      in      std_logic;                                  -- Force synchronous load of the counter
        enable :    in      std_logic                                   -- enable operation of the counter. Increment on rising edge.         
    );
end entity;

architecture behavioral of pcounter is

        signal internal_address :   unsigned((XLEN - 1) downto 0);
        signal address_maxval :     unsigned((XLEN - 1) downto 0)       := (others => '1');
        signal internal_nOVER :     std_logic;

    begin

        P1 : process(clock, nRST)
            begin
                if (nRST = '0') then
                    internal_address <= to_unsigned(RESET_ADDR, internal_address'length);
                    internal_nOVER <= '0';
                
                elsif rising_edge(clock) then

                    if (load = '1') then
                        internal_address <= unsigned(address_in);
                        internal_nOVER <= '0';

                    elsif (enable = '1') and (internal_nOVER = '0') then
                        internal_address <= internal_address + INCREMENT;

                        if (internal_address = address_maxval) then
                            internal_nOVER <= '1';
                        end if;

                    end if;
                
                end if;

            end process;

        -- Output assignement, in any time.
        address <= std_logic_vector(internal_address); 
        nOVER <= not internal_nOVER;

    end architecture;