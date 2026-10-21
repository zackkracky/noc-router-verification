//switch_allocator:separable input-first SA (INTERFACE.md s7/s7.2); sa_req/sa_out_port[p][v] in, sa_grant[p][v] + xbar_sel[o][p] + issue[o] out, all combinational
`default_nettype none

module switch_allocator
  import noc_pkg::*;
#(
  parameter int unsigned NUM_VCS = DEF_NUM_VCS,
  parameter int unsigned VC_IW   = vc_w(NUM_VCS)                      // stage-1 rr_arbiter IDX_W; do not override
) (
  input  logic clk,
  input  logic rst_n,        // sync, active-low (s8)
  input  logic [NUM_PORTS-1:0][NUM_VCS-1:0] sa_req,       // ACTIVE && !empty && credit (s7); must not depend on a grant
  input  logic [NUM_PORTS-1:0][NUM_VCS-1:0][PORT_W-1:0] sa_out_port,  // held encoded route, port_e
  output logic [NUM_PORTS-1:0][NUM_VCS-1:0] sa_grant,     // final grant: input FIFO dequeues at this edge
  output logic [NUM_PORTS-1:0][NUM_PORTS-1:0] xbar_sel,     // [o][p], onehot0 per output
  output logic [NUM_PORTS-1:0] issue         // |xbar_sel[o]: output load + credit debit
);

  localparam int unsigned P_IW = $clog2(NUM_PORTS);                   // stage-2 rr_arbiter IDX_W

  logic [NUM_PORTS-1:0][NUM_VCS-1:0]   s1_grant;                      // stage-1 pick per input, onehot0
  logic [NUM_PORTS-1:0][VC_IW-1:0]     s1_idx;
  logic [NUM_PORTS-1:0]                s1_vld;
  logic [NUM_PORTS-1:0][PORT_W-1:0]    s1_port;                       // output requested by the stage-1 pick
  logic [NUM_PORTS-1:0][NUM_PORTS-1:0] s2_req;                        // [o][p]
  logic [NUM_PORTS-1:0][NUM_PORTS-1:0] sel_t;                         // [p][o], transpose of xbar_sel
  logic [NUM_PORTS-1:0]                in_won;                        // input p won stage 2 at some output

  // stage 1: one NUM_VCS-way arbiter per input; rotates only on final grant (s7.2)
  for (genvar p = 0; p < NUM_PORTS; p++) begin : g_in
    rr_arbiter #(.N(NUM_VCS)) u_s1 (
      .clk(clk),
      .rst_n(rst_n),
      .req(sa_req[p]),
      .en(in_won[p]),                                         // = |sa_grant[p]; a stage-2 loss holds the pointer
      .grant(s1_grant[p]),
      .grant_idx(s1_idx[p]),
      .grant_vld(s1_vld[p])
    );
    assign s1_port[p]  = sa_out_port[p][s1_idx[p]];                   // pick's held route
    assign in_won[p]   = |sel_t[p];                                   // onehot0: one stage-1 pick requests one output
    assign sa_grant[p] = in_won[p] ? s1_grant[p] : '0;                // subset of stage-1 pick, so subset of sa_req
  end

  // stage 2: one NUM_PORTS-way arbiter per output; every stage-2 grant is final
  for (genvar o = 0; o < NUM_PORTS; o++) begin : g_out
    for (genvar p = 0; p < NUM_PORTS; p++) begin : g_req
      assign s2_req[o][p] = s1_vld[p] && (s1_port[p] == PORT_W'(o));  // encodings >= NUM_PORTS match no output
      assign sel_t[p][o]  = xbar_sel[o][p];
    end
    /* verilator lint_off UNUSEDSIGNAL */
    logic [P_IW-1:0] s2_idx;                                          // xbar_sel is onehot0; index not needed downstream
    /* verilator lint_on UNUSEDSIGNAL */
    rr_arbiter #(.N(NUM_PORTS)) u_s2 (
      .clk       (clk),
      .rst_n     (rst_n),
      .req       (s2_req[o]),
      .en        (issue[o]),                                          // a stage-2 grant is always final (s7.2)
      .grant     (xbar_sel[o]),
      .grant_idx (s2_idx),
      .grant_vld (issue[o])                                           // |s2_req == |xbar_sel
    );
  end

endmodule

`default_nettype wire