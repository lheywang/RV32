# --- Variables ---
TOP        ?= pcounter
SRC_DIR    = src
BUILD_DIR  = obj_dir
CXX_TB     = testbench/tb_$(TOP).cpp
VERILOG_SRCS = $(SRC_DIR)/packages/core_config_pkg.sv $(SRC_DIR)/core/pcounter/$(TOP).sv

# --- Verilator options ---
VERILATOR_FLAGS = -Wall --trace -j 16 --cc $(VERILOG_SRCS) --exe $(CXX_TB) --top-module $(TOP)

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
