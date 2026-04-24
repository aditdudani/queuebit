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
IVERILOG="C:/iverilog/bin/iverilog.exe"
VVP="C:/iverilog/bin/vvp.exe"

# Source files
PKG_SRC="$RTL_DIR/dispatcher_pkg.sv"
FIFO_SRC="$RTL_DIR/syndrome_fifo.sv"
MATRIX_SRC="$RTL_DIR/tracking_matrix.sv"
FSM_SRC="$RTL_DIR/dispatcher_fsm.sv"
TOP_SRC="$RTL_DIR/dispatcher_top.sv"
FIFO_TB="$TB_DIR/tb_syndrome_fifo.sv"
MATRIX_TB="$TB_DIR/tb_tracking_matrix.sv"
INTEGRATION_TB="$TB_DIR/tb_dispatcher_integration.sv"

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
    "$IVERILOG" -g2012 -o "$IVERILOG_DIR/tb_fifo.vvp" "$PKG_SRC" "$FIFO_SRC" "$FIFO_TB"

    print_info "Running FIFO testbench..."
    cd "$IVERILOG_DIR" && "$VVP" tb_fifo.vvp
    cd ../..
}

run_iverilog_matrix() {
    print_info "Compiling Tracking Matrix with iverilog..."
    mkdir -p "$IVERILOG_DIR"
    "$IVERILOG" -g2012 -o "$IVERILOG_DIR/tb_matrix.vvp" "$PKG_SRC" "$MATRIX_SRC" "$MATRIX_TB"

    print_info "Running Tracking Matrix testbench..."
    cd "$IVERILOG_DIR" && "$VVP" tb_matrix.vvp
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

run_iverilog_integration() {
    print_info "Compiling dispatcher integration test with iverilog..."
    mkdir -p "$IVERILOG_DIR"
    "$IVERILOG" -g2012 -o "$IVERILOG_DIR/tb_integration.vvp" \
        "$PKG_SRC" "$FIFO_SRC" "$MATRIX_SRC" "$FSM_SRC" "$TOP_SRC" "$INTEGRATION_TB"

    print_info "Running integration testbench..."
    cd "$IVERILOG_DIR" && "$VVP" tb_integration.vvp
    cd ../..
}

run_xsim_integration() {
    print_info "Compiling dispatcher integration test with xsim..."
    mkdir -p "$XSIM_DIR"
    cd "$XSIM_DIR"
    "$XVLOG" -sv "../../$PKG_SRC" "../../$FIFO_SRC" "../../$MATRIX_SRC" \
        "../../$FSM_SRC" "../../$TOP_SRC" "../../$INTEGRATION_TB" > xvlog_integration.log 2>&1
    "$XELAB" -debug typical tb_dispatcher_integration -s integration_sim > xelab_integration.log 2>&1

    print_info "Running integration testbench..."
    "$XSIM" integration_sim -runall > xsim_integration.log 2>&1
    grep "INTEGRATION TEST RESULTS" -A 10 xsim_integration.log || grep "Simulation" xsim_integration.log
    cd ../..
}

run_xsim_integration_naive() {
    print_info "Compiling dispatcher integration test (NAIVE - collision checking DISABLED) with xsim..."
    mkdir -p "$XSIM_DIR"
    cd "$XSIM_DIR"
    INTEGRATION_TB_NAIVE="../../tb/tb_dispatcher_integration_naive.sv"
    "$XVLOG" -sv "../../$PKG_SRC" "../../$FIFO_SRC" "../../$MATRIX_SRC" \
        "../../$FSM_SRC" "../../$TOP_SRC" "$INTEGRATION_TB_NAIVE" > xvlog_integration_naive.log 2>&1
    "$XELAB" -debug typical tb_dispatcher_integration_naive -s integration_sim_naive > xelab_integration_naive.log 2>&1

    print_info "Running integration testbench (naive)..."
    "$XSIM" integration_sim_naive -runall > xsim_integration_naive.log 2>&1
    grep "INTEGRATION TEST RESULTS (NAIVE)" -A 10 xsim_integration_naive.log || grep "Simulation" xsim_integration_naive.log
    cd ../..
}

run_xsim_integration_d23() {
    print_info "Compiling dispatcher integration test (d=23) with xsim..."
    mkdir -p "$XSIM_DIR"
    cd "$XSIM_DIR"
    TOP_SRC_D23="../../rtl/dispatcher_top_d23.sv"
    FSM_SRC_D23="../../rtl/dispatcher_fsm_d23.sv"
    INTEGRATION_TB_D23="../../tb/tb_dispatcher_integration_d23.sv"
    "$XVLOG" -sv "../../$PKG_SRC" "../../$FIFO_SRC" "../../$MATRIX_SRC" \
        "$FSM_SRC_D23" "$TOP_SRC_D23" "$INTEGRATION_TB_D23" > xvlog_integration_d23.log 2>&1
    "$XELAB" -debug typical tb_dispatcher_integration_d23 -s integration_sim_d23 > xelab_integration_d23.log 2>&1

    print_info "Running integration testbench (d=23)..."
    "$XSIM" integration_sim_d23 -runall > xsim_integration_d23.log 2>&1
    grep "INTEGRATION TEST RESULTS (d=23)" -A 10 xsim_integration_d23.log || grep "Simulation" xsim_integration_d23.log
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
    echo "  test              - Run unit tests with iverilog (default)"
    echo "  test-xsim         - Run unit tests with xsim"
    echo "  test-all          - Run all unit tests with both simulators"
    echo "  test-integration  - Run integration test with iverilog (d=11)"
    echo "  test-integration-xsim - Run integration test with xsim (d=11)"
    echo "  test-integration-naive - Run integration test (naive, no collision checking)"
    echo "  test-d23          - Run integration test with d=23 dispatcher (xsim)"
    echo ""
    echo "Individual unit tests:"
    echo "  iverilog-fifo     - Test FIFO with iverilog"
    echo "  iverilog-matrix   - Test tracking matrix with iverilog"
    echo "  xsim-fifo         - Test FIFO with xsim"
    echo "  xsim-matrix       - Test tracking matrix with xsim"
    echo ""
    echo "Individual integration tests:"
    echo "  iverilog-integration - Integration test with iverilog (d=11)"
    echo "  xsim-integration     - Integration test with xsim (d=11)"
    echo "  xsim-d23             - Integration test with xsim (d=23)"
    echo ""
    echo "Utility:"
    echo "  clean             - Remove all build artifacts"
    echo "  help              - Show this help message"
}

# Main script
case "${1:-test}" in
    test)
        print_header "Running iverilog unit tests"
        run_iverilog_fifo
        echo ""
        run_iverilog_matrix
        ;;
    test-xsim)
        print_header "Running xsim unit tests"
        run_xsim_fifo
        echo ""
        run_xsim_matrix
        ;;
    test-all)
        print_header "Running all unit tests (iverilog + xsim)"
        run_iverilog_fifo
        echo ""
        run_iverilog_matrix
        echo ""
        run_xsim_fifo
        echo ""
        run_xsim_matrix
        ;;
    test-integration)
        print_header "Running integration test (iverilog)"
        run_iverilog_integration
        ;;
    test-integration-xsim)
        print_header "Running integration test (xsim)"
        run_xsim_integration
        ;;
    iverilog-fifo)
        run_iverilog_fifo
        ;;
    iverilog-matrix)
        run_iverilog_matrix
        ;;
    iverilog-integration)
        run_iverilog_integration
        ;;
    xsim-fifo)
        run_xsim_fifo
        ;;
    xsim-matrix)
        run_xsim_matrix
        ;;
    xsim-integration)
        run_xsim_integration
        ;;
    test-integration-naive)
        print_header "Running integration test (naive - collision checking disabled)"
        run_xsim_integration_naive
        ;;
    xsim-integration-naive)
        run_xsim_integration_naive
        ;;
    test-d23)
        print_header "Running integration test (d=23 dispatcher)"
        run_xsim_integration_d23
        ;;
    xsim-d23)
        run_xsim_integration_d23
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
