# =========================================================================================================
# Files paths
# =========================================================================================================
# --- User passed parameters ---
TOP        	?= pcounter
TEST        ?= test1

# --- Folders definitions ---
SRC_DIR    	= rtl/
BUILD_DIR  	= build/
CONFIG_DIR 	= configs/
TB_DIR 	   	= testbench/
SIMOUT     	= simout/
UTILS 	   	= utils/
TESTS       = tests/

# --- Files definitions ---
TESTER_SRC  = $(TB_DIR)src/tests/tester.cpp
TESTER_TOP  = rv32


# =========================================================================================================
# Tools
# =========================================================================================================
RV32_CC     = riscv64-unknown-elf-gcc
RV32_OBJ    = riscv64-unknown-elf-objcopy

# =========================================================================================================
# Sources
# =========================================================================================================
TB_UTILS  	 = $(abspath $(TB_DIR)/include )
TB_TOP 	   	:= $(shell find $(abspath $(TB_DIR)src) -type f -iname "tb_$(TOP).cpp" | head -n 1)
TB_SRC     	:= $(shell find $(TB_DIR)src -type f -name "*.cpp")
PY_SRC     	:= $(shell find $(UTILS) -type f -name "*.py")

# We need to use different commands to ensure the right order is outputed...
RTL_SRC    	 = $(shell find $(SRC_DIR)core -type f -name "*.sv")
RTL_SRC    	+= $(shell find $(SRC_DIR)peripherals -type f -name "*.sv")
RTL_SRC    	+= $(SRC_DIR)rv32.sv

MEM_SRC    	+= $(shell find $(SRC_DIR)memory -type f -name "*.v")
PLL_SRC    	+= $(shell find $(SRC_DIR)clocks -type f -name "*.v")

VERILATOR_CFG = verilatorcfg.vlt

# =========================================================================================================
# Parameters
# =========================================================================================================
NPROC ?= $(shell nproc)

FILE_LIST = $(BUILD_DIR)sources.f

# --- Verilator options ---
VERILATOR_FLAGS = -Wall \
				  --trace \
				  -j $(NPROC) \
				  --cc $(VERILATOR_CFG) -f $(FILE_LIST) \
				  -O3 \
				  --top-module $(TOP) \
				  --exe $(TB_TOP) $(CCX_UTILS) \
				  -Mdir $(BUILD_DIR) \
				  -I$(BUILD_DIR) \
				  -CFLAGS "-I$(TB_UTILS)"

# --- Verilator options ---
VERILATOR_FLAGS_RUN = -Wall \
				      --trace \
				      -j $(NPROC) \
				      --cc $(VERILATOR_CFG) -f $(FILE_LIST) \
				      -O3 \
				      --top-module $(TESTER_TOP) \
				      --exe $(abspath $(TESTER_SRC)) $(CCX_UTILS) \
				      -Mdir $(BUILD_DIR) \
				      -I$(BUILD_DIR) \
				      -CFLAGS "-I$(TB_UTILS)"

# --- Files paths ---
NEEDED_CONFIS = $(BUILD_DIR)core_config_pkg.svh \
				$(BUILD_DIR)argb_config_pkg.svh \
				$(BUILD_DIR)gpio_config_pkg.svh \
				$(BUILD_DIR)interrupts_config_pkg.svh \
				$(BUILD_DIR)keys_config_pkg.svh \
				$(BUILD_DIR)serial_config_pkg.svh \
				$(BUILD_DIR)timer_config_pkg.svh \
				$(BUILD_DIR)ulpi_config_pkg.svh

NEEDED_ENUMS  = $(BUILD_DIR)generated_opcodes.svh \
				$(BUILD_DIR)generated_decoders.svh \
				$(BUILD_DIR)generated_csr.svh \
				$(BUILD_DIR)generated_commands.svh

# --- Outputs ---
INIT_ROM 	  = $(BUILD_DIR)rom.mif
INIT_RAM      = $(BUILD_DIR)ram.mif

# --- Paths ---
TEST_BUILD := $(BUILD_DIR)/$(TEST)
TEST_SRC  := $(TESTS)/$(TEST)


# =========================================================================================================
# Recipes
# =========================================================================================================
.PHONY: all run clean tests doc

# --- Default target ---
all: run

# Clean
clean:
	@rm -rf $(BUILD_DIR)*
	@rm -rf $(SIMOUT)*.vcd
	@rm -rf logs/*.ans
	@rm -rf logs/reports/*.md
	@rm -rf logs/reports/*.stat
	@rm -rf logs/*.log
	@rm -rf documentation/html
	@rm -rf documentation/latex
	@rm -rf obj_dir/*

# Build and run simulation
run: $(BUILD_DIR)/V$(TOP)
	@echo "Running simulation..."
	@$(BUILD_DIR)V$(TOP)

# Compile generated C++ from Verilator
$(BUILD_DIR)/V$(TOP): $(FILE_LIST) $(RTL_SRC) $(CXX_TB)  $(TB_TOP)
	verilator $(VERILATOR_FLAGS)
	@make -C $(BUILD_DIR) -f V$(TOP).mk V$(TOP) -j$(NPROC) CXX="ccache g++"

wave: run
	@gtkwave $(SIMOUT)$(TOP).vcd

# Format source files for the project
format:
	@verible-verilog-format --inplace --flagfile=.verible-format $(RTL_SRC)
	@clang-format -i --style=file $(TB_SRC)
	@black --line-length 100 $(PY_SRC)

# Prepare files for any simulations
prepare : $(BUILD_DIR) $(NEEDED_ENUMS) $(BUILD_DIR)generated.h

# Prepare files for a program run
test_case: $(FILE_LIST) $(TEST_BUILD) $(INIT_RAM) $(INIT_ROM)
	verilator $(VERILATOR_FLAGS_RUN)
	@make -C $(BUILD_DIR) -f V$(TESTER_TOP).mk V$(TESTER_TOP) -j$(NPROC) CXX="ccache g++"

# Run the unit-tests
tests:
	@./utils/tests.py

# Run the simulation by hand
run_case: test_case
	@$(BUILD_DIR)V$(TESTER_TOP)


# =========================================================================================================
# Autogenerated files : 
# =========================================================================================================
$(BUILD_DIR)generated.h $(BUILD_DIR)generated.sv : $(NEEDED_ENUMS) $(NEEDED_CONFIS)

# =========================================================================================================
# Configuration files : 
# =========================================================================================================

$(BUILD_DIR)core_config_pkg.svh :
	@./utils/conf2header.py configs/core/ --output $(BUILD_DIR)
$(BUILD_DIR)argb_config_pkg.svh :
	@./utils/conf2header.py configs/peripherals/argb/ --output $(BUILD_DIR)
$(BUILD_DIR)gpio_config_pkg.svh :
	@./utils/conf2header.py configs/peripherals/gpio/ --output $(BUILD_DIR)
$(BUILD_DIR)interrupts_config_pkg.svh : 
	@./utils/conf2header.py configs/peripherals/interrupts/ --output $(BUILD_DIR)
$(BUILD_DIR)keys_config_pkg.svh :
	@./utils/conf2header.py configs/peripherals/keys/ --output $(BUILD_DIR)
$(BUILD_DIR)serial_config_pkg.svh : 
	@./utils/conf2header.py configs/peripherals/serial/ --output $(BUILD_DIR)
$(BUILD_DIR)timer_config_pkg.svh :
	@./utils/conf2header.py configs/peripherals/timer/ --output $(BUILD_DIR)
$(BUILD_DIR)ulpi_config_pkg.svh :
	@./utils/conf2header.py configs/peripherals/ulpi/ --output $(BUILD_DIR)

# =========================================================================================================
# Enums creations
# =========================================================================================================

# Opcodes
$(BUILD_DIR)generated_opcodes.svh : $(CONFIG_DIR)def/opcodes.def
	@./utils/def2header.py -s $(BUILD_DIR)generated_opcodes.svh -c $(BUILD_DIR)generated_opcodes.h $< 

# Decoders
$(BUILD_DIR)generated_decoders.svh : $(CONFIG_DIR)def/decoders.def
	@./utils/def2header.py -s $(BUILD_DIR)generated_decoders.svh -c $(BUILD_DIR)generated_decoders.h $<

# CSRs
$(BUILD_DIR)generated_csr.svh : $(CONFIG_DIR)def/csr.def
	@./utils/def2header.py -s $(BUILD_DIR)generated_csr.svh -c $(BUILD_DIR)generated_csr.h $<

# Commands
$(BUILD_DIR)generated_commands.svh : $(CONFIG_DIR)def/commands.def
	@./utils/def2header.py -s $(BUILD_DIR)generated_commands.svh -c $(BUILD_DIR)generated_commands.h $<

# =========================================================================================================
# Folders
# =========================================================================================================

# Build dir
$(BUILD_DIR) : 
	@mkdir $(BUILD_DIR)

# List the files used for verilator.
$(FILE_LIST) : prepare
	@echo "$(MEM_SRC)" | tr ' ' '\n' > $@
	@echo "$(PLL_SRC)" | tr ' ' '\n' >> $@
	@echo "$(shell find $(BUILD_DIR) -type f -name "*.sv")" | tr ' ' '\n' >> $@
	@echo "$(RTL_SRC)" | tr ' ' '\n' >> $@

# =========================================================================================================
# Tests folders
# =========================================================================================================

$(TEST_BUILD): $(BUILD_DIR)
	@rm -rf $(TEST_BUILD)
	@cp -r $(TEST_SRC) $(TEST_BUILD)
	@cd $(TEST_BUILD) && $(MAKE) all

# =========================================================================================================
# MIF files
# =========================================================================================================

$(INIT_RAM): $(TEST_BUILD)
	@echo "WIDTH = 32;"          >> $@
	@echo "DEPTH = 512;"         >  $@

	@echo "ADDRESS_RADIX = HEX;" >> $@
	@echo "DATA_RADIX = HEX;"    >> $@

	@echo "CONTENT BEGIN"        >> $@
	@for i in $$(seq 0 511); do printf "    %04X : %08X;\n" $$i 0 >> $@; done
	@echo "END;" >> $@

$(INIT_ROM): $(TEST_BUILD)
	./utils/bin2mif.py $(TEST_BUILD)/program.elf $@ --width=32 --depth=1024

