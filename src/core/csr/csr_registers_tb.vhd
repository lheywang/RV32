library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity csr_registers_tb is
end entity;

architecture behavioral of csr_registers_tb is

        signal clock_t :    std_logic                       := '0';
        signal clock_en_t : std_logic                       := '0';
        signal nRST_t :     std_logic                       := '0';
        signal we_t :       std_logic                       := '0';
        signal wa_t :       csr_register                    := r_MSTATUS;
        signal wd_t :       std_logic_vector(31 downto 0)   := (others => '1');
        signal ra1_t :      csr_register                    := r_MSTATUS;
        signal rd1_t :      std_logic_vector(31 downto 0)   := (others => '0');
        signal int_vec_t :  std_logic_vector(31 downto 0)   := (others => '0');
        signal int_out_t :  std_logic                       := '0';

    begin

        U1 : entity work.clock(behavioral)
            port map (
                clk         => clock_t,
                nRST        => nRST_t,
                clk_en      => clock_en_t
            );

        U2 : entity work.csr_registers(rtl)
            port map (
                clock       => clock_t,
                clock_en    => clock_en_t,
                nRST        => nRST_t,
                we          => we_t,
                wa          => wa_t,
                wd          => wd_t,
                ra1         => ra1_t,
                rd1         => rd1_t,
                int_vec     => int_vec_t,
                int_out     => int_out_t
            );

        -- clock
        P1 : process
        begin
            wait for 5 ns;
            clock_t <= not clock_t;
        end process;

        -- nRST
        P2 : process
        begin
            nRST_t  <= '0';
            wait for 15 ns;
            nRST_t  <= '1';
            wait;
        end process;

        -- Write data
        P3 : process
        begin
            wait for 15 ns;
            wait for 100 ns;
            wa_t    <= r_MSTATUS;
            we_t    <= '1';
            wait for 10 ns;
            wa_t    <= r_MISA;
            wait for 10 ns;
            wa_t    <= r_MIE;
            wait for 10 ns;
            wa_t    <= r_MTVEC;
            wait for 10 ns;
            wa_t    <= r_MSCRATCH;
            wait for 10 ns;
            wa_t    <= r_MEPC;
            wait for 10 ns;
            wa_t    <= r_MCAUSE;
            wait for 10 ns;
            wa_t    <= r_MTVAL;
            wait for 10 ns;
            wa_t    <= r_MIP;
            wait for 10 ns;
            we_t    <= '0';
            wd_t    <= X"0000_0000";
            wait for 100 ns;
        end process;
        
        -- Read data
        P4 : process
        begin
            wait for 10 ns;
            ra1_t   <= r_MSTATUS;
            wait for 10 ns;
            ra1_t   <= r_MISA;
            wait for 10 ns;
            ra1_t   <= r_MIE;
            wait for 10 ns;
            ra1_t   <= r_MTVEC;
            wait for 10 ns;
            ra1_t   <= r_MSCRATCH;
            wait for 10 ns;
            ra1_t   <= r_MEPC;
            wait for 10 ns;
            ra1_t   <= r_MCAUSE;
            wait for 10 ns;
            ra1_t   <= r_MTVAL;
            wait for 10 ns;
            ra1_t   <= r_MIP;
            wait for 10 ns;
        end process;

        -- Emulate interrupt
        P5 : process
        begin
            wait for 15 ns;
            wait for 100 ns;
            wait for 18 ns;
            int_vec_t <= X"FFFF_FFFF";
            wait;
        end process;

    end architecture;