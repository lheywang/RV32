library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo is
    generic (
        XLEN :          integer := 32;    -- instruction width
        DEPTH  :        integer := 4      -- number of entries
    );
    port (
        clk :       in  std_logic;
        clk_en :    in  std_logic;
        nRST :      in  std_logic;

        -- Push side (memory -> FIFO)
        wr_en :     in  std_logic;
        din :       in  std_logic_vector((XLEN - 1) downto 0);

        -- Pop side (FIFO -> decoder)
        rd_en :     in  std_logic;
        dout :      out std_logic_vector((XLEN - 1) downto 0)
    );
end entity;

architecture rtl of fifo is
    -- calculate address width
    function clog2(n : integer) return integer is
        variable r : integer := 0;
        variable v : integer := n - 1;
    begin
        while v > 0 loop
            r := r + 1;
            v := v / 2;
        end loop;
        return r;
    end function;

    constant ADDR_WIDTH : integer := clog2(DEPTH);

    type ram_t is array (0 to DEPTH-1) of std_logic_vector((XLEN - 1) downto 0);
    signal ram : ram_t;

    signal wr_ptr : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal rd_ptr : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');

    signal bypass : std_logic;

begin
    -- Write
    process(clk, nRST)
    begin
        if (nRST = '0') then

            wr_ptr <= (others => '0');
            ram <= (others => (others => '0'));
            rd_ptr <= (others => '0');
            dout   <= (others => '0');
            bypass <= '0';

        elsif rising_edge(clk) and (clk_en = '1') then

            if (wr_en = '1') then

                ram(to_integer(wr_ptr)) <= din;
                wr_ptr <= wr_ptr + 1;

            end if;

            if (rd_en = '1') and  (wr_en = '0' or bypass = '1') then

                dout   <= ram(to_integer(rd_ptr));
                rd_ptr <= rd_ptr + 1;
                -- bypass <= '1';
            
            -- enable to "skip" the first load, and thus set count = 1.
            else
                
                bypass <= '1';

            end if;

        end if;

    end process;

end architecture;