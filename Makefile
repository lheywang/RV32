# =======================================================
# Variables
# =======================================================
TOP        ?= pcounter
SRC_DIR    = src
BUILD_DIR  = /mnt/ramdisk/
CXX_TB     = $(abspath testbench/tb_$(TOP).cpp)
CCX_UTILS  = $(abspath testbench/utils/utils.cpp)

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

# Including top file 
VERILOG_SRCS += $(SRC_DIR)/rv32.sv


# =======================================================
# Parameters and public recipes
# =======================================================
NPROC = $(shell nproc)
export CXX="ccache clang++"

# --- Verilator options ---
VERILATOR_FLAGS = -Wall \
				  --trace \
				  -j 8 \
				  --cc $(VERILOG_SRCS) \
				  -O3 \
				  --output-split 0 \
				  --top-module $(TOP) \
				  --exe $(CXX_TB) $(CCX_UTILS) \
				  -Mdir $(BUILD_DIR) \
				  -I$(BUILD_DIR)

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
$(BUILD_DIR)/V$(TOP): $(VERILOG_SRCS) $(CXX_TB) $(CXX_HEADERS) $(SYSTEMVERILOG_HEADERS)
	verilator $(VERILATOR_FLAGS)
	make -C $(BUILD_DIR) -f V$(TOP).mk V$(TOP) -j8 CXX="ccache clang++"

# Clean
clean:
	rm -rf $(BUILD_DIR)*
	rm -rf simout/*.vcd
	rm -rf logs/*.ans
	rm -rf logs/*.log
	rm -rf documentation/html
	rm -rf documentation/latex

tests:
	@./utils/tests.sh

mount:
	@mkdir -p /mnt/ramdisk
	@mkdir -p build/
	@./utils/ramdisk.sh 
	@ln -s /mnt/ramdisk/ build/

doc: FORCE
	doxygen DoxyFile && cd documentation/latex && make pdf

FORCE: ;

.PHONY: all run clean tests doc


# =======================================================
# Private recipes
# =======================================================

# Opcodes
$(BUILD_DIR)/generated_opcodes.svh $(BUILD_DIR)/generated_opcodes.h : src/packages/def/opcodes.def
	@echo "Generating opcodes enums ..."
	./utils/def2header.py -s $(BUILD_DIR)generated_opcodes.svh -c $(BUILD_DIR)generated_opcodes.h $< 

# Decoders
$(BUILD_DIR)/generated_decoders.svh $(BUILD_DIR)/generated_decoders.h : src/packages/def/decoders.def
	@echo "Generating decoders enums ..."
	./utils/def2header.py -s $(BUILD_DIR)generated_decoders.svh -c $(BUILD_DIR)generated_decoders.h $<

# CSRs
$(BUILD_DIR)/generated_csr.svh $(BUILD_DIR)/generated_csr.h : src/packages/def/csr.def
	@echo "Generating CSR enums ..."
	./utils/def2header.py -s $(BUILD_DIR)generated_csr.svh -c $(BUILD_DIR)generated_csr.h $<

# Commands
$(BUILD_DIR)/generated_commands.svh $(BUILD_DIR)/generated_commands.h : src/packages/def/commands.def
	@echo "Generating commands ..."
	./utils/def2header.py -s $(BUILD_DIR)generated_commands.svh -c $(BUILD_DIR)generated_commands.h $<
