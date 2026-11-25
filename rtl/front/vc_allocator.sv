
module vc_allocator
  import noc_pkg::*;
#(
    parameter int unsigned NUM_VCS = DEF_NUM_VCS
) (
    input  logic clk,
    input  logic rst_n,

    // Requests from each input port / input VC
    input  logic [NUM_PORTS-1:0][NUM_VCS-1:0] va_req,
    input  logic [NUM_PORTS-1:0][NUM_VCS-1:0][PORT_W-1:0] va_out_port,

    // Release when the final flit leaves the allocated VC
    input  logic [NUM_PORTS-1:0][NUM_VCS-1:0] va_release,

    // Allocation response to input_port
    output logic [NUM_PORTS-1:0][NUM_VCS-1:0] va_grant,
    output logic [NUM_PORTS-1:0][NUM_VCS-1:0][vc_w(NUM_VCS)-1:0] va_out_vc,

    // One means the output VC is available
    output logic [NUM_PORTS-1:0][NUM_VCS-1:0] ovc_free
);

    localparam int unsigned VC_W  = vc_w(NUM_VCS);
    localparam int unsigned N_REQ = NUM_PORTS * NUM_VCS;
    localparam int unsigned IDX_W = (N_REQ > 1) ? $clog2(N_REQ) : 1;

    // ------------------------------------------------------------
    // Ownership state
    // ------------------------------------------------------------

    logic [NUM_VCS-1:0] busy_q [NUM_PORTS];

    logic map_valid_q [NUM_PORTS][NUM_VCS];
    logic [PORT_W-1:0] map_port_q [NUM_PORTS][NUM_VCS];
    logic [VC_W-1:0] map_vc_q [NUM_PORTS][NUM_VCS];

    // ------------------------------------------------------------
    // Arbitration signals
    // ------------------------------------------------------------

    logic [N_REQ-1:0] base_req [NUM_PORTS];
    logic [N_REQ-1:0] arb_req [NUM_PORTS][NUM_VCS];

    logic [N_REQ-1:0] candidate_grant [NUM_PORTS][NUM_VCS];
    logic [N_REQ-1:0] accepted_grant [NUM_PORTS][NUM_VCS];

    logic [IDX_W-1:0] candidate_idx [NUM_PORTS][NUM_VCS];
    logic candidate_vld [NUM_PORTS][NUM_VCS];
    logic accepted_vld [NUM_PORTS][NUM_VCS];

    // ------------------------------------------------------------
    // Build request vectors and filter unavailable output VCs
    // ------------------------------------------------------------

    always_comb begin
        for (int unsigned o = 0; o < NUM_PORTS; o++) begin
            base_req[o] = '0;

            for (int unsigned p = 0; p < NUM_PORTS; p++) begin
                for (int unsigned v = 0; v < NUM_VCS; v++) begin
                    if (va_req[p][v] &&
                        !map_valid_q[p][v] &&
                        (va_out_port[p][v] == PORT_W'(o))) begin

                        base_req[o][(p * NUM_VCS) + v] = 1'b1;
                    end
                end
            end

            for (int unsigned ov = 0; ov < NUM_VCS; ov++) begin
                if (busy_q[o][ov]) begin
                    arb_req[o][ov] = '0;
                end else begin
                    arb_req[o][ov] = base_req[o];
                end
            end
        end
    end

    // ------------------------------------------------------------
    // One round-robin arbiter per output VC
    // ------------------------------------------------------------

    for (genvar o = 0; o < NUM_PORTS; o++) begin : g_output_port
        for (genvar ov = 0; ov < NUM_VCS; ov++) begin : g_output_vc

            rr_arbiter #(
                .N     (N_REQ),
                .IDX_W (IDX_W)
            ) u_rr_arbiter (
                .clk       (clk),
                .rst_n     (rst_n),
                .req       (arb_req[o][ov]),
                .en        (accepted_vld[o][ov]),
                .grant     (candidate_grant[o][ov]),
                .grant_idx (candidate_idx[o][ov]),
                .grant_vld (candidate_vld[o][ov])
            );

        end
    end

    // ------------------------------------------------------------
    // Prevent one input VC from receiving multiple output VC grants
    //
    // Output VC 0 has priority over output VC 1, etc.
    // Only accepted grants advance their round-robin pointer.
    // ------------------------------------------------------------

    always_comb begin
        for (int unsigned o = 0; o < NUM_PORTS; o++) begin
            logic [N_REQ-1:0] claimed;

            claimed = '0;

            for (int unsigned ov = 0; ov < NUM_VCS; ov++) begin
                accepted_grant[o][ov] =
                    candidate_grant[o][ov] & ~claimed;

                accepted_vld[o][ov] =
                    candidate_vld[o][ov] &&
                    (int'(candidate_idx[o][ov]) < N_REQ) &&
                    (|accepted_grant[o][ov]);

                claimed = claimed | accepted_grant[o][ov];
            end
        end
    end

    // ------------------------------------------------------------
    // Convert accepted grants back to input-port / input-VC outputs
    // ------------------------------------------------------------

    always_comb begin
        va_grant  = '0;
        va_out_vc = '0;

        for (int unsigned o = 0; o < NUM_PORTS; o++) begin
            for (int unsigned ov = 0; ov < NUM_VCS; ov++) begin
                for (int unsigned p = 0; p < NUM_PORTS; p++) begin
                    for (int unsigned v = 0; v < NUM_VCS; v++) begin

                        if (accepted_grant[o][ov][(p * NUM_VCS) + v]) begin
                            va_grant[p][v]  = 1'b1;
                            va_out_vc[p][v] = VC_W'(ov);
                        end

                    end
                end
            end
        end
    end

    // ------------------------------------------------------------
    // Output VC availability
    // ------------------------------------------------------------

    always_comb begin
        for (int unsigned o = 0; o < NUM_PORTS; o++) begin
            for (int unsigned ov = 0; ov < NUM_VCS; ov++) begin
                ovc_free[o][ov] = !busy_q[o][ov];
            end
        end
    end

    // ------------------------------------------------------------
    // Ownership update
    //
    // Release and allocation use pre-edge busy state.
    // A VC released on this edge becomes available next cycle.
    // ------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (!rst_n) begin

            for (int unsigned o = 0; o < NUM_PORTS; o++) begin
                busy_q[o] <= '0;

                for (int unsigned ov = 0; ov < NUM_VCS; ov++) begin
                    map_valid_q[o][ov] <= 1'b0;
                    map_port_q[o][ov]  <= '0;
                    map_vc_q[o][ov]    <= '0;
                end
            end

        end else begin

            // Release previously allocated output VCs
            for (int unsigned p = 0; p < NUM_PORTS; p++) begin
                for (int unsigned v = 0; v < NUM_VCS; v++) begin

                    if (va_release[p][v] && map_valid_q[p][v]) begin
                        busy_q[map_port_q[p][v]][map_vc_q[p][v]] <= 1'b0;
                        map_valid_q[p][v] <= 1'b0;
                    end

                end
            end

            // Record newly accepted allocations
            for (int unsigned o = 0; o < NUM_PORTS; o++) begin
                for (int unsigned ov = 0; ov < NUM_VCS; ov++) begin
                    for (int unsigned p = 0; p < NUM_PORTS; p++) begin
                        for (int unsigned v = 0; v < NUM_VCS; v++) begin

                            if (accepted_grant[o][ov][(p * NUM_VCS) + v]) begin
                                busy_q[o][ov] <= 1'b1;

                                map_valid_q[p][v] <= 1'b1;
                                map_port_q[p][v]  <= PORT_W'(o);
                                map_vc_q[p][v]    <= VC_W'(ov);
                            end

                        end
                    end
                end
            end

        end
    end

endmodule
