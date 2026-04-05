`timescale 1ns/1ps

module tb_dispatcher_integration;

    import dispatcher_pkg::*;

    // Testbench signals
    logic clk, rst_n;
    logic wr_valid, wr_ready;
    logic [9:0] wr_data;               // {y[4:0], x[4:0]}
    logic [3:0] worker_issue, worker_ready, worker_done;
    logic [9:0] issue_coord;           // {y[4:0], x[4:0]}
    logic issue_valid;

    // Stimulus data (dynamic arrays for Verilog compatibility)
    integer stim_x [500];
    integer stim_y [500];
    integer stim_count = 0;

    // Test metrics
    integer cycle_count = 0;
    integer issued_count = 0;
    integer syndromes_injected = 0;
    integer stall_count = 0;
    integer collision_warnings = 0;

    // Dispatch log
    string dispatch_log_filename = "dispatch_log.txt";
    integer dispatch_log_fd = 0;

    // Worker latency simulation (K=5 cycles)
    localparam int WORKER_LATENCY = 5;
    integer worker_timer [4];
    logic [3:0] worker_busy;
    integer worker_coord_x [4];
    integer worker_coord_y [4];

    // =========================================================================
    // Clock Generation
    // =========================================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;  // 10ns period = 100 MHz
    end

    // =========================================================================
    // Reset Sequence
    // =========================================================================

    initial begin
        rst_n = 1'b0;
        #25;  // 2.5 cycles
        rst_n = 1'b1;
    end

    // =========================================================================
    // Load Stimulus from File
    // =========================================================================

    initial begin
        integer file_fd, x, y, i;
        string stim_path;

        // Try primary path
        stim_path = "verification/stim_errors.txt";
        file_fd = $fopen(stim_path, "r");

        // Try alternate path (for build subdirectory runs)
        if (file_fd == 0) begin
            stim_path = "../../verification/stim_errors.txt";
            file_fd = $fopen(stim_path, "r");
        end

        // If file found, load stimulus
        if (file_fd != 0) begin
            stim_count = 0;
            while (!$feof(file_fd) && stim_count < 500) begin
                if ($fscanf(file_fd, "%d %d", x, y) == 2) begin
                    stim_x[stim_count] = x;
                    stim_y[stim_count] = y;
                    stim_count = stim_count + 1;
                end
            end
            $fclose(file_fd);
            $display("[Stimulus] Loaded %0d syndrome pairs from %s", stim_count, stim_path);
        end else begin
            // Fallback: use small test set
            $display("[Stimulus] Could not load stimulus file, using 10-syndrome test set");
            stim_count = 10;
            stim_x[0] = 0;   stim_y[0] = 0;
            stim_x[1] = 5;   stim_y[1] = 5;
            stim_x[2] = 10;  stim_y[2] = 10;
            stim_x[3] = 15;  stim_y[3] = 15;
            stim_x[4] = 20;  stim_y[4] = 20;
            stim_x[5] = 3;   stim_y[5] = 7;
            stim_x[6] = 8;   stim_y[6] = 12;
            stim_x[7] = 1;   stim_y[7] = 1;
            stim_x[8] = 19;  stim_y[8] = 22;
            stim_x[9] = 10;  stim_y[9] = 15;
        end
    end

    // =========================================================================
    // Stimulus Injection (Proper Handshake Protocol)
    // =========================================================================

    integer stim_idx = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_valid <= 1'b0;
            wr_data  <= 10'b0;
            stim_idx <= 0;
        end else begin
            // Proper handshake: only write when FIFO is ready AND not currently writing
            if (!wr_valid && stim_idx < stim_count && wr_ready) begin
                // No transfer pending, FIFO ready, and have data: initiate transfer
                wr_valid <= 1'b1;
                wr_data  <= {stim_y[stim_idx][4:0], stim_x[stim_idx][4:0]};
            end else if (wr_valid && wr_ready) begin
                // Transfer completed: advance to next
                syndromes_injected <= syndromes_injected + 1;
                stim_idx <= stim_idx + 1;
                if (stim_idx + 1 < stim_count) begin
                    // Immediately start next transfer
                    wr_valid <= 1'b1;
                    wr_data  <= {stim_y[stim_idx+1][4:0], stim_x[stim_idx+1][4:0]};
                end else begin
                    // No more data
                    wr_valid <= 1'b0;
                end
            end
            // else: wr_valid stays high while waiting for wr_ready (handshake pending)
        end
    end

    // =========================================================================
    // Worker Latency Simulation (Fixed K=5 cycles)
    // =========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 4; i++) begin
                worker_timer[i] <= 0;
                worker_busy[i]  <= 1'b0;
                worker_coord_x[i] <= 0;
                worker_coord_y[i] <= 0;
            end
        end else begin
            // Decrement active worker timers
            for (int i = 0; i < 4; i++) begin
                if (worker_busy[i]) begin
                    if (worker_timer[i] > 0) begin
                        worker_timer[i] <= worker_timer[i] - 1;
                    end else begin
                        worker_busy[i] <= 1'b0;
                    end
                end

                // When worker is issued a task, start its timer and store coordinates
                if (worker_issue[i] && issue_valid) begin
                    worker_timer[i] <= WORKER_LATENCY - 1;
                    worker_busy[i]  <= 1'b1;
                    worker_coord_x[i] <= issue_coord[4:0];
                    worker_coord_y[i] <= issue_coord[9:5];
                end
            end
        end
    end

    // Generate worker_done signals when timers expire
    always_comb begin
        for (int i = 0; i < 4; i++) begin
            worker_done[i] = worker_busy[i] && (worker_timer[i] == 0);
        end
    end

    // Compute worker_ready: 1 if not busy
    always_comb begin
        for (int i = 0; i < 4; i++) begin
            worker_ready[i] = ~worker_busy[i];
        end
    end

    // =========================================================================
    // Dispatch Logging & Monitoring
    // =========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 0;
            issued_count <= 0;
            stall_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            // Log dispatch events (LOCK format for verify_collisions.py)
            if (issue_valid && |worker_issue) begin
                issued_count <= issued_count + 1;
                if (dispatch_log_fd != 0) begin
                    // Find which worker was issued
                    for (int i = 0; i < 4; i++) begin
                        if (worker_issue[i]) begin
                            $fwrite(dispatch_log_fd, "%0d LOCK %0d %0d %0d\n",
                                    cycle_count, i, issue_coord[4:0], issue_coord[9:5]);
                        end
                    end
                end
            end

            // Log worker release events (RELEASE format for verify_collisions.py)
            for (int i = 0; i < 4; i++) begin
                if (worker_done[i]) begin
                    if (dispatch_log_fd != 0) begin
                        $fwrite(dispatch_log_fd, "%0d RELEASE %0d %0d %0d\n",
                                cycle_count, i, worker_coord_x[i], worker_coord_y[i]);
                    end
                end
            end
        end
    end

    // =========================================================================
    // Module Instantiation
    // =========================================================================

    dispatcher_top dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .wr_valid       (wr_valid),
        .wr_data        (wr_data),
        .wr_ready       (wr_ready),
        .worker_issue   (worker_issue),
        .issue_coord    (issue_coord),
        .issue_valid    (issue_valid),
        .worker_ready   (worker_ready),
        .worker_done    (worker_done)
    );

    // =========================================================================
    // Test Control: Run until all stimulus processed + workers idle
    // =========================================================================

    initial begin
        integer wait_cycles = 0;
        integer max_wait = 2000;

        // Wait for reset
        wait(rst_n);
        @(posedge clk);

        // Open dispatch log for writing
        dispatch_log_fd = $fopen("dispatch_log.txt", "w");
        if (dispatch_log_fd == 0) begin
            $display("[WARNING] Could not open dispatch_log.txt");
        end

        // Wait for all stimulus to be injected
        wait(stim_idx >= stim_count);
        $display("[Testbench] All %0d syndromes injected at cycle %0d", stim_count, cycle_count);

        // Wait for all workers to complete
        wait_cycles = 0;
        while (worker_busy != 4'b0000 && wait_cycles < max_wait) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end

        if (wait_cycles >= max_wait) begin
            $warning("[Testbench] Timeout waiting for workers to complete");
        end

        // Close dispatch log
        if (dispatch_log_fd != 0) begin
            $fclose(dispatch_log_fd);
            $display("[Testbench] Dispatch log written to dispatch_log.txt");
        end

        // Final report
        $display("\n");
        $display("================================================");
        $display("DISPATCHER INTEGRATION TEST RESULTS");
        $display("================================================");
        $display("Total cycles run:     %0d", cycle_count);
        $display("Syndromes injected:   %0d", syndromes_injected);
        $display("Syndromes issued:     %0d", issued_count);
        $display("Completion status:    %s", (worker_busy == 4'b0000) ? "ALL WORKERS DONE" : "TIMEOUT");
        $display("================================================");
        $display("Expected: collision verification via verify_collisions.py");
        $display("================================================\n");

        // Finish simulation
        #100;
        $finish;
    end

endmodule
