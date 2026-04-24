`ifndef DISPATCHER_TOP_D23_SV
`define DISPATCHER_TOP_D23_SV

`timescale 1ns/1ps

module dispatcher_top_d23 #(
    parameter bit ENABLE_COLLISION_CHECK = 1'b1  // Set to 0 for naive variant (no collision avoidance)
) (
    input  logic                            clk,
    input  logic                            rst_n,

    // Upstream: Syndrome ingestion interface
    input  logic                            wr_valid,
    input  logic [11:0]                     wr_data,      // {y[5:0], x[5:0]}
    output logic                            wr_ready,

    // Downstream: Worker dispatch interface
    output logic [3:0]                      worker_issue,  // one-hot: which worker gets task
    output logic [11:0]                     issue_coord,   // coordinate broadcast to all workers
    output logic                            issue_valid,   // strobe: task is valid this cycle

    input  logic [3:0]                      worker_ready,  // per-worker idle status
    input  logic [3:0]                      worker_done,   // per-worker completion signal

    // Debug: Collision detection events
    output logic                            collision_detected  // strobe: collision was detected
);

    import dispatcher_pkg::*;

    // =========================================================================
    // Internal Signals: FIFO → FSM paths
    // =========================================================================

    logic                        fifo_rd_valid;
    logic                        fifo_rd_ready;
    logic [5:0]                  fifo_rd_x;
    logic [5:0]                  fifo_rd_y;
    logic                        fifo_empty, fifo_full;
    logic [$clog2(FIFO_DEPTH):0] fifo_count;

    // =========================================================================
    // Internal Signals: FSM → Matrix paths
    // =========================================================================

    logic                        matrix_check_en;
    logic [5:0]                  matrix_check_x;
    logic [5:0]                  matrix_check_y;
    logic [8:0]                  matrix_neighborhood;
    logic                        matrix_collision;

    logic                        matrix_lock_en;
    logic [5:0]                  matrix_lock_x;
    logic [5:0]                  matrix_lock_y;

    logic                        matrix_release_en;
    logic [5:0]                  matrix_release_x;
    logic [5:0]                  matrix_release_y;

    // =========================================================================
    // Per-Worker Coordination: Track coordinates and release timing
    // =========================================================================

    // Store the syndrome coordinates for each worker
    logic [5:0] worker_coord_x [4];
    logic [5:0] worker_coord_y [4];
    logic [3:0] worker_active;              // which workers have active syndromes

    // Latch worker coordinates and mark active
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            worker_active <= 4'b0000;
            for (int i = 0; i < 4; i++) begin
                worker_coord_x[i] <= 6'b0;
                worker_coord_y[i] <= 6'b0;
            end
        end else begin
            // When a worker is issued a task, store its coordinates
            for (int i = 0; i < 4; i++) begin
                if (worker_issue[i] && issue_valid) begin
                    worker_coord_x[i] <= issue_coord[5:0];
                    worker_coord_y[i] <= issue_coord[11:6];
                    worker_active[i]  <= 1'b1;
                end
                // When a worker completes, release its lock and mark inactive
                if (worker_done[i]) begin
                    worker_active[i] <= 1'b0;
                end
            end
        end
    end

    // =========================================================================
    // Release Logic: Issue matrix release when workers complete
    // =========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            matrix_release_en <= 1'b0;
            matrix_release_x  <= 6'b0;
            matrix_release_y  <= 6'b0;
        end else begin
            // Default: no release
            matrix_release_en <= 1'b0;

            // For each worker that just completed, release its locked region
            // (Priority: worker 0, 1, 2, 3 - only release one per cycle for simplicity)
            if (worker_done[0] && worker_active[0]) begin
                matrix_release_en <= 1'b1;
                matrix_release_x  <= worker_coord_x[0];
                matrix_release_y  <= worker_coord_y[0];
            end else if (worker_done[1] && worker_active[1]) begin
                matrix_release_en <= 1'b1;
                matrix_release_x  <= worker_coord_x[1];
                matrix_release_y  <= worker_coord_y[1];
            end else if (worker_done[2] && worker_active[2]) begin
                matrix_release_en <= 1'b1;
                matrix_release_x  <= worker_coord_x[2];
                matrix_release_y  <= worker_coord_y[2];
            end else if (worker_done[3] && worker_active[3]) begin
                matrix_release_en <= 1'b1;
                matrix_release_x  <= worker_coord_x[3];
                matrix_release_y  <= worker_coord_y[3];
            end
        end
    end

    // =========================================================================
    // Module Instantiations
    // =========================================================================

    // Syndrome FIFO (d=23 variant: COORD_WIDTH=6)
    syndrome_fifo #(
        .COORD_WIDTH(6),
        .DEPTH(32)
    ) fifo_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .wr_valid   (wr_valid),
        .wr_ready   (wr_ready),
        .wr_x       (wr_data[5:0]),       // Extract x from packed data
        .wr_y       (wr_data[11:6]),      // Extract y from packed data
        .rd_valid   (fifo_rd_valid),
        .rd_ready   (fifo_rd_ready),
        .rd_x       (fifo_rd_x),
        .rd_y       (fifo_rd_y),
        .empty      (fifo_empty),
        .full       (fifo_full),
        .count      (fifo_count)
    );

    // Tracking Matrix (d=23 variant: GRID=47x47, COORD_WIDTH=6)
    tracking_matrix #(
        .COORD_WIDTH(6),
        .GRID_WIDTH(47),
        .GRID_HEIGHT(47)
    ) matrix_inst (
        .clk            (clk),
        .rst_n          (rst_n),
        .check_x        (matrix_check_x),
        .check_y        (matrix_check_y),
        .neighborhood   (matrix_neighborhood),
        .collision      (matrix_collision),
        .lock_en        (matrix_lock_en),
        .lock_x         (matrix_lock_x),
        .lock_y         (matrix_lock_y),
        .release_en     (matrix_release_en),
        .release_x      (matrix_release_x),
        .release_y      (matrix_release_y)
    );

    // Dispatcher FSM (d=23 variant)
    logic [11:0] dispatch_coord_internal;
    logic        dispatch_valid_internal;

    dispatcher_fsm_d23 #(
        .ENABLE_COLLISION_CHECK(ENABLE_COLLISION_CHECK)
    ) fsm_inst (
        .clk                (clk),
        .rst_n              (rst_n),
        .fifo_rd_valid      (fifo_rd_valid),
        .fifo_rd_ready      (fifo_rd_ready),
        .fifo_rd_x          (fifo_rd_x),
        .fifo_rd_y          (fifo_rd_y),
        .matrix_check_en    (matrix_check_en),
        .matrix_check_x     (matrix_check_x),
        .matrix_check_y     (matrix_check_y),
        .matrix_collision   (matrix_collision),
        .matrix_lock_en     (matrix_lock_en),
        .matrix_lock_x      (matrix_lock_x),
        .matrix_lock_y      (matrix_lock_y),
        .matrix_release_en  (),    // Not used; top-level handles releases
        .matrix_release_x   (),
        .matrix_release_y   (),
        .worker_ready       (worker_ready),
        .worker_done        (worker_done),
        .worker_issue       (worker_issue),
        .dispatch_coord     (dispatch_coord_internal),
        .dispatch_valid     (dispatch_valid_internal),
        .collision_detected (collision_detected)  // <-- Export for testbench monitoring
    );

    // Connect FSM dispatch outputs to top-level issue interface
    assign issue_coord = dispatch_coord_internal;
    assign issue_valid = dispatch_valid_internal;

    // =========================================================================
    // Assertions & Monitoring
    // =========================================================================

    // synthesis translate_off
    always @(posedge clk) begin
        if (rst_n) begin
            // Log dispatch events
            if (issue_valid && |worker_issue) begin
                for (int i = 0; i < 4; i++) begin
                    if (worker_issue[i]) begin
                        $display("[Dispatcher d23] Cycle %0d: Issued syndr (%0d, %0d) to worker[%0d]",
                                 $time, issue_coord[5:0], issue_coord[11:6], i);
                    end
                end
            end

            // Log worker_done signals
            for (int i = 0; i < 4; i++) begin
                if (worker_done[i]) begin
                    $display("[Dispatcher d23] Cycle %0d: Worker[%0d] DONE (active=%0b, stored_coord=(%0d,%0d))",
                             $time, i, worker_active[i], worker_coord_x[i], worker_coord_y[i]);
                end
            end

            // Log actual release commands issued
            if (matrix_release_en) begin
                for (int i = 0; i < 4; i++) begin
                    if (worker_done[i] && worker_active[i]) begin
                        $display("[Dispatcher d23] Cycle %0d: Release issued for worker[%0d] at (%0d,%0d)",
                                 $time, i, matrix_release_x, matrix_release_y);
                    end
                end
            end
        end
    end
    // synthesis translate_on

endmodule

`endif
