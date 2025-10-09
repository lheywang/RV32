# --- Variables ---
TOP        ?= pcounter
SRC_DIR    = src
BUILD_DIR  = obj_dir
CXX_TB     = testbench/tb_$(TOP).cpp

# Including all SV packages files 
VERILOG_SRCS = $(SRC_DIR)/packages/core_config_pkg.sv 

# Including all core files
VERILOG_SRCS += $(SRC_DIR)/core/pcounter.sv
VERILOG_SRCS += $(SRC_DIR)/core/clock.sv
VERILOG_SRCS += $(SRC_DIR)/core/alu.sv
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
VERILATOR_FLAGS = -Wall --trace -j $(NPROC) --cc $(VERILOG_SRCS) --exe $(CXX_TB) --top-module $(TOP)

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

.PHONY: all run clean
