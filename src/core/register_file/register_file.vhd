library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity register_file is
    generic (
        XLEN    : integer := 32;
        REG_NB  : integer := 32
    );
    port (
        clock   : in  std_logic;
        clock_en : in std_logic;
        nRST    : in  std_logic;

        -- single write port
        we      : in  std_logic;
        wa      : in  integer range 0 to REG_NB-1;
        wd      : in  std_logic_vector(XLEN-1 downto 0);

        -- two read ports
        ra1     : in  integer range 0 to REG_NB-1;
        rd1     : out std_logic_vector(XLEN-1 downto 0);

        ra2     : in  integer range 0 to REG_NB-1;
        rd2     : out std_logic_vector(XLEN-1 downto 0)
    );
end entity;

architecture rtl of register_file is

    type reg_array_t is array (0 to REG_NB-1) of std_logic_vector(XLEN-1 downto 0);
    signal reg_array : reg_array_t := (others => (others => '0'));

begin

    -- synchronous write
    process(clock, nRST)
    begin
        if nRST = '0' then
            reg_array <= (others => (others => '0'));
        elsif rising_edge(clock) and (clock_en = '1') then
            if (we = '1') and (wa /= 0) then
                reg_array(wa) <= wd;
            end if;
        end if;
    end process;

    -- asynchronous reads (combinational muxes)
    rd1 <= (others => '0') when ra1 = 0 else reg_array(ra1);
    rd2 <= (others => '0') when ra2 = 0 else reg_array(ra2);

end architecture;


------------------------------------------------------------------------
-- OLD DESIGN
------------------------------------------------------------------------
-- This was using ~2300 LUTs (!!!!), and thus was not usable.
-- Leaved here only for reference, the entity has evolved since. Using OLD_behavioral
-- will *probably* trigger compilation errors.
--
-- The new design use ... ~15 LUTs. Much cleaner !

-- architecture OLD_behavioral of register_file is
    
--     begin
--         -- Register 0 is constant to '000..000'. It cannot be written, and thus is ensured to get a constant 0 value.
--         REG0 : entity work.dualreg(behavioral)
--             generic map (
--                 XLEN    =>  XLEN
--             )
--             port map (
--                 datain1 =>  (others => '0'),
--                 datain2 =>  (others => '0'),
--                 dataout1=>  out1,
--                 dataout2=>  out2,
--                 clock   =>  clock,
--                 nRST    =>  nRST,
--                 WREN1   =>  sel_in1(0),
--                 INPU1   =>  '0',
--                 WREN2   =>  sel_in2(0),
--                 INPU2   =>  '0'
--             );

--         REG_FILE : for i in 1 to (REG_NB - 1) generate

--                 REGX : entity work.dualreg(behavioral)
--                     generic map (
--                         XLEN    =>  XLEN
--                     )
--                     port map (
--                         datain1 =>  in1,
--                         datain2 =>  in2,
--                         dataout1=>  out1,
--                         dataout2=>  out2,
--                         clock   =>  clock,
--                         nRST    =>  nRST,
--                         WREN1   =>  sel_in1(i),
--                         INPU1   =>  sel_out1(i),
--                         WREN2   =>  sel_in2(i),
--                         INPU2   =>  sel_out2(i)
--                     );

--         end generate REG_FILE;

--     end architecture;