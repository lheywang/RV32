# =======================================================
# Variables
# =======================================================
TOP        ?= pcounter
SRC_DIR    = rtl/
BUILD_DIR  = build/
TB_DIR 	   = testbench/
SIMOUT     = simout/
UTILS 	   = utils/

TB_UTILS   = $(abspath $(TB_DIR)/include )
TB_TOP 	   := $(shell find $(abspath $(TB_DIR)src) -type f -iname "tb_$(TOP).cpp" | head -n 1)
TB_SRC     := $(shell find $(TB_DIR)src -type f -name "*.cpp")
PY_SRC     := $(shell find $(UTILS) -type f -name "*.py")

# We need to use different commands to ensure the right order is outputed...
RTL_SRC    := $(shell find $(SRC_DIR)packages -type f -name "*.sv")
RTL_SRC    += $(shell find $(SRC_DIR)memory -type f -name "*.v")
RTL_SRC    += $(shell find $(SRC_DIR)core -type f -name "*.sv")
RTL_SRC    += $(shell find $(SRC_DIR)peripherals -type f -name "*.sv")
RTL_SRC    += $(SRC_DIR)reset.sv
RTL_SRC    += $(SRC_DIR)rv32.sv

VERILATOR_CFG = verilatorcfg.vlt

# =======================================================
# Parameters and public recipes
# =======================================================
NPROC ?= $(shell nproc)

FILE_LIST = $(BUILD_DIR)sources.f

# --- Verilator options ---
VERILATOR_FLAGS = -Wall \
				  --trace \
				  -j $(NPROC) \
				  --cc -f $(FILE_LIST) $(VERILATOR_CFG) \
				  -O3 \
				  --top-module $(TOP) \
				  --exe $(TB_TOP) $(CCX_UTILS) \
				  -Mdir $(BUILD_DIR) \
				  -I$(BUILD_DIR) \
				  -CFLAGS "-I$(TB_UTILS)"

SYSTEMVERILOG_HEADERS = $(BUILD_DIR)/generated_opcodes.svh \
						$(BUILD_DIR)/generated_decoders.svh \
						$(BUILD_DIR)/generated_csr.svh \
						$(BUILD_DIR)/generated_commands.svh

CXX_HEADERS = $(BUILD_DIR)/generated_opcodes.h \
			  $(BUILD_DIR)/generated_decoders.h \
			  $(BUILD_DIR)/generated_csr.h \
			  $(BUILD_DIR)/generated_commands.h

# --- Default target ---
all: run

# Build and run simulation
run: $(BUILD_DIR)/V$(TOP)
	@echo "Running simulation..."
	@$(BUILD_DIR)V$(TOP)

# Compile generated C++ from Verilator
$(BUILD_DIR)/V$(TOP): prepare $(RTL_SRC) $(CXX_TB)  $(TB_TOP)
	verilator $(VERILATOR_FLAGS)
	make -C $(BUILD_DIR) -f V$(TOP).mk V$(TOP) -j8 CXX="ccache g++"

# List the files used for verilator.
$(FILE_LIST) :
	echo "$(RTL_SRC)" | tr ' ' '\n' >> $@

# Clean
clean:
	rm -rf $(BUILD_DIR)*
	rm -rf $(SIMOUT)*.vcd
	rm -rf logs/*.ans
	rm -rf logs/reports/*.md
	rm -rf logs/reports/*.stat
	rm -rf logs/*.log
	rm -rf documentation/html
	rm -rf documentation/latex

tests:
	@python utils/tests.py

wave: run
	@gtkwave $(SIMOUT)$(TOP).vcd

format:
	@verible-verilog-format --inplace --flagfile=.verible-format $(RTL_SRC)
	@clang-format -i --style=file $(TB_SRC)
	@black --line-length 100 $(PY_SRC)

prepare : $(BUILD_DIR) $(SYSTEMVERILOG_HEADERS) $(FILE_LIST)

.PHONY: all run clean tests doc


# =======================================================
# Private recipes
# =======================================================

# Opcodes
$(BUILD_DIR)/generated_opcodes.svh $(BUILD_DIR)/generated_opcodes.h : $(SRC_DIR)/packages/def/opcodes.def
	@echo "Generating opcodes enums ..."
	./utils/def2header.py -s $(BUILD_DIR)generated_opcodes.svh -c $(BUILD_DIR)generated_opcodes.h $< 

# Decoders
$(BUILD_DIR)/generated_decoders.svh $(BUILD_DIR)/generated_decoders.h : $(SRC_DIR)/packages/def/decoders.def
	@echo "Generating decoders enums ..."
	./utils/def2header.py -s $(BUILD_DIR)generated_decoders.svh -c $(BUILD_DIR)generated_decoders.h $<

# CSRs
$(BUILD_DIR)/generated_csr.svh $(BUILD_DIR)/generated_csr.h : $(SRC_DIR)/packages/def/csr.def
	@echo "Generating CSR enums ..."
	./utils/def2header.py -s $(BUILD_DIR)generated_csr.svh -c $(BUILD_DIR)generated_csr.h $<

# Commands
$(BUILD_DIR)/generated_commands.svh $(BUILD_DIR)/generated_commands.h : $(SRC_DIR)/packages/def/commands.def
	@echo "Generating commands ..."
	./utils/def2header.py -s $(BUILD_DIR)generated_commands.svh -c $(BUILD_DIR)generated_commands.h $<

# Build dir
$(BUILD_DIR) : 
	@mkdir $(BUILD_DIR)
