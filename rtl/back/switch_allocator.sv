// switch_allocator: input-first separable switch allocation (INTERFACE.md s7, s7.2); sa_req/sa_out_port[p][v] in, sa_grant[p][v] + xbar_sel[o][p] + issue[o] out, all combinational
`default_nettype none

module switch_allocator
  import noc_pkg::*;
  #(
  parameter int unsigned NUM_VCS = DEF_NUM_VCS
  ) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic [NUM_PORTS-1:0][NUM_VCS-1:0] sa_req, //i/p active & FIFO not empty considering resp. credit availability.must not depend on a grant (s7)
  input  wire logic [NUM_PORTS-1:0][NUM_VCS-1:0][PORT_W-1:0] sa_out_port, //held encoded route.caller guarantees < NUM_PORTS (s7, formal/assume.sv)
  output logic [NUM_PORTS-1:0][NUM_VCS-1:0] sa_grant, //onehot0 per input
  output logic [NUM_PORTS-1:0][NUM_PORTS-1:0] xbar_sel,
  output logic [NUM_PORTS-1:0] issue //status of i/p assigned to o/p
  );

  localparam int unsigned VC_INDEX_W = vc_w(NUM_VCS); //1 rr_arbiter
  localparam int unsigned PORT_INDEX_W = $clog2(NUM_PORTS); //2 rr_arbiter

  logic [NUM_PORTS-1:0][NUM_VCS-1:0] selected_vc;
  logic [NUM_PORTS-1:0][VC_INDEX_W-1:0] selected_vc_index;
  logic [NUM_PORTS-1:0] selected_vc_valid;//indicates if stage-1 found a requesting VC
  logic [NUM_PORTS-1:0][PORT_W-1:0] selected_out_port;
  logic [NUM_PORTS-1:0][NUM_PORTS-1:0] output_requests;//pass stage-1,p request to o [o][p]
  logic [NUM_PORTS-1:0][NUM_PORTS-1:0] xbar_sel_by_input;//xbar_sel with inverted dimensions[p][o]
  logic [NUM_PORTS-1:0] input_won;

  /* 
    Stage 1:A single <NUM_VCS>-way arbiter per input picks at most one requesting VC.
    The pointer rotates only on a final grant (en = input_won)
  */

  /*
    stage 2:input that loses, re-offer the same VC next cycle instead of rotating past it (s7, s7.2).
    cost of committing to one VC here:if this input loses stage 2, its other VCs are
    hidden for the cycle, so the result is a matching but not always a maximal one.
    Characterised and measured in tb_switch_allocator phase 3b and the efficiency report.
  */

  //STAGE 1
  for (genvar p = 0; p < NUM_PORTS; p++) 
    begin : g_input
      rr_arbiter #(
        .N(NUM_VCS)
      ) u_vc_arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .req(sa_req[p]),
        .en(input_won[p]),
        .grant(selected_vc[p]),
        .grant_idx(selected_vc_index[p]),
        .grant_vld(selected_vc_valid[p])
      );

      assign selected_out_port[p] = sa_out_port[p][selected_vc_index[p]];
      assign input_won[p] = |xbar_sel_by_input[p];
      assign sa_grant[p] = input_won[p]? selected_vc[p] : '0;
    end
  /*
    Stage 2:one NUM_PORTS-way arbiter per output picks at most one input.
    Every stage-2 grant is final.The arbiter consumes its own grant and issue[o]
    which serve as both its enable and its valid (s7.2).
  */
  for (genvar o = 0; o < NUM_PORTS; o++) 
    begin : g_output
      for (genvar p = 0; p < NUM_PORTS; p++)
        begin : g_request
          assign output_requests[o][p] = selected_vc_valid[p] && (selected_out_port[p] == PORT_W'(o));
          assign xbar_sel_by_input[p][o] = xbar_sel[o][p];
        end

      /* verilator lint_off UNUSEDSIGNAL */
      logic [PORT_INDEX_W-1:0] granted_input_index;//xbar_sel is onehot0for waveform debug only
      /* verilator lint_on UNUSEDSIGNAL */

      rr_arbiter #(
        .N(NUM_PORTS)
      ) u_input_arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .req(output_requests[o]),
        .en(issue[o]),
        .grant(xbar_sel[o]),
        .grant_idx(granted_input_index),
        .grant_vld(issue[o])                                             // |output_requests[o] == |xbar_sel[o]
      );
    end

endmodule

`default_nettype wire
