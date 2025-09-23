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
        signal irq_t :                  std_logic                       := '0';
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

    begin

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
                irq                 =>  irq_t,
                halt                =>  halt_t,
                exception           =>  exception_t,
                if_addr             =>  if_addr_t,
                if_rdata            =>  if_rdata_t,
                if_err              =>  if_err_t,
                mem_addr            =>  mem_addr_t,
                mem_we              =>  mem_we_t,
                mem_req             =>  mem_req_t,
                mem_wdata           =>  mem_wdata_t,
                mem_byten           =>  mem_byten_t,
                mem_rdata           =>  mem_rdata_t,
                mem_err             =>  mem_err_t,
                core_halt           =>  core_halt_t,
                core_trap           =>  core_trap_t
            );

        ROM : entity altera_mf.altsyncram(SYN)
            generic map (
                address_reg_b => "CLOCK0",
                clock_enable_input_a => "BYPASS",
                clock_enable_input_b => "BYPASS",
                clock_enable_output_a => "BYPASS",
                clock_enable_output_b => "BYPASS",
                indata_reg_b => "CLOCK0",
                init_file => "./IP/ROM/mem.hex",
                intended_device_family => "MAX 10",
                lpm_type => "altsyncram",
                numwords_a => 12288,
                numwords_b => 12288,
                operation_mode => "BIDIR_DUAL_PORT",
                outdata_aclr_a => "CLEAR0",
                outdata_aclr_b => "CLEAR0",
                outdata_reg_a => "CLOCK0",
                outdata_reg_b => "CLOCK0",
                power_up_uninitialized => "FALSE",
                widthad_a => 14,
                widthad_b => 14,
                width_a => 32,
                width_b => 32,
                width_byteena_a => 1,
                width_byteena_b => 1,
                wrcontrol_wraddress_reg_b => "CLOCK0"
            )
            port map (
                aclr0 => aclr,
                address_a => address_a,
                address_b => address_b,
                clock0 => clock,
                data_a => sub_wire0,
                data_b => sub_wire0,
                wren_a => sub_wire1,
                wren_b => sub_wire1,
                q_a => sub_wire2,
                q_b => sub_wire3
            );

        RAM : entity altera_mf.altsyncram(SYN)
            generic map (
                byte_size => 8,
                clock_enable_input_a => "BYPASS",
                clock_enable_output_a => "BYPASS",
                intended_device_family => "MAX 10",
                lpm_hint => "ENABLE_RUNTIME_MOD=NO",
                lpm_type => "altsyncram",
                numwords_a => 6144,
                operation_mode => "SINGLE_PORT",
                outdata_aclr_a => "CLEAR0",
                outdata_reg_a => "CLOCK0",
                power_up_uninitialized => "FALSE",
                read_during_write_mode_port_a => "DONT_CARE",
                widthad_a => 13,
                width_a => 32,
                width_byteena_a => 4
            )
            port map (
                aclr0 => aclr,
                address_a => address,
                byteena_a => byteena,
                clock0 => clock,
                data_a => data,
                wren_a => wren,
                q_a => sub_wire0
            );

        -- Stimulus
        -- Clocks
        P1 : process
        begin
            wait for 5 ns;
            clk_t <= not clk_t;
        end process;

        P2 : process
        begin
            nRST_t <= '0';
            wait for 8 ns;
            nRST_t <= '1';
            wait;
        end process;

    end architecture;