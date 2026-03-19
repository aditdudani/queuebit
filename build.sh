#!/usr/bin/env bash
# Build script for QueueBit Verification
# Run tests with iverilog and xsim in isolated build directories

# Directories
RTL_DIR="rtl"
TB_DIR="tb"
BUILD_DIR="build"
IVERILOG_DIR="$BUILD_DIR/iverilog"
XSIM_DIR="$BUILD_DIR/xsim"

# Xilinx tools
XVLOG="C:/Xilinx/2025.1/Vivado/bin/xvlog.bat"
XELAB="C:/Xilinx/2025.1/Vivado/bin/xelab.bat"
XSIM="C:/Xilinx/2025.1/Vivado/bin/xsim.bat"

# Source files
PKG_SRC="$RTL_DIR/dispatcher_pkg.sv"
FIFO_SRC="$RTL_DIR/syndrome_fifo.sv"
MATRIX_SRC="$RTL_DIR/tracking_matrix.sv"
FIFO_TB="$TB_DIR/tb_syndrome_fifo.sv"
MATRIX_TB="$TB_DIR/tb_tracking_matrix.sv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}→${NC} $1"
}

# iverilog functions
run_iverilog_fifo() {
    print_info "Compiling FIFO with iverilog..."
    mkdir -p "$IVERILOG_DIR"
    iverilog -g2012 -o "$IVERILOG_DIR/tb_fifo.vvp" "$PKG_SRC" "$FIFO_SRC" "$FIFO_TB"

    print_info "Running FIFO testbench..."
    cd "$IVERILOG_DIR" && vvp tb_fifo.vvp
    cd ../..
}

run_iverilog_matrix() {
    print_info "Compiling Tracking Matrix with iverilog..."
    mkdir -p "$IVERILOG_DIR"
    iverilog -g2012 -o "$IVERILOG_DIR/tb_matrix.vvp" "$PKG_SRC" "$MATRIX_SRC" "$MATRIX_TB"

    print_info "Running Tracking Matrix testbench..."
    cd "$IVERILOG_DIR" && vvp tb_matrix.vvp
    cd ../..
}

# xsim functions
run_xsim_fifo() {
    print_info "Compiling FIFO with xsim..."
    mkdir -p "$XSIM_DIR"
    cd "$XSIM_DIR"
    "$XVLOG" -sv "../../$PKG_SRC" "../../$FIFO_SRC" "../../$FIFO_TB" > xvlog_fifo.log 2>&1
    "$XELAB" -debug typical tb_syndrome_fifo -s fifo_sim > xelab_fifo.log 2>&1

    print_info "Running FIFO testbench..."
    "$XSIM" fifo_sim -runall > xsim_fifo.log 2>&1
    grep "Results:" xsim_fifo.log
    cd ../..
}

run_xsim_matrix() {
    print_info "Compiling Tracking Matrix with xsim..."
    mkdir -p "$XSIM_DIR"
    cd "$XSIM_DIR"
    "$XVLOG" -sv "../../$PKG_SRC" "../../$MATRIX_SRC" "../../$MATRIX_TB" > xvlog_matrix.log 2>&1
    "$XELAB" -debug typical tb_tracking_matrix -s matrix_sim > xelab_matrix.log 2>&1

    print_info "Running Tracking Matrix testbench..."
    "$XSIM" matrix_sim -runall > xsim_matrix.log 2>&1
    grep "Results:" xsim_matrix.log
    cd ../..
}

# Clean build directory
clean() {
    print_info "Cleaning build artifacts..."
    rm -rf "$BUILD_DIR"
    print_success "Build directory cleaned"
}

# Show help
show_help() {
    echo "QueueBit Verification Build Script"
    echo "===================================="
    echo ""
    echo "Usage: ./build.sh [command]"
    echo ""
    echo "Commands:"
    echo "  test              - Run all tests with iverilog (default)"
    echo "  test-xsim         - Run all tests with xsim"
    echo "  test-all          - Run all tests with both simulators"
    echo ""
    echo "Individual tests:"
    echo "  iverilog-fifo     - Test FIFO with iverilog"
    echo "  iverilog-matrix   - Test tracking matrix with iverilog"
    echo "  xsim-fifo         - Test FIFO with xsim"
    echo "  xsim-matrix       - Test tracking matrix with xsim"
    echo ""
    echo "Utility:"
    echo "  clean             - Remove all build artifacts"
    echo "  help              - Show this help message"
}

# Main script
case "${1:-test}" in
    test)
        print_header "Running iverilog tests"
        run_iverilog_fifo
        echo ""
        run_iverilog_matrix
        ;;
    test-xsim)
        print_header "Running xsim tests"
        run_xsim_fifo
        echo ""
        run_xsim_matrix
        ;;
    test-all)
        print_header "Running all tests (iverilog + xsim)"
        run_iverilog_fifo
        echo ""
        run_iverilog_matrix
        echo ""
        run_xsim_fifo
        echo ""
        run_xsim_matrix
        ;;
    iverilog-fifo)
        run_iverilog_fifo
        ;;
    iverilog-matrix)
        run_iverilog_matrix
        ;;
    xsim-fifo)
        run_xsim_fifo
        ;;
    xsim-matrix)
        run_xsim_matrix
        ;;
    clean)
        clean
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run './build.sh help' for usage information"
        exit 1
        ;;
esac
