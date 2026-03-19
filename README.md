# QueueBit

Hardware implementation for efficient syndrome-based error tracking in surface code quantum error correction.

## Project Structure

```
queuebit/
├── rtl/                    # RTL source files
│   ├── dispatcher_pkg.sv   # Package definitions
│   ├── syndrome_fifo.sv    # Syndrome FIFO queue
│   └── tracking_matrix.sv  # 2D tracking matrix
├── tb/                     # Testbenches
│   ├── tb_syndrome_fifo.sv
│   └── tb_tracking_matrix.sv
├── build/                  # Build artifacts (auto-generated, gitignored)
│   ├── iverilog/          # iverilog outputs
│   └── xsim/              # Xilinx xsim outputs
└── build.sh               # Build script

```

## Build & Test

### Quick Start

```bash
# Run all tests with iverilog (default)
./build.sh

# Run all tests with xsim
./build.sh test-xsim

# Run all tests with both simulators
./build.sh test-all

# Clean build artifacts
./build.sh clean
```

### Individual Tests

```bash
# Test FIFO
./build.sh iverilog-fifo
./build.sh xsim-fifo

# Test tracking matrix
./build.sh iverilog-matrix
./build.sh xsim-matrix
```

### Using Make (if available)

```bash
make              # Run all tests with iverilog
make test-xsim    # Run all tests with xsim
make test-all     # Run all tests with both simulators
make clean        # Remove build artifacts
```

## Requirements

- **iverilog**: Open-source Verilog simulator
- **Xilinx Vivado 2025.1** (optional): For xsim testing

## Test Results

All modules include comprehensive testbenches with automated pass/fail reporting:

- **syndrome_fifo**: 26/26 tests passing
- **tracking_matrix**: 22/22 tests passing

Both modules verified on iverilog and Xilinx xsim.

## Notes

- All build artifacts are isolated in the `build/` directory
- The build directory is automatically created and is excluded from git
- Run `./build.sh clean` to remove all build artifacts
