// switch_allocator: separable input-first switch allocation (INTERFACE.md s7, s7.2); sa_req/sa_out_port[p][v] in, sa_grant[p][v] + xbar_sel[o][p] + issue[o] out, all combinational
`default_nettype none

module switch_allocator
  import noc_pkg::*;
#(
  parameter int unsigned NUM_VCS = DEF_NUM_VCS
) (
  input  logic                                          clk,
  input  logic                                          rst_n,        // sync, active-low (s8)
  input  logic [NUM_PORTS-1:0][NUM_VCS-1:0]             sa_req,       // ACTIVE && !empty && ocredit_avail; must not depend on a grant (s7)
  input  logic [NUM_PORTS-1:0][NUM_VCS-1:0][PORT_W-1:0] sa_out_port,  // held encoded route, port_e; caller guarantees < NUM_PORTS
  output logic [NUM_PORTS-1:0][NUM_VCS-1:0]             sa_grant,     // final grant: input FIFO dequeues this VC at this edge; onehot0 per input
  output logic [NUM_PORTS-1:0][NUM_PORTS-1:0]           xbar_sel,     // [o][p] crossbar select, onehot0 per output
  output logic [NUM_PORTS-1:0]                          issue         // |xbar_sel[o]: output register load and credit debit
);

  localparam int unsigned VC_IW = vc_w(NUM_VCS);                      // stage-1 rr_arbiter IDX_W
  localparam int unsigned P_IW  = $clog2(NUM_PORTS);                  // stage-2 rr_arbiter IDX_W

  logic [NUM_PORTS-1:0][NUM_VCS-1:0]   s1_pick;                       // stage-1 VC pick per input, onehot0
  logic [NUM_PORTS-1:0][VC_IW-1:0]     s1_pick_idx;
  logic [NUM_PORTS-1:0]                s1_pick_vld;
  logic [NUM_PORTS-1:0][PORT_W-1:0]    s1_pick_port;                  // output the stage-1 pick is routed to
  logic [NUM_PORTS-1:0][NUM_PORTS-1:0] s2_req;                        // [o][p] stage-2 requests
  logic [NUM_PORTS-1:0][NUM_PORTS-1:0] xbar_sel_t;                    // [p][o] transpose of xbar_sel
  logic [NUM_PORTS-1:0]                in_won;                        // input p won stage 2 at some output

  // Stage 1: one NUM_VCS-way arbiter per input picks at most one requesting VC.
  // Its pointer rotates only on a final grant, so losing stage 2 re-offers the same VC (s7, s7.2).
  for (genvar p = 0; p < NUM_PORTS; p++) begin : g_in
    rr_arbiter #(.N(NUM_VCS)) u_s1 (
      .clk       (clk),
      .rst_n     (rst_n),
      .req       (sa_req[p]),
      .en        (in_won[p]),                                         // == |sa_grant[p]
      .grant     (s1_pick[p]),
      .grant_idx (s1_pick_idx[p]),
      .grant_vld (s1_pick_vld[p])
    );

    assign s1_pick_port[p] = sa_out_port[p][s1_pick_idx[p]];          // route held by the picked VC
    assign in_won[p]       = |xbar_sel_t[p];                          // onehot0: one pick requests one output
    assign sa_grant[p]     = in_won[p] ? s1_pick[p] : '0;             // subset of the pick, so subset of sa_req
  end

  // Stage 2: one NUM_PORTS-way arbiter per output. Every stage-2 grant is final, so the
  // arbiter consumes its own grant and issue[o] is both its enable and its valid (s7.2).
  for (genvar o = 0; o < NUM_PORTS; o++) begin : g_out
    for (genvar p = 0; p < NUM_PORTS; p++) begin : g_req
      assign s2_req[o][p]     = s1_pick_vld[p] && (s1_pick_port[p] == PORT_W'(o)); // codes >= NUM_PORTS match no output
      assign xbar_sel_t[p][o] = xbar_sel[o][p];
    end

    /* verilator lint_off UNUSEDSIGNAL */
    logic [P_IW-1:0] s2_pick_idx;                                     // xbar_sel is onehot0; kept for waveform debug only
    /* verilator lint_on UNUSEDSIGNAL */

    rr_arbiter #(.N(NUM_PORTS)) u_s2 (
      .clk       (clk),
      .rst_n     (rst_n),
      .req       (s2_req[o]),
      .en        (issue[o]),
      .grant     (xbar_sel[o]),
      .grant_idx (s2_pick_idx),
      .grant_vld (issue[o])                                           // |s2_req[o] == |xbar_sel[o]
    );
  end

endmodule

`default_nettype wire
