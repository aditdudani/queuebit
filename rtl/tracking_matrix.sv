`ifndef TRACKING_MATRIX_SV
`define TRACKING_MATRIX_SV

`timescale 1ns/1ps

module tracking_matrix #(
    parameter int COORD_WIDTH  = 5,
    parameter int GRID_WIDTH   = 21,
    parameter int GRID_HEIGHT  = 23
) (
    input  logic                        clk,
    input  logic                        rst_n,

    // Collision check port (combinatorial read)
    input  logic [COORD_WIDTH-1:0]      check_x,
    input  logic [COORD_WIDTH-1:0]      check_y,
    output logic [8:0]                  neighborhood,
    output logic                        collision,

    // Lock port (synchronous - sets 3x3 region to 1)
    input  logic                        lock_en,
    input  logic [COORD_WIDTH-1:0]      lock_x,
    input  logic [COORD_WIDTH-1:0]      lock_y,

    // Release port (synchronous - clears 3x3 region to 0)
    input  logic                        release_en,
    input  logic [COORD_WIDTH-1:0]      release_x,
    input  logic [COORD_WIDTH-1:0]      release_y
);

    // 2D register array for the grid
    logic matrix [GRID_HEIGHT][GRID_WIDTH];

    // Pre-computed neighbor indices (wires ensure constant width)
    wire [COORD_WIDTH-1:0] xm1 = check_x - 1;  // x minus 1
    wire [COORD_WIDTH-1:0] xp1 = check_x + 1;  // x plus 1
    wire [COORD_WIDTH-1:0] ym1 = check_y - 1;  // y minus 1
    wire [COORD_WIDTH-1:0] yp1 = check_y + 1;  // y plus 1

    // Bounds checking flags
    // For x-1: need x > 0 (no underflow) AND x-1 < GRID_WIDTH (always true if x <= GRID_WIDTH)
    wire xm1_valid = (check_x > 0) && (check_x <= GRID_WIDTH);
    wire x_valid   = (check_x < GRID_WIDTH);
    wire xp1_valid = (check_x < GRID_WIDTH - 1);  // x+1 < GRID_WIDTH

    // For y-1: need y > 0 (no underflow) AND y-1 < GRID_HEIGHT (i.e., y <= GRID_HEIGHT)
    wire ym1_valid = (check_y > 0) && (check_y <= GRID_HEIGHT);
    wire y_valid   = (check_y < GRID_HEIGHT);
    wire yp1_valid = (check_y < GRID_HEIGHT - 1); // y+1 < GRID_HEIGHT

    // Intermediate signals for array indexing (workaround for xsim variable-index issues)
    logic [4:0] lx, ly;
    logic [4:0] rx, ry;

    always_comb begin
        lx = lock_x;
        ly = lock_y;
        rx = release_x;
        ry = release_y;
    end

    // Combinatorial 3x3 neighborhood read with boundary checking
    // Bit layout:
    //   +---+---+---+
    //   | 0 | 1 | 2 |   y-1
    //   +---+---+---+
    //   | 3 | 4 | 5 |   y (center)
    //   +---+---+---+
    //   | 6 | 7 | 8 |   y+1
    //   +---+---+---+
    //   x-1  x  x+1

    // Row y-1
    assign neighborhood[0] = (xm1_valid && ym1_valid) ? matrix[ym1][xm1] : 1'b0;
    assign neighborhood[1] = (x_valid && ym1_valid) ? matrix[ym1][check_x] : 1'b0;
    assign neighborhood[2] = (xp1_valid && ym1_valid) ? matrix[ym1][xp1] : 1'b0;

    // Row y (center row)
    assign neighborhood[3] = (xm1_valid && y_valid) ? matrix[check_y][xm1] : 1'b0;
    assign neighborhood[4] = (x_valid && y_valid) ? matrix[check_y][check_x] : 1'b0;
    assign neighborhood[5] = (xp1_valid && y_valid) ? matrix[check_y][xp1] : 1'b0;

    // Row y+1
    assign neighborhood[6] = (xm1_valid && yp1_valid) ? matrix[yp1][xm1] : 1'b0;
    assign neighborhood[7] = (x_valid && yp1_valid) ? matrix[yp1][check_x] : 1'b0;
    assign neighborhood[8] = (xp1_valid && yp1_valid) ? matrix[yp1][xp1] : 1'b0;

    // Collision if any cell in the 3x3 region is locked
    assign collision = |neighborhood;

    // Synchronous write logic - ATOMIC 3x3 operations
    integer dy, dx;
    integer nx, ny;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Clear all cells on reset
            for (dy = 0; dy < GRID_HEIGHT; dy = dy + 1) begin
                for (dx = 0; dx < GRID_WIDTH; dx = dx + 1) begin
                    matrix[dy][dx] <= 1'b0;
                end
            end
        end else begin
            // Release: clear entire 3x3 region (lower priority)
            if (release_en) begin
                for (dy = -1; dy <= 1; dy = dy + 1) begin
                    for (dx = -1; dx <= 1; dx = dx + 1) begin
                        nx = release_x + dx;
                        ny = release_y + dy;
                        if (nx >= 0 && nx < GRID_WIDTH && ny >= 0 && ny < GRID_HEIGHT) begin
                            matrix[ny][nx] <= 1'b0;
                        end
                    end
                end
            end

            // Lock: set entire 3x3 region (higher priority - wins on conflict)
            if (lock_en) begin
                for (dy = -1; dy <= 1; dy = dy + 1) begin
                    for (dx = -1; dx <= 1; dx = dx + 1) begin
                        nx = lock_x + dx;
                        ny = lock_y + dy;
                        if (nx >= 0 && nx < GRID_WIDTH && ny >= 0 && ny < GRID_HEIGHT) begin
                            matrix[ny][nx] <= 1'b1;
                        end
                    end
                end
            end
        end
    end

    // Assertions for simulation
    // synthesis translate_off
    always @(posedge clk) begin
        if (rst_n) begin
            // Log lock operations
            if (lock_en) begin
                $display("[MATRIX] Lock at (%0d, %0d) - cells set: (%0d-%0d, %0d-%0d)",
                         lock_x, lock_y,
                         (lock_x > 0 ? lock_x-1 : 0), (lock_x < GRID_WIDTH-1 ? lock_x+1 : GRID_WIDTH-1),
                         (lock_y > 0 ? lock_y-1 : 0), (lock_y < GRID_HEIGHT-1 ? lock_y+1 : GRID_HEIGHT-1));
            end

            // Log release operations
            if (release_en) begin
                $display("[MATRIX] Release at (%0d, %0d) - cells cleared: (%0d-%0d, %0d-%0d)",
                         release_x, release_y,
                         (release_x > 0 ? release_x-1 : 0), (release_x < GRID_WIDTH-1 ? release_x+1 : GRID_WIDTH-1),
                         (release_y > 0 ? release_y-1 : 0), (release_y < GRID_HEIGHT-1 ? release_y+1 : GRID_HEIGHT-1));
            end

            // Check for both lock and release same cycle (lock wins)
            if (lock_en && release_en) begin
                $warning("[MATRIX] Both LOCK and RELEASE asserted same cycle - lock takes priority!");
            end

            if (lock_en && (lock_x >= GRID_WIDTH || lock_y >= GRID_HEIGHT))
                $error("MATRIX: Lock coordinate out of range: (%0d, %0d)", lock_x, lock_y);
            if (release_en && (release_x >= GRID_WIDTH || release_y >= GRID_HEIGHT))
                $error("MATRIX: Release coordinate out of range: (%0d, %0d)", release_x, release_y);
        end
    end
    // synthesis translate_on

endmodule

`endif
