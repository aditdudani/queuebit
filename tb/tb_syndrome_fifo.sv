`timescale 1ns/1ps

module tb_syndrome_fifo;

    // Parameters
    localparam int COORD_WIDTH = 5;
    localparam int DEPTH = 8;  // Smaller for testing
    localparam int CLK_PERIOD = 10;

    // DUT signals
    logic                       clk;
    logic                       rst_n;
    logic                       wr_valid;
    logic                       wr_ready;
    logic [COORD_WIDTH-1:0]     wr_x;
    logic [COORD_WIDTH-1:0]     wr_y;
    logic                       rd_valid;
    logic                       rd_ready;
    logic [COORD_WIDTH-1:0]     rd_x;
    logic [COORD_WIDTH-1:0]     rd_y;
    logic                       empty;
    logic                       full;
    logic [$clog2(DEPTH):0]     count;

    // Test tracking
    int test_count = 0;
    int pass_count = 0;

    // DUT instantiation
    syndrome_fifo #(
        .COORD_WIDTH(COORD_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_valid(wr_valid),
        .wr_ready(wr_ready),
        .wr_x(wr_x),
        .wr_y(wr_y),
        .rd_valid(rd_valid),
        .rd_ready(rd_ready),
        .rd_x(rd_x),
        .rd_y(rd_y),
        .empty(empty),
        .full(full),
        .count(count)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test tasks
    task automatic check(input string name, input logic condition);
        test_count++;
        if (condition) begin
            $display("[PASS] %s", name);
            pass_count++;
        end else begin
            $display("[FAIL] %s", name);
        end
    endtask

    task automatic reset();
        rst_n = 0;
        wr_valid = 0;
        rd_ready = 0;
        wr_x = 0;
        wr_y = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
    endtask

    task automatic write_coord(input logic [COORD_WIDTH-1:0] x, input logic [COORD_WIDTH-1:0] y);
        wr_valid = 1;
        wr_x = x;
        wr_y = y;
        while (!wr_ready) @(posedge clk);  // Wait until ready first
        @(posedge clk);                     // Write happens here
        #1;  // Ensure NBA completes
        wr_valid = 0;
    endtask

    task automatic read_coord(output logic [COORD_WIDTH-1:0] x, output logic [COORD_WIDTH-1:0] y);
        rd_ready = 1;
        // Wait until data is valid
        while (!rd_valid) @(posedge clk);
        // Capture data BEFORE the clock edge that consumes it
        x = rd_x;
        y = rd_y;
        @(posedge clk);  // This edge increments rd_ptr
        #1;  // Ensure NBA completes
        rd_ready = 0;
    endtask

    // Main test sequence
    initial begin
        logic [COORD_WIDTH-1:0] rx, ry;

        $display("\n========================================");
        $display("  FIFO Unit Test");
        $display("========================================\n");

        // Test 1: Reset state
        reset();
        check("Reset: empty=1", empty == 1);
        check("Reset: full=0", full == 0);
        check("Reset: count=0", count == 0);
        check("Reset: rd_valid=0", rd_valid == 0);
        check("Reset: wr_ready=1", wr_ready == 1);

        // Test 2: Single write/read
        $display("\n--- Test: Single write/read ---");
        write_coord(5'd10, 5'd15);
        #1;  // Allow combinatorial signals to propagate
        check("After write: empty=0", empty == 0);
        check("After write: count=1", count == 1);

        read_coord(rx, ry);
        check("Read data: x=10", rx == 5'd10);
        check("Read data: y=15", ry == 5'd15);
        @(posedge clk);
        check("After read: empty=1", empty == 1);
        check("After read: count=0", count == 0);

        // Test 3: Fill to capacity
        $display("\n--- Test: Fill to capacity ---");
        reset();
        for (int i = 0; i < DEPTH; i++) begin
            write_coord(COORD_WIDTH'(i), COORD_WIDTH'(i+1));
        end
        #1;  // Allow combinatorial signals to propagate
        check("Full: full=1", full == 1);
        check("Full: count=DEPTH", count == DEPTH);
        check("Full: wr_ready=0", wr_ready == 0);

        // Test 4: Empty completely
        $display("\n--- Test: Empty completely ---");
        #1;  // Ensure signals propagate before first read
        for (int i = 0; i < DEPTH; i++) begin
            read_coord(rx, ry);
            check($sformatf("FIFO order: x=%0d", i), rx == COORD_WIDTH'(i));
        end
        #1;  // Allow combinatorial signals to propagate
        check("Empty: empty=1", empty == 1);
        check("Empty: count=0", count == 0);

        // Test 5: Simultaneous read/write
        $display("\n--- Test: Simultaneous R/W ---");
        reset();
        write_coord(5'd1, 5'd2);
        write_coord(5'd3, 5'd4);
        #1;  // Allow combinatorial signals to propagate
        check("Before simul: count=2", count == 2);

        // Simultaneous read and write
        wr_valid = 1;
        wr_x = 5'd5;
        wr_y = 5'd6;
        rd_ready = 1;
        @(posedge clk);
        wr_valid = 0;
        rd_ready = 0;
        @(posedge clk);
        check("After simul R/W: count=2", count == 2);

        // Summary
        $display("\n========================================");
        $display("  Results: %0d / %0d tests passed", pass_count, test_count);
        $display("========================================\n");

        $finish;
    end

endmodule
