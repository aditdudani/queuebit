`timescale 1ns/1ps

module tb_tracking_matrix;

    // Parameters
    localparam int COORD_WIDTH = 5;
    localparam int GRID_WIDTH  = 21;
    localparam int GRID_HEIGHT = 23;
    localparam int CLK_PERIOD  = 10;

    // DUT signals
    logic                       clk;
    logic                       rst_n;
    logic [COORD_WIDTH-1:0]     check_x;
    logic [COORD_WIDTH-1:0]     check_y;
    logic [8:0]                 neighborhood;
    logic                       collision;
    logic                       lock_en;
    logic [COORD_WIDTH-1:0]     lock_x;
    logic [COORD_WIDTH-1:0]     lock_y;
    logic                       release_en;
    logic [COORD_WIDTH-1:0]     release_x;
    logic [COORD_WIDTH-1:0]     release_y;

    // Test tracking
    int test_count = 0;
    int pass_count = 0;

    // DUT instantiation
    tracking_matrix #(
        .COORD_WIDTH(COORD_WIDTH),
        .GRID_WIDTH(GRID_WIDTH),
        .GRID_HEIGHT(GRID_HEIGHT)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .check_x(check_x),
        .check_y(check_y),
        .neighborhood(neighborhood),
        .collision(collision),
        .lock_en(lock_en),
        .lock_x(lock_x),
        .lock_y(lock_y),
        .release_en(release_en),
        .release_x(release_x),
        .release_y(release_y)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Signal initialization
    initial begin
        rst_n = 0;
        lock_en = 0;
        release_en = 0;
        lock_x = 0;
        lock_y = 0;
        release_x = 0;
        release_y = 0;
        check_x = 0;
        check_y = 0;
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
        lock_en = 0;
        release_en = 0;
        lock_x = 0;
        lock_y = 0;
        release_x = 0;
        release_y = 0;
        check_x = 0;
        check_y = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
    endtask

    task automatic do_lock(input logic [COORD_WIDTH-1:0] x, input logic [COORD_WIDTH-1:0] y);
        lock_en = 1;
        lock_x = x;
        lock_y = y;
        @(posedge clk);
        lock_en = 0;
        @(posedge clk);  // Wait for NBA region to complete
        #1;              // Delta cycle for good measure
    endtask

    task automatic do_release(input logic [COORD_WIDTH-1:0] x, input logic [COORD_WIDTH-1:0] y);
        release_en = 1;
        release_x = x;
        release_y = y;
        @(posedge clk);
        release_en = 0;
        @(posedge clk);  // Wait for NBA region to complete
        #1;              // Delta cycle for good measure
    endtask

    task automatic check_coord(input logic [COORD_WIDTH-1:0] x, input logic [COORD_WIDTH-1:0] y);
        check_x = x;
        check_y = y;
        #1; // Allow combinatorial logic to settle
    endtask

    // Count locked cells using hierarchical access
    function automatic int count_locked_cells();
        int cnt = 0;
        for (int y = 0; y < GRID_HEIGHT; y++) begin
            for (int x = 0; x < GRID_WIDTH; x++) begin
                if (dut.matrix[y][x]) cnt++;
            end
        end
        return cnt;
    endfunction

    // Main test sequence
    initial begin
        $display("\n========================================");
        $display("  Tracking Matrix Unit Test");
        $display("========================================\n");

        // Test 1: Reset state
        reset();
        check_coord(5'd10, 5'd10);
        check("Reset: all cells clear", count_locked_cells() == 0);
        check("Reset: no collision at (10,10)", collision == 0);

        // Test 2: Lock at interior (10,10) - should set 9 cells
        $display("\n--- Test: Lock at interior (10,10) ---");
        @(posedge clk);  // Extra clock edge before first lock
        do_lock(5'd10, 5'd10);
        check("Interior lock: 9 cells locked", count_locked_cells() == 9);

        // Verify 3x3 region
        check_coord(5'd10, 5'd10);
        check("Center collision detected", collision == 1);
        check("All 9 neighborhood bits set", neighborhood == 9'b111111111);

        // Test 3: Check at distance 2 (should see collision)
        $display("\n--- Test: Collision at Chebyshev distance 2 ---");
        check_coord(5'd12, 5'd10);  // Distance 2 in X
        check("Distance 2: collision detected", collision == 1);

        check_coord(5'd10, 5'd12);  // Distance 2 in Y
        check("Distance 2 (Y): collision detected", collision == 1);

        check_coord(5'd12, 5'd12);  // Distance 2 diagonal
        check("Distance 2 (diag): collision detected", collision == 1);

        // Test 4: Check at distance 3 (should be clear)
        $display("\n--- Test: No collision at Chebyshev distance 3 ---");
        check_coord(5'd13, 5'd10);  // Distance 3 in X
        check("Distance 3: no collision", collision == 0);

        check_coord(5'd10, 5'd13);  // Distance 3 in Y
        check("Distance 3 (Y): no collision", collision == 0);

        // Test 5: Release clears 3x3 region
        $display("\n--- Test: Release clears 3x3 region ---");
        @(posedge clk);  // Extra clock edge before release
        do_release(5'd10, 5'd10);
        check("After release: 0 cells locked", count_locked_cells() == 0);
        check_coord(5'd10, 5'd10);
        check("After release: no collision", collision == 0);

        // Test 6: Lock at corner (0,0) - should only set 4 cells
        $display("\n--- Test: Lock at corner (0,0) ---");
        reset();
        do_lock(5'd0, 5'd0);
        check("Corner (0,0): 4 cells locked", count_locked_cells() == 4);

        // Verify only valid cells are locked
        check_coord(5'd0, 5'd0);
        // Expected: cells at (0,0), (1,0), (0,1), (1,1)
        // neighborhood[4]=center, [5]=right, [7]=below, [8]=below-right
        check("Corner: correct bits set",
              neighborhood[4] == 1 && neighborhood[5] == 1 &&
              neighborhood[7] == 1 && neighborhood[8] == 1 &&
              neighborhood[0] == 0 && neighborhood[1] == 0 &&
              neighborhood[2] == 0 && neighborhood[3] == 0 &&
              neighborhood[6] == 0);

        // Test 7: Lock at opposite corner (20,22)
        $display("\n--- Test: Lock at corner (20,22) ---");
        reset();
        do_lock(5'd20, 5'd22);
        check("Corner (20,22): 4 cells locked", count_locked_cells() == 4);

        // Test 8: Two non-overlapping locks
        $display("\n--- Test: Two non-overlapping locks ---");
        reset();
        do_lock(5'd5, 5'd5);    // First lock
        @(posedge clk);  // Extra clock edge before second lock
        do_lock(5'd15, 5'd15);  // Second lock (distance > 3)
        check("Two locks: 18 cells locked", count_locked_cells() == 18);

        check_coord(5'd5, 5'd5);
        check("First region: collision", collision == 1);

        check_coord(5'd15, 5'd15);
        check("Second region: collision", collision == 1);

        check_coord(5'd10, 5'd10);
        check("Between regions: no collision", collision == 0);

        // Test 9: Out-of-bounds check coordinates return no collision
        $display("\n--- Test: Out-of-bounds check coordinates ---");
        reset();
        do_lock(5'd10, 5'd10);  // Lock interior region

        // Check beyond grid bounds - should return collision=0 for center cell
        check_coord(5'd25, 5'd10);  // X out of bounds
        check("Out-of-bounds X: no collision", collision == 0);

        check_coord(5'd10, 5'd25);  // Y out of bounds
        check("Out-of-bounds Y: no collision", collision == 0);

        check_coord(5'd30, 5'd30);  // Both out of bounds
        check("Out-of-bounds XY: no collision", collision == 0);

        // Summary
        $display("\n========================================");
        $display("  Results: %0d / %0d tests passed", pass_count, test_count);
        $display("========================================\n");

        $finish;
    end

endmodule
