//router_top: 5-port wormhole router top, back half wired (SA/XB/OU), front half stubbed, lint-only skeleton
module router_top
  import noc_pkg::*;
#(
  parameter int unsigned NUM_VCS      = DEF_NUM_VCS,
  parameter int unsigned FLIT_W       = DEF_FLIT_WIDTH,
  parameter int unsigned BUFFER_DEPTH = DEF_BUFFER_DEPTH,
  /* verilator lint_off UNUSEDPARAM */
  //these three feed route_unit inside the stubbed front half, drop the waiver when input_port lands
  parameter int unsigned X_COORD      = 0,
  parameter int unsigned Y_COORD      = 0,
  parameter              ROUTE_ALGO   = "XY",
  /* verilator lint_on UNUSEDPARAM */
  localparam int unsigned VC_W        = vc_w(NUM_VCS)//package helper, never hardcoded
) (
  input  wire logic                                clk,
  input  wire logic                                rst_n,

  input  wire logic [NUM_PORTS-1:0]                in_valid_i,
  input  wire logic [NUM_PORTS-1:0][VC_W-1:0]      in_vc_i,
  input  wire logic [NUM_PORTS-1:0][FLIT_W-1:0]    in_flit_i,
  output logic      [NUM_PORTS-1:0]                in_credit_o,
  output logic      [NUM_PORTS-1:0][VC_W-1:0]      in_credit_vc_o,

  output logic      [NUM_PORTS-1:0]                out_valid_o,
  output logic      [NUM_PORTS-1:0][VC_W-1:0]      out_vc_o,
  output logic      [NUM_PORTS-1:0][FLIT_W-1:0]    out_flit_o,
  input  wire logic [NUM_PORTS-1:0]                out_credit_i,
  input  wire logic [NUM_PORTS-1:0][VC_W-1:0]      out_credit_vc_i
);

  //sa interface shapes come from switch_allocator s7: requests are per (input port, vc)
  logic [NUM_PORTS-1:0][NUM_VCS-1:0]              sa_req;
  logic [NUM_PORTS-1:0][NUM_VCS-1:0][PORT_W-1:0]  sa_out_port;
  logic [NUM_PORTS-1:0][NUM_VCS-1:0]              sa_grant;
  logic [NUM_PORTS-1:0][NUM_PORTS-1:0]            xbar_sel; //[o][p], feeds crossbar directly
  logic [NUM_PORTS-1:0]                           issue;    //[o], a flit is launched on this output

  logic [NUM_PORTS-1:0][FLIT_W-1:0]  xb_data_in;
  logic [NUM_PORTS-1:0][FLIT_W-1:0]  xb_data_out;
  logic [NUM_PORTS-1:0]              xb_valid_out;
  logic [NUM_PORTS-1:0][VC_W-1:0]    ou_send_vc;
  logic [NUM_PORTS-1:0][NUM_VCS-1:0] ou_has_credit;

  //front half stub: input_port + route_unit + vc_allocator pending, tied off so this elaborates
  //replace this block with the input_port generate loop when those merge, no test covers this region
  always_comb begin
    sa_req         = '0;
    sa_out_port    = '0;
    xb_data_in     = '0;
    in_credit_o    = '0;
    in_credit_vc_o = '0;
    for (int p = 0; p < NUM_PORTS; p++) begin
      ou_send_vc[p] = '0;
    end
  end

  //sa_grant goes back to the front half, ou_has_credit gates sa_req there, both stubbed.
  //xb_valid_out is crossbar's own recomputation of issue: |xbar_sel[o] by construction.
  //worth an SVA equivalence check (xb_valid_out === issue) once a functional tb exists.
  logic unused_front;
  assign unused_front = |in_valid_i | |in_vc_i | |in_flit_i
                      | |sa_grant | |ou_has_credit | |xb_valid_out;//drop with the stub

  switch_allocator #(
    .NUM_VCS (NUM_VCS)//only parameter, NUM_PORTS and PORT_W come from noc_pkg
  ) u_switch_allocator (
    .clk         (clk),
    .rst_n       (rst_n),
    .sa_req      (sa_req),
    .sa_out_port (sa_out_port),
    .sa_grant    (sa_grant),
    .xbar_sel    (xbar_sel),
    .issue       (issue)
  );

  crossbar #(
    .NUM_PORTS (NUM_PORTS),
    .DATA_W    (FLIT_W)
  ) u_crossbar (
    .data_i  (xb_data_in),
    .grant_i (xbar_sel),//already [o][p], no transpose
    .data_o  (xb_data_out),
    .valid_o (xb_valid_out)
  );

  for (genvar p = 0; p < NUM_PORTS; p++) begin : g_out
    output_unit #(
      .FLIT_W       (FLIT_W),
      .NUM_VCS      (NUM_VCS),
      .BUFFER_DEPTH (BUFFER_DEPTH)
    ) u_output_unit (
      .clk             (clk),
      .rst_n           (rst_n),
      .send_valid_i    (issue[p]),//allocator is authoritative, not crossbar's derived valid
      .send_vc_i       (ou_send_vc[p]),
      .send_flit_i     (xb_data_out[p]),
      .credit_valid_i  (out_credit_i[p]),
      .credit_vc_i     (out_credit_vc_i[p]),
      .vc_has_credit_o (ou_has_credit[p]),
      .flit_valid_o    (out_valid_o[p]),
      .flit_vc_o       (out_vc_o[p]),
      .flit_o          (out_flit_o[p])
    );
  end

endmodule
