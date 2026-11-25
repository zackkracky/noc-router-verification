`default_nettype none

module input_port
  import noc_pkg::*;
#(
    parameter int unsigned FLIT_WIDTH    = DEF_FLIT_WIDTH,
    parameter int unsigned NUM_VCS       = DEF_NUM_VCS,
    parameter int unsigned BUFFER_DEPTH  = DEF_BUFFER_DEPTH,
    parameter int unsigned X_COORD       = 0,
    parameter int unsigned Y_COORD       = 0,
    parameter string       ROUTE_ALGO    = "XY",
    parameter int unsigned IN_PORT       = LOCAL,

    localparam int unsigned VC_W  = vc_w(NUM_VCS),
    localparam int unsigned CNT_W = cnt_w(BUFFER_DEPTH)
) (
    input  wire logic clk,
    input  wire logic rst_n,

    // Incoming link
    input  wire logic [FLIT_WIDTH-1:0] in_flit,
    input  wire logic                  in_flit_valid,
    input  wire logic [VC_W-1:0]       in_flit_vc,

    // Output credits: indexed [output_port][output_vc]
    input  wire logic [NUM_PORTS-1:0][NUM_VCS-1:0]
                       ocredit_avail,
    input  wire logic [NUM_PORTS-1:0][NUM_VCS-1:0][CNT_W-1:0]
                       ocredit_count,

    // VC allocator handshake: indexed [input_vc]
    output logic [NUM_VCS-1:0]              va_req,
    output logic [NUM_VCS-1:0][PORT_W-1:0]  va_out_port,
    input  wire logic [NUM_VCS-1:0]         va_grant,
    input  wire logic [NUM_VCS-1:0][VC_W-1:0] va_out_vc,
    output logic [NUM_VCS-1:0]              va_release,

    // Switch allocator interface: indexed [input_vc]
    output logic [NUM_VCS-1:0]              sa_req,
    output logic [NUM_VCS-1:0][PORT_W-1:0]  sa_out_port,
    output logic [NUM_VCS-1:0][VC_W-1:0]    sa_out_vc,
    output logic [NUM_VCS-1:0][FLIT_WIDTH-1:0] sa_flit,
    input  wire logic [NUM_VCS-1:0]         sa_grant,

    // Registered upstream credit return
    output logic                            in_credit_valid,
    output logic [VC_W-1:0]                 in_credit_vc
);

    localparam int unsigned NORTH = 0;
    localparam int unsigned EAST  = 1;
    localparam int unsigned SOUTH = 2;
    localparam int unsigned WEST  = 3;
    localparam int unsigned LOCAL = 4;

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_ROUTING,
        ST_WAIT_VC,
        ST_ACTIVE
    } state_t;

    state_t state [NUM_VCS];

    logic [NUM_VCS-1:0] fifo_wr_valid;
    logic [NUM_VCS-1:0] fifo_rd_valid;
    logic [NUM_VCS-1:0] fifo_rd_ready;
    logic [NUM_VCS-1:0] fifo_credit_out;

    logic [NUM_VCS-1:0][FLIT_WIDTH-1:0] fifo_rd_data;
    logic [NUM_VCS-1:0][CNT_W-1:0] fifo_count;
    logic [NUM_VCS-1:0] fifo_full;
    logic [NUM_VCS-1:0] fifo_empty;
    logic unused_fifo_status;

    logic [NUM_VCS-1:0][NUM_PORTS-1:0] route_onehot;
    logic [NUM_VCS-1:0][PORT_W-1:0] held_out_port;
    logic [NUM_VCS-1:0][VC_W-1:0] held_out_vc;

    logic [NUM_VCS-1:0] dequeue;
    logic [1:0] head_ftype [NUM_VCS];

    assign unused_fifo_status = ^{fifo_count, fifo_full, fifo_empty};

    // ------------------------------------------------------------
    // Input VC FIFOs
    // ------------------------------------------------------------

    always_comb begin
        fifo_wr_valid = '0;

        for (int unsigned v = 0; v < NUM_VCS; v++) begin
            if (in_flit_valid && (in_flit_vc == VC_W'(v))) begin
                fifo_wr_valid[v] = 1'b1;
            end
        end
    end

    for (genvar v = 0; v < NUM_VCS; v++) begin : g_input_fifo

        input_fifo #(
            .WIDTH (FLIT_WIDTH),
            .DEPTH (BUFFER_DEPTH)
        ) u_input_fifo (
            .clk        (clk),
            .rst_n      (rst_n),
            .wr_valid   (fifo_wr_valid[v]),
            .wr_data    (in_flit),
            .rd_ready   (fifo_rd_ready[v]),
            .rd_valid   (fifo_rd_valid[v]),
            .rd_data    (fifo_rd_data[v]),
            .count      (fifo_count[v]),
            .full       (fifo_full[v]),
            .empty      (fifo_empty[v]),
            .credit_out (fifo_credit_out[v])
        );

        route_unit #(
            .ROUTE_ALGO   (ROUTE_ALGO),
            .X_COORD      (X_COORD),
            .Y_COORD      (Y_COORD),
            .NUM_VCS      (NUM_VCS),
            .BUFFER_DEPTH (BUFFER_DEPTH)
        ) u_route_unit (
            .dst_x (
                fifo_rd_data[v][FLIT_WIDTH-3 -: COORD_W]
            ),
            .dst_y (
                fifo_rd_data[v][FLIT_WIDTH-6 -: COORD_W]
            ),
            .in_port         (PORT_W'(IN_PORT)),
            .route_credit    (ocredit_count),
            .out_port_onehot (route_onehot[v])
        );

    end

    // ------------------------------------------------------------
    // Decode route and expose allocator/switch signals
    // ------------------------------------------------------------

    always_comb begin
        va_req      = '0;
        va_out_port = '0;
        va_release  = '0;

        sa_req      = '0;
        sa_out_port = '0;
        sa_out_vc   = '0;
        sa_flit     = '0;

        fifo_rd_ready = '0;
        dequeue       = '0;

        for (int unsigned v = 0; v < NUM_VCS; v++) begin

            head_ftype[v] = fifo_rd_data[v][FLIT_WIDTH-1 -: FTYPE_W];

            sa_flit[v]     = fifo_rd_data[v];
            sa_out_port[v] = held_out_port[v];
            sa_out_vc[v]   = held_out_vc[v];

            va_out_port[v] = held_out_port[v];

            // Request an output VC only while waiting for allocation.
            if ((state[v] == ST_WAIT_VC) &&
                fifo_rd_valid[v] &&
                ((head_ftype[v] == HEAD) ||
                 (head_ftype[v] == HEAD_TAIL))) begin
                va_req[v] = 1'b1;
            end

            // Request switch traversal only when output VC has credit.
            if ((state[v] == ST_ACTIVE) &&
                fifo_rd_valid[v] &&
                ocredit_avail[held_out_port[v]][held_out_vc[v]]) begin
                sa_req[v] = 1'b1;
            end

            // Only a final switch grant dequeues a flit.
            fifo_rd_ready[v] = (state[v] == ST_ACTIVE) && sa_grant[v];
            dequeue[v] = fifo_rd_ready[v] && fifo_rd_valid[v];

            // Release output VC ownership on the final flit.
            if (dequeue[v] &&
                ((head_ftype[v] == TAIL) ||
                 (head_ftype[v] == HEAD_TAIL))) begin
                va_release[v] = 1'b1;
            end
        end
    end

    // ------------------------------------------------------------
    // Per-VC routing and allocation state machines
    // ------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int unsigned v = 0; v < NUM_VCS; v++) begin
                state[v]         <= ST_IDLE;
                held_out_port[v] <= '0;
                held_out_vc[v]   <= '0;
            end
        end
        else begin
            for (int unsigned v = 0; v < NUM_VCS; v++) begin

                case (state[v])

                    ST_IDLE: begin
                        if (fifo_rd_valid[v] &&
                            ((head_ftype[v] == HEAD) ||
                             (head_ftype[v] == HEAD_TAIL))) begin
                            state[v] <= ST_ROUTING;
                        end
                    end

                    // Route must be a valid one-hot value.
                    // Invalid routes remain in ST_ROUTING.
                    ST_ROUTING: begin
                        case (route_onehot[v])
                            5'b00001: begin
                                held_out_port[v] <= PORT_W'(NORTH);
                                state[v] <= ST_WAIT_VC;
                            end

                            5'b00010: begin
                                held_out_port[v] <= PORT_W'(EAST);
                                state[v] <= ST_WAIT_VC;
                            end

                            5'b00100: begin
                                held_out_port[v] <= PORT_W'(SOUTH);
                                state[v] <= ST_WAIT_VC;
                            end

                            5'b01000: begin
                                held_out_port[v] <= PORT_W'(WEST);
                                state[v] <= ST_WAIT_VC;
                            end

                            5'b10000: begin
                                held_out_port[v] <= PORT_W'(LOCAL);
                                state[v] <= ST_WAIT_VC;
                            end

                            default: begin
                                // Invalid route: remain in ST_ROUTING.
                            end
                        endcase
                    end

                    ST_WAIT_VC: begin
                        if (va_grant[v]) begin
                            held_out_vc[v] <= va_out_vc[v];
                            state[v]       <= ST_ACTIVE;
                        end
                    end

                    ST_ACTIVE: begin
                        if (dequeue[v] &&
                            ((head_ftype[v] == TAIL) ||
                             (head_ftype[v] == HEAD_TAIL))) begin
                            state[v] <= ST_IDLE;
                        end
                    end

                    default: begin
                        state[v] <= ST_IDLE;
                    end

                endcase
            end
        end
    end

    // ------------------------------------------------------------
    // Registered upstream credit return
    // ------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            in_credit_valid <= 1'b0;
            in_credit_vc    <= '0;
        end
        else begin
            in_credit_valid <= 1'b0;

            // switch_allocator guarantees at most one final grant
            // per physical input port per cycle.
            for (int unsigned v = 0; v < NUM_VCS; v++) begin
                if (fifo_credit_out[v]) begin
                    in_credit_valid <= 1'b1;
                    in_credit_vc    <= VC_W'(v);
                end
            end
        end
    end

endmodule

`default_nettype wire
