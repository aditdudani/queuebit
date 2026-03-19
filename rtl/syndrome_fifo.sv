`ifndef SYNDROME_FIFO_SV
`define SYNDROME_FIFO_SV

`timescale 1ns/1ps

module syndrome_fifo #(
    parameter int COORD_WIDTH = 5,
    parameter int DEPTH       = 32
) (
    input  logic                        clk,
    input  logic                        rst_n,

    // Write port (upstream - from syndrome source)
    input  logic                        wr_valid,
    output logic                        wr_ready,
    input  logic [COORD_WIDTH-1:0]      wr_x,
    input  logic [COORD_WIDTH-1:0]      wr_y,

    // Read port (downstream - to FSM)
    output logic                        rd_valid,
    input  logic                        rd_ready,
    output logic [COORD_WIDTH-1:0]      rd_x,
    output logic [COORD_WIDTH-1:0]      rd_y,

    // Status flags
    output logic                        empty,
    output logic                        full,
    output logic [$clog2(DEPTH):0]      count
);

    // Local parameters
    localparam int DATA_WIDTH = 2 * COORD_WIDTH;
    localparam int PTR_WIDTH  = $clog2(DEPTH);

    // Storage
    logic [DATA_WIDTH-1:0] mem [DEPTH];

    // Pointers (extra MSB to distinguish full from empty)
    logic [PTR_WIDTH:0] wr_ptr;
    logic [PTR_WIDTH:0] rd_ptr;

    // Internal signals
    logic do_write;
    logic do_read;

    // Combinatorial status
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]) &&
                   (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]);
    assign count = wr_ptr - rd_ptr;

    // Handshake
    assign wr_ready = ~full;
    assign rd_valid = ~empty;

    // Write and read conditions
    assign do_write = wr_valid && wr_ready;
    assign do_read  = rd_valid && rd_ready;

    // Read data output (combinatorial from memory)
    assign rd_x = mem[rd_ptr[PTR_WIDTH-1:0]][COORD_WIDTH-1:0];
    assign rd_y = mem[rd_ptr[PTR_WIDTH-1:0]][DATA_WIDTH-1:COORD_WIDTH];

    // Pointer and memory update (iverilog-compatible: use always instead of always_ff)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= {(PTR_WIDTH+1){1'b0}};
            rd_ptr <= {(PTR_WIDTH+1){1'b0}};
        end else begin
            // Write operation
            if (do_write) begin
                mem[wr_ptr[PTR_WIDTH-1:0]] <= {wr_y, wr_x};
                wr_ptr <= wr_ptr + 1'b1;
            end

            // Read operation
            if (do_read) begin
                rd_ptr <= rd_ptr + 1'b1;
            end
        end
    end

    // Assertions for simulation
    // synthesis translate_off
    initial begin
        // Compile-time check: DEPTH must be power of 2 and >= 2
        if (DEPTH < 2) begin
            $fatal(1, "FIFO: DEPTH=%0d must be at least 2", DEPTH);
        end
        if ((DEPTH & (DEPTH - 1)) != 0) begin
            $fatal(1, "FIFO: DEPTH=%0d must be a power of 2", DEPTH);
        end
    end

    always @(posedge clk) begin
        if (rst_n) begin
            // Check raw inputs to catch protocol violations
            if (wr_valid && full)
                $error("FIFO: wr_valid asserted while full!");
            if (rd_ready && empty)
                $error("FIFO: rd_ready asserted while empty!");
        end
    end
    // synthesis translate_on

endmodule

`endif
