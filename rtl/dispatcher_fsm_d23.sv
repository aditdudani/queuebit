`ifndef DISPATCHER_FSM_D23_SV
`define DISPATCHER_FSM_D23_SV

`timescale 1ns/1ps

module dispatcher_fsm_d23 #(
    parameter bit ENABLE_COLLISION_CHECK = 1'b1  // Set to 0 for naive variant
) (
    input  logic                            clk,
    input  logic                            rst_n,

    // FIFO interface
    input  logic                            fifo_rd_valid,
    output logic                            fifo_rd_ready,
    input  logic [5:0]                      fifo_rd_x,
    input  logic [5:0]                      fifo_rd_y,

    // Tracking matrix interface
    output logic                            matrix_check_en,
    output logic [5:0]                      matrix_check_x,
    output logic [5:0]                      matrix_check_y,
    input  logic                            matrix_collision,

    output logic                            matrix_lock_en,
    output logic [5:0]                      matrix_lock_x,
    output logic [5:0]                      matrix_lock_y,

    output logic                            matrix_release_en,
    output logic [5:0]                      matrix_release_x,
    output logic [5:0]                      matrix_release_y,

    // Worker interface
    input  logic [3:0]                      worker_ready,   // mask: which workers are idle
    input  logic [3:0]                      worker_done,    // triggers: workers finishing (one-hot)

    output logic [3:0]                      worker_issue,   // one-hot: assign to worker[i]
    output logic [11:0]                     dispatch_coord, // 6-bit x + 6-bit y
    output logic                            dispatch_valid,
    output logic                            collision_detected  // strobe: collision was detected this cycle
);

    import dispatcher_pkg::*;

    // Registers for FSM state and latched syndrome data
    logic [5:0] latched_x, latched_y;

    // Track if a release was just triggered (holds for 2 cycles to let matrix clear)
    logic [1:0] release_wait_counter;  // 0=no wait, 1-2=wait cycles

    // Current and next state
    fsm_state_e current_state, next_state;

    // =========================================================================
    // Combinatorial State Machine Logic
    // =========================================================================

    always_comb begin
        // Default outputs
        fifo_rd_ready        = 1'b0;
        matrix_check_en      = 1'b0;
        matrix_check_x       = 6'bx;
        matrix_check_y       = 6'bx;
        matrix_lock_en       = 1'b0;
        matrix_lock_x        = 6'bx;
        matrix_lock_y        = 6'bx;
        matrix_release_en    = 1'b0;
        matrix_release_x     = 6'bx;
        matrix_release_y     = 6'bx;
        dispatch_valid       = 1'b0;
        worker_issue         = 4'b0000;
        dispatch_coord       = 12'bx;
        collision_detected   = 1'b0;  // Default: no collision this cycle
        next_state           = current_state;

        case (current_state)

            // IDLE: Wait for FIFO to have data, then pop and move to hazard check
            FSM_IDLE: begin
                if (fifo_rd_valid) begin
                    fifo_rd_ready = 1'b1;  // Pop syndrome from FIFO
                    next_state = FSM_HAZARD_CHK;
                end
            end

            // HAZARD_CHK: Check for collision at latched coordinates
            FSM_HAZARD_CHK: begin
                // In standard mode, perform collision check; in naive mode, skip directly to ISSUE
                if (ENABLE_COLLISION_CHECK) begin
                    matrix_check_en = 1'b1;
                    matrix_check_x  = latched_x;
                    matrix_check_y  = latched_y;

                    if (matrix_collision) begin
                        // Collision detected: wait for worker to complete
                        collision_detected = 1'b1;  // <-- COUNT THIS COLLISION EVENT
                        next_state = FSM_STALL;
                    end else begin
                        // No collision: proceed to issue
                        next_state = FSM_ISSUE;
                    end
                end else begin
                    // Naive mode: skip collision check, proceed directly to ISSUE
                    next_state = FSM_ISSUE;
                end
            end

            // ISSUE: Assign to available worker and lock matrix
            FSM_ISSUE: begin
                if (worker_ready != 4'b0000) begin
                    // Find first available worker using case statement
                    casez (worker_ready)
                        4'b???1: worker_issue = 4'b0001;  // Worker 0
                        4'b??10: worker_issue = 4'b0010;  // Worker 1
                        4'b?100: worker_issue = 4'b0100;  // Worker 2
                        4'b1000: worker_issue = 4'b1000;  // Worker 3
                        default: worker_issue = 4'b0000;
                    endcase

                    // Lock the 3x3 region
                    matrix_lock_en  = 1'b1;
                    matrix_lock_x   = latched_x;
                    matrix_lock_y   = latched_y;

                    // Dispatch syndrome
                    dispatch_valid  = 1'b1;
                    dispatch_coord  = {latched_y, latched_x};

                    // Try to pop next syndrome and loop back to HAZARD_CHK
                    if (fifo_rd_valid) begin
                        fifo_rd_ready = 1'b1;  // Pop the next syndrome
                        next_state = FSM_HAZARD_CHK;
                    end else begin
                        // No more syndromes: return to IDLE
                        next_state = FSM_IDLE;
                    end
                end else begin
                    // All workers busy: stall until one finishes
                    next_state = FSM_STALL;
                end
            end

            // STALL: Wait for ANY worker completion, then re-check collision
            // Must wait 2+ cycles for matrix release to propagate through sequential logic
            FSM_STALL: begin
                // Release wait counter tracks how many cycles to wait after worker_done
                if (release_wait_counter > 0) begin
                    // Still counting down from a worker completion
                    next_state = FSM_STALL;  // Stay in STALL until counter reaches 0
                end else if (worker_done != 4'b0000) begin
                    // Worker just completed, start the wait countdown
                    next_state = FSM_STALL;  // Stay, increment counter on next edge
                end else begin
                    // No active release and no worker done: re-check collision
                    next_state = FSM_HAZARD_CHK;
                end
            end

            default: begin
                next_state = FSM_IDLE;
            end

        endcase
    end

    // =========================================================================
    // Sequential Logic: State Register and Data Latching
    // =========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= FSM_IDLE;
            latched_x     <= 6'b0;
            latched_y     <= 6'b0;
            release_wait_counter <= 2'b0;
        end else begin
            current_state <= next_state;

            // Latch syndrome coordinates whenever we pop from FIFO
            if ((current_state == FSM_IDLE && next_state == FSM_HAZARD_CHK) ||
                (current_state == FSM_ISSUE && next_state == FSM_HAZARD_CHK)) begin
                latched_x <= fifo_rd_x;
                latched_y <= fifo_rd_y;
            end

            // Manage release wait counter
            // When worker_done is detected in STALL, set counter to 2 to wait for matrix to clear
            if (current_state == FSM_STALL && worker_done != 4'b0000 && release_wait_counter == 0) begin
                release_wait_counter <= 2'd2;  // Wait 2 cycles for sequential release logic
            end else if (release_wait_counter > 0) begin
                release_wait_counter <= release_wait_counter - 1;
            end
        end
    end

    // =========================================================================
    // Release Logic (for Top-Level Use)
    // =========================================================================
    //
    // NOTE: The FSM itself does NOT handle matrix releases when workers complete.
    // Instead, the top-level dispatcher tracks per-worker coordinates and issues
    // release commands to the matrix independently of FSM state transitions.
    // The FSM only generates the STALL signal when workers are busy and collision
    // is detected, forcing re-evaluation when worker_done signals arrive.

    // =========================================================================
    // Assertions
    // =========================================================================

    // synthesis translate_off
    always @(posedge clk) begin
        if (rst_n) begin
            // Log state transitions and key signals
            if (current_state != next_state) begin
                $display("[FSM d23] Cycle %0d: %s → %s (fifo_valid=%0b, collision=%0b, workers_ready=%b)",
                         $time / 10,
                         current_state.name(),
                         next_state.name(),
                         fifo_rd_valid,
                         matrix_collision,
                         worker_ready);
            end

            // Log collision checks
            if (matrix_check_en) begin
                $display("[FSM d23] Collision check: (%0d,%0d) → collision=%0b",
                         matrix_check_x, matrix_check_y, matrix_collision);
            end

            // Log lock operations
            if (matrix_lock_en) begin
                $display("[FSM d23] Lock issued: (%0d,%0d) → dispatch to worker", matrix_lock_x, matrix_lock_y);
            end

            // Ensure only one worker gets issued per cycle
            if ($countones(worker_issue) > 1) begin
                $error("FSM: Multiple workers issued in same cycle!");
            end
        end
    end
    // synthesis translate_on

endmodule

`endif
