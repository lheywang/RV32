# --- Variables ---
TOP        ?= pcounter
SRC_DIR    = src
BUILD_DIR  = obj_dir
CXX_TB     = testbench/tb_$(TOP).cpp
CCX_UTILS  = testbench/utils/utils.cpp

# Including all SV packages files 
VERILOG_SRCS = $(SRC_DIR)/packages/core_config_pkg.sv 

# Including ALU files
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
VERILOG_SRCS += $(SRC_DIR)/core/core.sv

# Including all peripherals files
VERILOG_SRCS += $(SRC_DIR)/peripherals/argb.sv
VERILOG_SRCS += $(SRC_DIR)/peripherals/gpio.sv
VERILOG_SRCS += $(SRC_DIR)/peripherals/interrupt.sv
VERILOG_SRCS += $(SRC_DIR)/peripherals/keys.sv
VERILOG_SRCS += $(SRC_DIR)/peripherals/serial.sv
VERILOG_SRCS += $(SRC_DIR)/peripherals/timer.sv
VERILOG_SRCS += $(SRC_DIR)/peripherals/ulpi.sv

# Including memory files

# Including top file 
VERILOG_SRCS += $(SRC_DIR)/rv32.sv

NPROC = $(shell nproc)


# --- Verilator options ---
VERILATOR_FLAGS = -Wall --trace -j $(NPROC) --cc $(VERILOG_SRCS) --top-module $(TOP) --exe $(CXX_TB) $(CCX_UTILS)

# --- Default target ---
all: run

# Build and run simulation
run: $(BUILD_DIR)/V$(TOP)
	@echo "Running simulation..."
	@./$(BUILD_DIR)/V$(TOP)

# Compile generated C++ from Verilator
$(BUILD_DIR)/V$(TOP): $(VERILOG_SRCS) $(CXX_TB)
	verilator $(VERILATOR_FLAGS)
	make -C $(BUILD_DIR) -f V$(TOP).mk V$(TOP)

# Clean
clean:
	rm -rf $(BUILD_DIR) *.vcd
	rm -rf simout/*.vcd
	rm -rf logs/*.ans
	rm -rf logs/*.log
	rm -rf documentation/html
	rm -rf documentation/latex

tests:
	./tests.sh

doc: FORCE
	doxygen DoxyFile && cd documentation/latex && make pdf

FORCE: ;

.PHONY: all run clean tests doc
