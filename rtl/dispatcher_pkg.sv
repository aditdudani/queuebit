`ifndef DISPATCHER_PKG_SV
`define DISPATCHER_PKG_SV

`timescale 1ns/1ps

package dispatcher_pkg;

    // Feature control: enable/disable collision detection
    // Set to 0 for naive variant (testing collision avoidance value)
    parameter bit ENABLE_COLLISION_CHECK = 1'b1;

    // Grid parameters derived from d=11 surface code
    parameter int CODE_DISTANCE = 11;
    parameter int GRID_WIDTH    = 21;   // X range [0, 20]
    parameter int GRID_HEIGHT   = 23;   // Y range [0, 22]

    // Derived parameters
    parameter int COORD_WIDTH   = 5;    // ceil(log2(23)) = 5 bits
    parameter int FIFO_DEPTH    = 32;
    parameter int NUM_WORKERS   = 4;
    parameter int WORKER_ID_W   = 2;    // ceil(log2(4)) = 2 bits

    // FSM state encoding
    typedef enum logic [2:0] {
        FSM_IDLE        = 3'b000,
        FSM_FETCH       = 3'b001,
        FSM_HAZARD_CHK  = 3'b010,
        FSM_ISSUE       = 3'b011,
        FSM_STALL       = 3'b100
    } fsm_state_e;

    // Syndrome coordinate type
    typedef struct packed {
        logic [COORD_WIDTH-1:0] x;
        logic [COORD_WIDTH-1:0] y;
    } coord_t;

endpackage

`endif
