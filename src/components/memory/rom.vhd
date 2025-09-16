library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
-- quartus shall ignore it by itself
use std.textio.all;

entity rom is 
    generic (
        XLEN :          integer := 32;                                                  -- Number of bits stored by the register.
        ROM_ADDR :      integer := 16#0000_0000#;                                       -- Base address of memory, only used for checking illegal addresses.
        ROM_SIZE :      integer := 16#0002_FFFF#;                                       -- RAM size in bytes (192 kB by default).

        DEBUG :         boolean := false                                                -- When set to true, call a memory initialization from a file. Otherwise, use the Quartus attribute loaders.
    );
    port (
        -- standard
        clock :         in  std_logic;                                                  -- clock for the system
        nRST :          in  std_logic;                                                  -- Reset signal

        -- Bus IOs
        addr1 :         in  std_logic_vector((XLEN - 1) downto 0);                      -- address bus 1
        addr2 :         in  std_logic_vector((XLEN - 1) downto 0);                      -- address bus 2
        dataout1 :      out std_logic_vector((XLEN - 1) downto 0)   := (others => '0'); -- data output 1
        dataout2 :      out std_logic_vector((XLEN - 1) downto 0)   := (others => '0'); -- data output 2
        byte_en1 :      in  std_logic_vector(((XLEN / 8) - 1) downto 0);                -- byte enabling 1
        byte_en2 :      in  std_logic_vector(((XLEN / 8) - 1) downto 0);                -- byte enabling 2
        data_valid1 :   out std_logic;                                                  -- Enable the data is valid for usage 1
        data_valid2 :   out std_logic;                                                  -- Enable the data is valid for usage 2

        -- status
        busy1 :         out std_logic                               := '0';             -- Indicate that a memory operation is currently running 1
        busy2 :         out std_logic                               := '0';             -- Indicate that a memory operation is currently running 2
        illegal_addr :  out std_logic                               := '0'              -- Indicate an impossible memory address (on any of the ports)
    );
end entity;

architecture behavioral of rom is

        -- Create the memory array
        type rom_array is array(0 to (ROM_SIZE / 4)) of std_logic_vector((XLEN - 1) downto 0);
        

        -- Internal busy signal
        signal mem_busy1 : std_logic := '0';
        signal mem_busy2 : std_logic := '0';
        signal wrong_addr1 : std_logic := 'X';
        signal wrong_addr2 : std_logic := 'X';

        -- function hex_char_to_int(c : in character) return integer is
        -- begin
        --     if c >= '0' and c <= '9' then
        --         return character'pos(c) - character'pos('0');
        --     elsif c >= 'A' and c <= 'F' then
        --         return 10 + character'pos(c) - character'pos('A');
        --     elsif c >= 'a' and c <= 'f' then
        --         return 10 + character'pos(c) - character'pos('a');
        --     else
        --         return 0;
        --     end if;
        -- end function;

        -- function hex_to_slv(hex : in string; bits : in natural) return std_logic_vector is
        --     variable result : std_logic_vector(bits-1 downto 0) := (others => '0');
        --     variable val    : integer := 0;
        -- begin
        --     for i in hex'range loop
        --         val := val * 16 + hex_char_to_int(hex(i));
        --     end loop;
        --     result := std_logic_vector(to_unsigned(val, bits));
        --     return result;
        -- end function;

        -- procedure load_mem_from_file(signal outmem : out rom_array; fname : in string) is
        --     file f      : text open read_mode is fname;
        --     variable l  : line;
        --     variable s  : string(1 to 8);  -- 8 hex chars per line
        --     variable v  : std_logic_vector(31 downto 0);
        --     variable idx : integer := 0;
        --     variable i   : integer;
        --     variable len : integer;
        -- begin
        --     while not endfile(f) loop
        --         readline(f, l);  -- read one line

        --         -- Fill s safely, pad if line too short
        --         len := l'length;
        --         for i in 1 to 8 loop
        --             if i <= len then
        --                 s(i) := l(i);
        --             else
        --                 s(i) := '0';
        --             end if;
        --         end loop;

        --         -- Convert hex string to std_logic_vector
        --         v := hex_to_slv(s, 32);
        --         outmem(idx) <= v;
        --         idx := idx + 1;
        --     end loop;
        -- end procedure;

        -- For quartus build only : Initialyze ROM from file
        -- attribute ram_init_file : string;
        -- attribute ram_init_file of mem : signal is "code/output/rom.hex";

        impure function init_ram_hex return rom_array is
            file text_file : text open read_mode is "code/output/rom.bin";
            variable text_line : line;
            variable ram_content : rom_array;
            variable c : character;
            variable offset : integer;
            variable hex_val : std_logic_vector(3 downto 0);
        begin
        for i in 0 to rom_array'high - 1 loop
            readline(text_file, text_line);
        
            offset := 0;
        
            while offset < ram_content(i)'high loop
                read(text_line, c);
            
                case c is
                    when '0' => hex_val := "0000";
                    when '1' => hex_val := "0001";
                    when '2' => hex_val := "0010";
                    when '3' => hex_val := "0011";
                    when '4' => hex_val := "0100";
                    when '5' => hex_val := "0101";
                    when '6' => hex_val := "0110";
                    when '7' => hex_val := "0111";
                    when '8' => hex_val := "1000";
                    when '9' => hex_val := "1001";
                    when 'A' | 'a' => hex_val := "1010";
                    when 'B' | 'b' => hex_val := "1011";
                    when 'C' | 'c' => hex_val := "1100";
                    when 'D' | 'd' => hex_val := "1101";
                    when 'E' | 'e' => hex_val := "1110";
                    when 'F' | 'f' => hex_val := "1111";
            
                    when others =>
                    hex_val := "XXXX";
                    assert false report "Found non-hex character '" & c & "'";
                end case;
            
                ram_content(i)(ram_content(i)'high - offset
                    downto ram_content(i)'high - offset - 3) := hex_val;
                offset := offset + 4;
            
                end loop;
            end loop;
  
            return ram_content;
        end function;

        signal mem : rom_array := init_ram_hex;

    begin

        -- For GHDL only : Initialize ROM from file
        -- ghdl_loader : if DEBUG generate
        --     P0 : process(nRST)
        --     begin
        --         if (nRST = '0') then
        --             load_mem_from_file(mem, );
        --         end if;
        --     end process;
        -- end generate;
         
        P10 : process(clock, nRST)

            variable word_addr1 : integer;

        begin
            if (nRST = '0') then
                mem_busy1 <= '0';
                dataout1 <= (others => '0');
                busy1 <= '0';
                data_valid1 <= '0';

            elsif rising_edge(clock) then

                if (mem_busy1 = '0') then -- Memory is busy, don't look for memory IO. The signal is also sent to controller.
                    if (wrong_addr1 = '0') then

                        -- assign the word address value
                        word_addr1 := to_integer((unsigned(addr1) - ROM_ADDR) / 4);


                        for i in 0 to 3 loop
                            if byte_en1(i) = '1' then
                                dataout1(8*(i+1)-1 downto 8*i) <= mem(word_addr1)(8*(i+1)-1 downto 8*i);
                            end if;
                        end loop;

                        mem_busy1 <= '1';

                    else
                        dataout1 <= (others => '0');

                    end if;

                    data_valid1 <= '0';

                else -- Memory IO take a single cycle on Intel M9K, so we can safely reset it here.
                    mem_busy1 <= '0';
                    data_valid1 <= '1';

                end if;

            end if;

        end process;

        P11 : process(clock, nRST)

            variable word_addr2 : integer;

        begin
            if (nRST = '0') then
                mem_busy2 <= '0';
                dataout2 <= (others => '0');
                busy2 <= '0';
                data_valid2 <= '0';

            elsif rising_edge(clock) then

                if (mem_busy2 = '0') then -- Memory is busy, don't look for memory IO. The signal is also sent to controller.
                    if (wrong_addr2 = '0') then

                        -- assign the word address value
                        word_addr2 := to_integer((unsigned(addr2) - ROM_ADDR) / 4);


                        for i in 0 to 3 loop
                            if byte_en2(i) = '1' then
                                dataout2(8*(i+1)-1 downto 8*i) <= mem(word_addr2)(8*(i+1)-1 downto 8*i);
                            end if;
                        end loop;

                        mem_busy2 <= '1';

                    else
                        dataout2 <= (others => '0');

                    end if;

                    data_valid2 <= '0';

                else -- Memory IO take a single cycle on Intel M9K, so we can safely reset it here.
                    mem_busy2 <= '0';
                    data_valid2 <= '1';

                end if;

            end if;

        end process;

        -- Check for any changes of address if it is valid
        P2 : process(addr1, addr2)
        begin
            if ((unsigned(addr1) + 1 > (ROM_ADDR)) and ((unsigned(addr1) < (ROM_ADDR + ROM_SIZE + 1)))) then
                wrong_addr1 <= '0';
            else
                wrong_addr1 <= '1';
            end if;

            if ((unsigned(addr2) + 1 > (ROM_ADDR)) and ((unsigned(addr2) < (ROM_ADDR + ROM_SIZE + 1)))) then
                wrong_addr2 <= '0';
            else
                wrong_addr2 <= '1';
            end if;

        end process;
    
        illegal_addr <= wrong_addr1 or wrong_addr2;
        busy1 <= mem_busy1;
        busy2 <= mem_busy2;

    end architecture;