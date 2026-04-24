`timescale 1ns/1ps

module tb_dispatcher_integration_d23 #(
    parameter integer WORKER_LATENCY = 5,
    parameter integer INJECT_RATE_PPT = 1000  // Thousandths of a syndrome per cycle
) ();

    import dispatcher_pkg::*;

    // Testbench signals
    logic clk, rst_n;
    logic wr_valid, wr_ready;
    logic [11:0] wr_data;               // {y[5:0], x[5:0]}
    logic [3:0] worker_issue, worker_ready, worker_done;
    logic [11:0] issue_coord;           // {y[5:0], x[5:0]}
    logic issue_valid;
    logic collision_detected;           // Strobe when collision is detected

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
    string dispatch_log_filename = "dispatch_log_d23.txt";
    integer dispatch_log_fd = 0;

    // Worker latency simulation (K cycles, overridable parameter)
    // WORKER_LATENCY is now a top-level module parameter (see module header)
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
    // Load Stimulus from File (d=23 variant)
    // =========================================================================

    initial begin
        integer file_fd, x, y, i;
        string stim_path;

        // Try primary path (d=23 stimulus file)
        stim_path = "D:\\College\\4-2\\SoP2\\Code\\queuebit\\verification\\stim_errors_d23.txt";
        file_fd = $fopen(stim_path, "r");

        // Try alternate path (for build subdirectory runs)
        if (file_fd == 0) begin
            stim_path = "D:/College/4-2/SoP2/Code/queuebit/verification/stim_errors_d23.txt";
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
            // Fallback: use small test set (d=23 range)
            $display("[Stimulus] Could not load stimulus file, using 10-syndrome test set");
            stim_count = 10;
            stim_x[0] = 0;   stim_y[0] = 0;
            stim_x[1] = 11;  stim_y[1] = 11;
            stim_x[2] = 22;  stim_y[2] = 22;
            stim_x[3] = 33;  stim_y[3] = 33;
            stim_x[4] = 44;  stim_y[4] = 44;
            stim_x[5] = 7;   stim_y[5] = 15;
            stim_x[6] = 18;  stim_y[6] = 27;
            stim_x[7] = 2;   stim_y[7] = 2;
            stim_x[8] = 42;  stim_y[8] = 49;
            stim_x[9] = 22;  stim_y[9] = 33;
        end
    end

    // =========================================================================
    // Stimulus Injection (Proper Handshake Protocol)
    // =========================================================================

    integer stim_idx = 0;
    integer inject_credit_ppt = 0;
    integer next_inject_credit_ppt;
    logic inject_enable;
    logic inject_enable_next;

    always_comb begin
        next_inject_credit_ppt = inject_credit_ppt;
        if (stim_idx < stim_count) begin
            next_inject_credit_ppt = next_inject_credit_ppt + INJECT_RATE_PPT;
        end
        if (wr_valid && wr_ready) begin
            next_inject_credit_ppt = next_inject_credit_ppt - 1000;
        end
        if (next_inject_credit_ppt < 0) begin
            next_inject_credit_ppt = 0;
        end

        inject_enable = (stim_idx < stim_count) && (next_inject_credit_ppt >= 1000);
        inject_enable_next = ((stim_idx + 1) < stim_count) && (next_inject_credit_ppt >= 1000);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_valid <= 1'b0;
            wr_data  <= 12'b0;
            stim_idx <= 0;
            syndromes_injected <= 0;
            inject_credit_ppt <= 0;
        end else begin
            inject_credit_ppt <= next_inject_credit_ppt;

            if (!wr_valid && inject_enable) begin
                // Injection-rate pacing controls when a new transfer may start.
                wr_valid <= 1'b1;
                wr_data  <= {stim_y[stim_idx][5:0], stim_x[stim_idx][5:0]};
            end

            if (wr_valid && wr_ready) begin
                // Transfer completed: advance to next and, if credit remains,
                // preload the following item in the same cycle to avoid bubbles.
                syndromes_injected <= syndromes_injected + 1;
                stim_idx <= stim_idx + 1;
                if (inject_enable_next) begin
                    wr_valid <= 1'b1;
                    wr_data  <= {stim_y[stim_idx+1][5:0], stim_x[stim_idx+1][5:0]};
                end else begin
                    wr_valid <= 1'b0;
                end
            end
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
                    worker_coord_x[i] <= issue_coord[5:0];
                    worker_coord_y[i] <= issue_coord[11:6];
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

            // Count stalls: cycles where we have stimulus but can't issue
            if (wr_valid && !issue_valid && stim_idx < stim_count) begin
                stall_count <= stall_count + 1;
            end

            // Count collisions: FSM detected a spatial collision this cycle
            if (collision_detected) begin
                collision_warnings <= collision_warnings + 1;
            end

            // Log dispatch events (LOCK format for verify_collisions.py)
            if (issue_valid && |worker_issue) begin
                issued_count <= issued_count + 1;
                if (dispatch_log_fd != 0) begin
                    // Find which worker was issued
                    for (int i = 0; i < 4; i++) begin
                        if (worker_issue[i]) begin
                            $fwrite(dispatch_log_fd, "%0d LOCK %0d %0d %0d\n",
                                    cycle_count, i, issue_coord[5:0], issue_coord[11:6]);
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
    // Module Instantiation (d=23 variant)
    // =========================================================================

    dispatcher_top_d23 dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .wr_valid       (wr_valid),
        .wr_data        (wr_data),
        .wr_ready       (wr_ready),
        .worker_issue   (worker_issue),
        .issue_coord    (issue_coord),
        .issue_valid    (issue_valid),
        .worker_ready   (worker_ready),
        .worker_done    (worker_done),
        .collision_detected (collision_detected)  // Monitor collisions
    );

    // =========================================================================
    // Test Control: Run until all stimulus processed + dispatcher drained
    // =========================================================================

    initial begin
        integer wait_cycles = 0;
        integer quiet_cycles = 0;
        integer max_wait = 5000;
        integer required_quiet_cycles = 8;

        // Wait for reset
        wait(rst_n);
        @(posedge clk);

        // Open dispatch log for writing
        dispatch_log_fd = $fopen("dispatch_log_d23.txt", "w");
        if (dispatch_log_fd == 0) begin
            $display("[WARNING] Could not open dispatch_log_d23.txt");
        end

        $display("[Stimulus] Injection pacing = %0d ppt (%0.3f syndromes/cycle)",
                 INJECT_RATE_PPT, INJECT_RATE_PPT / 1000.0);
        if (INJECT_RATE_PPT > 1000) begin
            $display("[Stimulus] NOTE: Rates above 1.0 syndromes/cycle saturate at the single-write input interface");
        end

        // Wait for all stimulus to be injected
        wait(stim_idx >= stim_count);
        $display("[Testbench] All %0d syndromes injected at cycle %0d", stim_count, cycle_count);

        // Wait for the dispatcher pipeline to go quiet. This catches
        // syndromes still buffered inside the DUT after stimulus injection ends.
        wait_cycles = 0;
        quiet_cycles = 0;
        while (quiet_cycles < required_quiet_cycles && wait_cycles < max_wait) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;

            if ((wr_valid == 1'b0) &&
                (issue_valid == 1'b0) &&
                (worker_busy == 4'b0000) &&
                (worker_done == 4'b0000)) begin
                quiet_cycles = quiet_cycles + 1;
            end else begin
                quiet_cycles = 0;
            end
        end

        if (wait_cycles >= max_wait) begin
            $warning("[Testbench] Timeout waiting for dispatcher pipeline to drain");
        end

        // Close dispatch log
        if (dispatch_log_fd != 0) begin
            $fclose(dispatch_log_fd);
            $display("[Testbench] Dispatch log written to dispatch_log_d23.txt");
        end

        // Final report
        $display("\n");
        $display("================================================");
        $display("DISPATCHER INTEGRATION TEST RESULTS (d=23)");
        $display("================================================");
        $display("Total Cycles:        %0d", cycle_count);
        $display("Syndromes Issued:    %0d", issued_count);
        $display("Syndromes Stalled:   %0d", stall_count);
        $display("Collisions Detected: %0d", collision_warnings);
        $display("Completion status:   %s",
                 (quiet_cycles >= required_quiet_cycles) ? "ALL WORKERS DONE" : "TIMEOUT");
        $display("================================================");
        $display("Expected: collision verification via verify_collisions.py");
        $display("================================================\n");

        // Finish simulation
        #100;
        $finish;
    end

endmodule
