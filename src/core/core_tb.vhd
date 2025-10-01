library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity core_tb is 
end entity;

architecture behavioral of core_tb is

        signal clk_t :                  std_logic                       := '0';
        signal nRST_t :                 std_logic                       := '0';
        signal RST_t :                  std_logic                       := '0';
        signal halt_t :                 std_logic                       := '0';
        signal exception_t :            std_logic                       := '0';
        signal if_addr_t :              std_logic_vector(31 downto 0)   := (others => '0');
        signal if_rdata_t :             std_logic_vector(31 downto 0)   := (others => '0');
        signal if_err_t :               std_logic                       := '0';
        signal mem_addr_t :             std_logic_vector(31 downto 0)   := (others => '0');
        signal mem_we_t :               std_logic                       := '0';
        signal mem_req_t :              std_logic                       := '0';
        signal mem_wdata_t :            std_logic_vector(31 downto 0)   := (others => '0');
        signal mem_byten_t :            std_logic_vector(3 downto 0)    := (others => '0');
        signal mem_rdata_t :            std_logic_vector(31 downto 0)   := (others => '0');
        signal mem_err_t :              std_logic                       := '0';
        signal core_halt_t :            std_logic                       := '0';
        signal core_trap_t :            std_logic                       := '0';
        signal if_aclr_t :              std_logic                       := '0';
        signal int_vec_t :              std_logic_vector(31 downto 0)   := (others => '0');

    begin

        RST_t <= (not nRST_t) or if_aclr_t;


        CORE : entity work.core(behavioral)
            generic map ( 
                XLEN                =>  32,
                REG_NB              =>  32,
                INPUT_FREQ          =>  200_000_000,
                RESET_ADDR          =>  0,
                INT_ADDR            =>  0,
                ERR_ADDR            =>  0
            )
            port map (
                clk                 =>  clk_t,
                nRST                =>  nRST_t,
                halt                =>  halt_t,
                exception           =>  exception_t,
                if_addr             =>  if_addr_t,
                if_rdata            =>  if_rdata_t,
                if_err              =>  if_err_t,
                if_aclr             =>  if_aclr_t,
                mem_addr            =>  mem_addr_t,
                mem_we              =>  mem_we_t,
                mem_req             =>  mem_req_t,
                mem_wdata           =>  mem_wdata_t,
                mem_byten           =>  mem_byten_t,
                mem_rdata           =>  mem_rdata_t,
                mem_err             =>  mem_err_t,
                core_halt           =>  core_halt_t,
                core_trap           =>  core_trap_t,
                int_vec             =>  int_vec_t
            );

        -- The two memory elements depends on the altera_mf library, which, if not available WILL cause compilation issues.
        -- Ensure you have them, or, try to make without.
        RAM : entity work.ram(SYN)
            port map 
            (
                aclr                =>  RST_t,
                address             =>  mem_addr_t(14 downto 2), -- To correct : write a memory address translator that match the different addres spaces. 
                byteena             =>  mem_byten_t,
                clock               =>  clk_t,
                data                =>  mem_wdata_t,
                wren                =>  mem_we_t,
                q                   =>  mem_rdata_t
            );

        ROM : entity work.rom(SYN)
            port map 
            (
                aclr                =>  RST_t,                    -- Never reset the ROM. Since RAM based, we don't want to clear it.
                address_a           =>  if_addr_t(15 downto 2),
                address_b           =>  mem_addr_t(15 downto 2),-- To correct : write a memory address translator that match the different addres spaces.
                clock               =>  clk_t,
                q_a                 =>  if_rdata_t,
                q_b                 =>  mem_rdata_t
            );

        -- Stimulus
        -- Clocks
        P1 : process
        begin
            wait for 5 ns;
            clk_t <= not clk_t;
        end process;

        -- reset handler
        P2 : process
        begin
            nRST_t <= '0';
            wait for 8 ns;
            nRST_t <= '1';
            wait;
        end process;
        
        -- Interrupt emulation (command / uncomment if neded)
        P3 : process
        begin
            wait for 228 ns;
            -- int_vec_t(11) <= '1';
            wait;
        end process;

    end architecture;