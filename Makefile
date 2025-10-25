# =======================================================
# Variables
# =======================================================
TOP        ?= pcounter
SRC_DIR    = rtl
BUILD_DIR  = build/
TB_DIR 	   = testbench/
SIMOUT     = simout/
TB_UTILS   = $(abspath $(TB_DIR)/include )
CXX_TB 	   := $(shell find $(abspath $(TB_DIR)/src) -type f -iname "tb_$(TOP).cpp" | head -n 1)
CCX_UTILS  = $(wildcard $(TB_DIR)/src/utils/*.cpp)

# Including all SV packages files 
VERILOG_SRCS = $(SRC_DIR)/packages/core_config_pkg.sv 

# Including ALU files
VERILOG_SRCS += $(SRC_DIR)/core/alu/operations/booth.sv
VERILOG_SRCS += $(SRC_DIR)/core/alu/operations/srt.sv
VERILOG_SRCS += $(SRC_DIR)/core/alu/operations/shift.sv
VERILOG_SRCS += $(SRC_DIR)/core/alu/alu0.sv
VERILOG_SRCS += $(SRC_DIR)/core/alu/alu1.sv
VERILOG_SRCS += $(SRC_DIR)/core/alu/alu2.sv
VERILOG_SRCS += $(SRC_DIR)/core/alu/alu4.sv
VERILOG_SRCS += $(SRC_DIR)/core/alu/alu5.sv

# Including all core files
VERILOG_SRCS += $(SRC_DIR)/core/pcounter.sv
VERILOG_SRCS += $(SRC_DIR)/core/counter.sv
VERILOG_SRCS += $(SRC_DIR)/core/clock.sv
VERILOG_SRCS += $(SRC_DIR)/core/csr.sv
VERILOG_SRCS += $(SRC_DIR)/core/decoder.sv
VERILOG_SRCS += $(SRC_DIR)/core/endianess.sv
VERILOG_SRCS += $(SRC_DIR)/core/registers.sv
VERILOG_SRCS += $(SRC_DIR)/core/occupancy.sv
VERILOG_SRCS += $(SRC_DIR)/core/issuer.sv
VERILOG_SRCS += $(SRC_DIR)/core/commiter.sv
VERILOG_SRCS += $(SRC_DIR)/core/prediction.sv
VERILOG_SRCS += $(SRC_DIR)/core/core.sv

# Including all peripherals files
VERILOG_SRCS += $(SRC_DIR)/peripherals/argb.sv
VERILOG_SRCS += $(SRC_DIR)/peripherals/gpio.sv
VERILOG_SRCS += $(SRC_DIR)/peripherals/interrupt.sv
VERILOG_SRCS += $(SRC_DIR)/peripherals/keys.sv
VERILOG_SRCS += $(SRC_DIR)/peripherals/serial.sv
VERILOG_SRCS += $(SRC_DIR)/peripherals/timer.sv
VERILOG_SRCS += $(SRC_DIR)/peripherals/ulpi.sv

# Top files
VERILOG_SRCS += $(SRC_DIR)/reset.sv
VERILOG_SRCS += $(SRC_DIR)/rv32.sv

# Including memory files


# =======================================================
# Parameters and public recipes
# =======================================================
NPROC = $(shell nproc)

# --- Verilator options ---
VERILATOR_FLAGS = -Wall \
				  --trace \
				  -j 8 \
				  --cc $(VERILOG_SRCS) \
				  -O3 \
				  --top-module $(TOP) \
				  --exe $(CXX_TB) $(CCX_UTILS) \
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
$(BUILD_DIR)/V$(TOP): $(BUILD_DIR) $(VERILOG_SRCS) $(CXX_TB) $(CXX_HEADERS) $(SYSTEMVERILOG_HEADERS) 
	verilator $(VERILATOR_FLAGS)
	make -C $(BUILD_DIR) -f V$(TOP).mk V$(TOP) -j8 CXX="ccache g++"

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
	python utils/tests.py

doc: FORCE
	doxygen DoxyFile && cd documentation/latex && make pdf

FORCE: ;

wave: run
	gtkwave $(SIMOUT)$(TOP).vcd

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
