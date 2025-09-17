library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rom is
    generic (
        XLEN :            integer := 32;
        ROM_ADDR :        integer := 16#0000_0000#;
        ROM_SIZE :        integer := 16#0002_FFFF#
    );
    port (
        clk         : in  std_logic;
        nRST        : in  std_logic;

        -- Port 0: Instruction fetch
        addr0       : in  std_logic_vector((XLEN - 1) downto 0);
        dataout0    : out std_logic_vector((XLEN - 1) downto 0);
        mem_req0    : in  std_logic;
        mem_busy0   : out std_logic;
        data_valid0 : out std_logic;

        -- Port 1: General-purpose
        addr1       : in  std_logic_vector((XLEN - 1) downto 0);
        byte_en1    : in  std_logic_vector(3 downto 0);
        dataout1    : out std_logic_vector((XLEN - 1) downto 0);
        mem_req1    : in  std_logic;
        mem_busy1   : out std_logic;
        data_valid1 : out std_logic
    );
end rom;

architecture behavioral of rom is

    type rom_array is  array(0 to (ROM_SIZE / 4)) of std_logic_vector(XLEN-1 downto 0);
    

    -- internal registers for one-cycle latency
    signal dout0_reg, dout1_reg : std_logic_vector(XLEN-1 downto 0);
    signal busy0_reg, busy1_reg : std_logic;
    signal valid0_reg, valid1_reg : std_logic;

    impure function init_ram_hex return rom_array is
        variable ram_content : rom_array;
        variable last : integer;
    begin
        last := 0;
        for i in 0 to rom_array'high - 1 loop
            if last = 0 then
                ram_content(i) := "10101010101010101010101010101010";
                last := 1;
            else
                ram_content(i) := "01010101010101010101010101010101";
                last := 0;
            end if;
         end loop;

        return ram_content;
    end function;

    signal mem : rom_array := init_ram_hex;  -- init later with MIF/HEX

begin

    process(clk, nRST)

        variable word_addr0 : integer;
        variable dout_var0 : std_logic_vector(XLEN-1 downto 0);

    begin
        if nRST = '0' then
            dataout0 <= (others => '0');
            busy0_reg <= '0';
            data_valid0 <= '0';

        elsif rising_edge(clk) then
            
            -- === Port 0: Instruction fetch ===
            if mem_req0 = '1' and busy0_reg = '0' then

                word_addr0 := to_integer(unsigned(addr0)) / 4;
                dataout0 <= mem(word_addr0);
                data_valid0 <= '0';

            elsif busy0_reg = '1' then

                busy0_reg <= '0';
                data_valid0 <= '1';

            elsif mem_req0 = '0' then

                dataout0 <= (others => 'Z');

            else
                
                data_valid0 <= '0';

            end if;

        end if;

    end process;

    --     process(clk, nRST)

    --     variable word_addr1 : integer;
    --     variable dout_var1 : std_logic_vector(XLEN-1 downto 0);

    -- begin
    --     if nRST = '0' then
    --         dataout1 <= (others => '0');
    --         busy1_reg <= '0';
    --         data_valid1 <= '0';

    --     elsif rising_edge(clk) then
            
    --         -- === Port 1: Data access ===
    --         if mem_req1 = '1' and busy1_reg = '0' then

    --             word_addr1 := to_integer(unsigned(addr1)) / 4;
    --             dout_var1 := (others => '0');  -- default for byte_en

    --             for i in 0 to byte_en1'high loop
    --                 if byte_en1(i) = '1' then
    --                     dout_var1(8*(i+1)-1 downto 8*i) := mem(word_addr1)(8*(i+1)-1 downto 8*i);
    --                 end if;
    --             end loop;

    --             dataout1 <= dout_var1;
    --             busy1_reg <= '1';
    --             data_valid1 <= '0';

    --         elsif busy1_reg = '1' then

    --             busy1_reg <= '0';
    --             data_valid1 <= '1';

    --         elsif mem_req1 = '0' then

    --             dataout1 <= (others => 'Z');

    --         else

    --             data_valid1 <= '0';

    --         end if;

    --     end if;

    -- end process;

    -- Assign outputs
    mem_busy0   <= busy0_reg;
    mem_busy1   <= busy1_reg;


end behavioral;
