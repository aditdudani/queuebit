# Makefile for QueueBit Verification
# Supports both iverilog and Xilinx xsim simulators

# Directories
RTL_DIR = rtl
TB_DIR = tb
BUILD_DIR = build
IVERILOG_DIR = $(BUILD_DIR)/iverilog
XSIM_DIR = $(BUILD_DIR)/xsim

# Xilinx tools
XVLOG = "C:/Xilinx/2025.1/Vivado/bin/xvlog.bat"
XELAB = "C:/Xilinx/2025.1/Vivado/bin/xelab.bat"
XSIM = "C:/Xilinx/2025.1/Vivado/bin/xsim.bat"

# Source files
PKG_SRC = $(RTL_DIR)/dispatcher_pkg.sv
FIFO_SRC = $(RTL_DIR)/syndrome_fifo.sv
MATRIX_SRC = $(RTL_DIR)/tracking_matrix.sv
FIFO_TB = $(TB_DIR)/tb_syndrome_fifo.sv
MATRIX_TB = $(TB_DIR)/tb_tracking_matrix.sv

# Default target
.PHONY: all
all: test

# Run all tests with iverilog (default)
.PHONY: test
test: iverilog-fifo iverilog-matrix

# Run all tests with xsim
.PHONY: test-xsim
test-xsim: xsim-fifo xsim-matrix

# Run all tests with both simulators
.PHONY: test-all
test-all: test test-xsim

#==============================================================================
# iverilog targets
#==============================================================================

.PHONY: iverilog-fifo
iverilog-fifo: $(IVERILOG_DIR)/tb_fifo.vvp
	@echo "Running FIFO testbench with iverilog..."
	@cd $(IVERILOG_DIR) && vvp tb_fifo.vvp

.PHONY: iverilog-matrix
iverilog-matrix: $(IVERILOG_DIR)/tb_matrix.vvp
	@echo "Running Tracking Matrix testbench with iverilog..."
	@cd $(IVERILOG_DIR) && vvp tb_matrix.vvp

$(IVERILOG_DIR)/tb_fifo.vvp: $(PKG_SRC) $(FIFO_SRC) $(FIFO_TB)
	@mkdir -p $(IVERILOG_DIR)
	@echo "Compiling FIFO with iverilog..."
	@iverilog -g2012 -o $@ $(PKG_SRC) $(FIFO_SRC) $(FIFO_TB)

$(IVERILOG_DIR)/tb_matrix.vvp: $(PKG_SRC) $(MATRIX_SRC) $(MATRIX_TB)
	@mkdir -p $(IVERILOG_DIR)
	@echo "Compiling Tracking Matrix with iverilog..."
	@iverilog -g2012 -o $@ $(PKG_SRC) $(MATRIX_SRC) $(MATRIX_TB)

#==============================================================================
# xsim targets
#==============================================================================

.PHONY: xsim-fifo
xsim-fifo:
	@mkdir -p $(XSIM_DIR)
	@echo "Compiling FIFO with xsim..."
	@cd $(XSIM_DIR) && $(XVLOG) -sv ../../$(PKG_SRC) ../../$(FIFO_SRC) ../../$(FIFO_TB) > xvlog_fifo.log 2>&1
	@cd $(XSIM_DIR) && $(XELAB) -debug typical tb_syndrome_fifo -s fifo_sim > xelab_fifo.log 2>&1
	@echo "Running FIFO testbench with xsim..."
	@cd $(XSIM_DIR) && $(XSIM) fifo_sim -runall > xsim_fifo.log 2>&1
	@cd $(XSIM_DIR) && grep "Results:" xsim_fifo.log

.PHONY: xsim-matrix
xsim-matrix:
	@mkdir -p $(XSIM_DIR)
	@echo "Compiling Tracking Matrix with xsim..."
	@cd $(XSIM_DIR) && $(XVLOG) -sv ../../$(PKG_SRC) ../../$(MATRIX_SRC) ../../$(MATRIX_TB) > xvlog_matrix.log 2>&1
	@cd $(XSIM_DIR) && $(XELAB) -debug typical tb_tracking_matrix -s matrix_sim > xelab_matrix.log 2>&1
	@echo "Running Tracking Matrix testbench with xsim..."
	@cd $(XSIM_DIR) && $(XSIM) matrix_sim -runall > xsim_matrix.log 2>&1
	@cd $(XSIM_DIR) && grep "Results:" xsim_matrix.log

#==============================================================================
# Utility targets
#==============================================================================

.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "Build directory cleaned"

.PHONY: help
help:
	@echo "QueueBit Verification Makefile"
	@echo "=============================="
	@echo ""
	@echo "Targets:"
	@echo "  make               - Run all tests with iverilog (default)"
	@echo "  make test          - Run all tests with iverilog"
	@echo "  make test-xsim     - Run all tests with xsim"
	@echo "  make test-all      - Run all tests with both simulators"
	@echo ""
	@echo "Individual tests:"
	@echo "  make iverilog-fifo   - Test FIFO with iverilog"
	@echo "  make iverilog-matrix - Test tracking matrix with iverilog"
	@echo "  make xsim-fifo       - Test FIFO with xsim"
	@echo "  make xsim-matrix     - Test tracking matrix with xsim"
	@echo ""
	@echo "Utility:"
	@echo "  make clean         - Remove all build artifacts"
	@echo "  make help          - Show this help message"
