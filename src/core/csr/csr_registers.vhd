library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity csr_registers is
    generic (
        XLEN    : integer := 32
    );
    port (
        clock   : in  std_logic;
        clock_en : in std_logic;
        nRST    : in  std_logic;

        -- single write port
        we      : in  std_logic;
        wa      : in  csr_register;
        wd      : in  std_logic_vector((XLEN - 1) downto 0);

        -- two read ports
        ra1     : in  csr_register;
        rd1     : out std_logic_vector((XLEN - 1) downto 0);

        -- Interrupt specific IOs
        int_vec : in  std_logic_vector((XLEN - 1) downto 0);
        int_out : out std_logic
    );
end entity;

architecture rtl of csr_registers is

    -- Define write permissions for each register
    constant MSTATUS_W_MASK :   std_logic_vector((XLEN - 1) downto 0) := "00000000000000000111100010001000";
    constant MISA_W_MASK :      std_logic_vector((XLEN - 1) downto 0) := "00000000000000000000000000000000";
    constant MIE_W_MASK :       std_logic_vector((XLEN - 1) downto 0) := "11111111111111110000100010001000";
    constant MTVEC_W_MASK :     std_logic_vector((XLEN - 1) downto 0) := "11111111111111111111111100000001";
    constant MSCRATCH_W_MASK :  std_logic_vector((XLEN - 1) downto 0) := "11111111111111111111111111111111";
    constant MEPC_W_MASK :      std_logic_vector((XLEN - 1) downto 0) := "11111111111111111111111111111110";
    constant MCAUSE_W_MASK :    std_logic_vector((XLEN - 1) downto 0) := "10000000000000000000000000011111";
    constant MTVAL_W_MASK :     std_logic_vector((XLEN - 1) downto 0) := "00000000000000000000000000000000";
    constant MIP_W_MASK :       std_logic_vector((XLEN - 1) downto 0) := "00000000000000000000000000000000";    

    -- Since there's not a lot of registers, we define them manually.
    signal mstatus :            std_logic_vector((XLEN - 1) downto 0);
    signal misa :               std_logic_vector((XLEN - 1) downto 0);
    signal mie :                std_logic_vector((XLEN - 1) downto 0);
    signal mtvec :              std_logic_vector((XLEN - 1) downto 0);
    signal mscratch :           std_logic_vector((XLEN - 1) downto 0);
    signal mepc :               std_logic_vector((XLEN - 1) downto 0);
    signal mcause :             std_logic_vector((XLEN - 1) downto 0);
    signal mtval :              std_logic_vector((XLEN - 1) downto 0);
    signal mip :                std_logic_vector((XLEN - 1) downto 0);

    -- Defining logic mask function for easier updates
    function update_bits(
        write_in :      std_logic_vector((XLEN - 1) downto 0);
        write_mask :    std_logic_vector((XLEN - 1) downto 0);
        write_old :     std_logic_vector((XLEN - 1) downto 0))
        return std_logic_vector is
        begin
            return (write_in and write_mask) or (write_old and (not write_mask));
        end function;

begin

    -- synchronous write
    process(clock, nRST, int_vec)
    begin

        -- Handle reset 
        if nRST = '0' then

            mstatus     <= X"0000_1800";
            misa        <= X"4000_0100";
            mie         <= (others => '0');
            mtvec       <= (others => '0');
            mscratch    <= (others => '0');
            mepc        <= (others => '0');
            mcause      <= (others => '0');
            mtval       <= (others => '0');
            mip         <= (others => '0');

        -- Handle standard writes
        elsif rising_edge(clock) and (clock_en = '1') then

            -- Synchronizing the MIP register
            mip   <=  int_vec and mie; 

            if (we = '1') then

                case wa is
                    when r_MSTATUS =>
                        mstatus     <= update_bits(wd, MSTATUS_W_MASK,  mstatus);
                    -- when r_MISA =>
                    --     misa        <= update_bits(wd, MISA_W_MASK,     misa); -- Mask is 0
                    when r_MIE =>
                        mie         <= update_bits(wd, MIE_W_MASK,      mie);
                    when r_MTVEC =>
                        mtvec       <= update_bits(wd, MTVEC_W_MASK,    mtvec);
                    when r_MSCRATCH =>
                    --    mscratch    <= update_bits(wd, MSCRATCH_W_MASK, mscratch);
                        mscratch    <= wd;                                        -- Mask is FFFF_FFFF, so direct copy           
                    when r_MEPC =>
                        mepc        <= update_bits(wd, MEPC_W_MASK,     mepc);
                    when r_MCAUSE =>
                        mcause      <= update_bits(wd, MCAUSE_W_MASK,   mcause);
                    -- when r_MTVAL =>
                    --     mtval       <= update_bits(wd, MTVAL_W_MASK,    mtval); -- Mask is 0
                    -- when r_MIP    =>
                    --     mip         <= update_bits(wd, MIP_W_MASK,   mcause);  -- Mask is 0
                    when others =>
                        -- do nothing
                end case;
                     
            
            end if;
                
        end if;

    end process;
    
    -- asynchronous reads (combinational muxes)
    rd1 <=      mstatus     when (ra1 = r_MSTATUS)  else
                misa        when (ra1 = r_MISA)     else
                mie         when (ra1 = r_MIE)      else
                mtvec       when (ra1 = r_MTVEC)    else
                mscratch    when (ra1 = r_MSCRATCH) else
                mepc        when (ra1 = r_MEPC)     else
                mcause      when (ra1 = r_MCAUSE)   else
                mtval       when (ra1 = r_MTVAL)    else
                mip         when (ra1 = r_MIP)      else
                (others => '0');

    -- always read the MIP port.
    int_out <=  mip(11);

end architecture;