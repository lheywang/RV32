library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ram is 
    generic (
        XLEN :          integer := 32;                                                  -- Number of bits stored by the register.
        RAM_ADDR :      integer := 16#2000_0000#;                                       -- Base address of memory, only used for checking illegal addresses.
        RAM_SIZE :      integer := 16#0001_FFFF#                                        -- RAM size in bytes (128 kB by default).
    );
    port (
        -- standard
        clock :         in  std_logic;                                                  -- clock for the system
        nRST :          in  std_logic;                                                  -- Reset signal

        -- Bus IOs
        WR :            in  std_logic;                                                  -- \R/W signal (0 = read, 1 = write)
        addr :          in  std_logic_vector((XLEN - 1) downto 0);                      -- address bus
        datain :        in  std_logic_vector((XLEN - 1) downto 0);                      -- data input
        dataout :       out std_logic_vector((XLEN - 1) downto 0)   := (others => '0'); -- data output
        byte_en :       in  std_logic_vector(((XLEN / 8) - 1) downto 0);                -- byte enabling
        data_valid :    out std_logic;                                                  -- Enable the data is valid for usage.

        -- status
        busy :          out std_logic                               := '0';             -- Indicate that a memory operation is currently running.
        illegal_addr :  out std_logic                               := '0'              -- Indicate an impossible memory address.  
    );
end entity;

architecture behavioral of ram is

        -- Create the memory array
        type ram_array is array(0 to (RAM_SIZE / 4)) of std_logic_vector((XLEN - 1) downto 0);
        signal mem : ram_array := (others => (others => '0'));

        -- Internal busy signal
        signal mem_busy : std_logic := '0';
        signal wrong_addr : std_logic := '0';

    begin

        P1 : process(clock, nRST)

            variable word_addr : integer;

        begin
            if (nRST = '0') then
                -- Clear the memory array
                mem <= (others => (others => '0'));
                mem_busy <= '0';

                -- Reset outputs
                dataout <= (others => '0');
                busy <= '0';
                data_valid <= '0';

            elsif rising_edge(clock) then

                if (mem_busy = '0') then -- Memory is busy, don't look for memory IO. The signal is also sent to controller.
                    if (wrong_addr = '0') then

                        -- assign the word address value
                        word_addr := to_integer((unsigned(addr) - RAM_ADDR) / 4);

                        if (WR = '0') then  -- read
                            for i in 0 to 3 loop
                                if byte_en(i) = '1' then
                                    dataout(8*(i+1)-1 downto 8*i) <= mem(word_addr)(8*(i+1)-1 downto 8*i);
                                end if;
                            end loop;

                        else                -- write
                            for i in 0 to 3 loop
                                if byte_en(i) = '1' then
                                    mem(word_addr)(8*(i+1)-1 downto 8*i) <= datain(8*(i+1)-1 downto 8*i);
                                end if;
                            end loop;
                            dataout <= (others => '0');
                        end if;

                        mem_busy <= '1';

                    else
                        dataout <= (others => '0');

                    end if;

                    data_valid <= '0';

                else -- Memory IO take a single cycle on Intel M9K, so we can safely reset it here.
                    mem_busy <= '0';
                    data_valid <= '1';

                end if;

            end if;

        end process;

        -- Check for any changes of address if it is valid
        P2 : process(addr)
        begin
            if (unsigned(addr) + 1 > (RAM_ADDR)) and ((unsigned(addr) < (RAM_ADDR + RAM_SIZE + 1))) then
                wrong_addr <= '0';
            else
                wrong_addr <= '1';
            end if;
        end process;
    
        illegal_addr <= wrong_addr;

    end architecture;