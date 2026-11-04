//router_top: 5-port wormhole router, flat INTERFACE.md s4 ports; back half wired (granted-VC mux, SA, crossbar, 5 output units), input_port x5 stubbed; lint-only skeleton
`default_nettype none
module router_top
  import noc_pkg::*;
#(
  parameter int unsigned FLIT_WIDTH   = DEF_FLIT_WIDTH,
  parameter int unsigned NUM_VCS      = DEF_NUM_VCS,
  parameter int unsigned BUFFER_DEPTH = DEF_BUFFER_DEPTH,
  parameter int unsigned X_COORD      = 0,
  parameter int unsigned Y_COORD      = 0,
  parameter string       ROUTE_ALGO   = "XY",
  localparam int unsigned VC_W        = vc_w(NUM_VCS),
  localparam int unsigned CNT_W       = cnt_w(BUFFER_DEPTH)
) (
  input  wire logic                                 clk,
  input  wire logic                                 rst_n,
  input  wire logic [NUM_PORTS-1:0][FLIT_WIDTH-1:0] in_flit,         //from upstream
  input  wire logic [NUM_PORTS-1:0]                 in_flit_valid,
  input  wire logic [NUM_PORTS-1:0][VC_W-1:0]       in_flit_vc,
  input  wire logic [NUM_PORTS-1:0]                 out_credit_valid,//from downstream
  input  wire logic [NUM_PORTS-1:0][VC_W-1:0]       out_credit_vc,
  output logic      [NUM_PORTS-1:0]                 in_credit_valid, //to upstream
  output logic      [NUM_PORTS-1:0][VC_W-1:0]       in_credit_vc,
  output logic      [NUM_PORTS-1:0][FLIT_WIDTH-1:0] out_flit,        //to downstream
  output logic      [NUM_PORTS-1:0]                 out_flit_valid,
  output logic      [NUM_PORTS-1:0][VC_W-1:0]       out_flit_vc
);

  //front/back boundary, INTERFACE.md s7 names and indices
  logic [NUM_PORTS-1:0][NUM_VCS-1:0]                 sa_req;       //[p][v]
  logic [NUM_PORTS-1:0][NUM_VCS-1:0][PORT_W-1:0]     sa_out_port;  //[p][v] held route
  logic [NUM_PORTS-1:0][NUM_VCS-1:0][VC_W-1:0]       sa_out_vc;    //[p][v] held output VC
  logic [NUM_PORTS-1:0][NUM_VCS-1:0][FLIT_WIDTH-1:0] sa_flit;      //[p][v] FIFO head
  logic [NUM_PORTS-1:0][NUM_VCS-1:0]                 sa_grant;     //[p][v] final grant
  logic [NUM_PORTS-1:0][NUM_VCS-1:0]                 ocredit_avail;//[o][v]
  logic [NUM_PORTS-1:0][NUM_VCS-1:0][CNT_W-1:0]      ocredit_count;//[o][v]
  logic [NUM_PORTS-1:0][NUM_PORTS-1:0]               xbar_sel;     //[o][p]
  logic [NUM_PORTS-1:0][FLIT_WIDTH-1:0]              xb_flit;      //[p]
  logic [NUM_PORTS-1:0][VC_W-1:0]                    xb_vc;        //[p]
  logic [NUM_PORTS-1:0]                              issue;        //[o]
  logic [NUM_PORTS-1:0][FLIT_WIDTH-1:0]              issue_flit;   //[o]
  logic [NUM_PORTS-1:0][VC_W-1:0]                    issue_vc;     //[o]

  //front half stub: input_port x5 (route_unit, per-VC FIFOs, FSM, credit return) pending.
  //drives every input_port output to zero so the back half elaborates; no test covers this region
  always_comb begin
    sa_req          = '0;
    sa_out_port     = '0;
    sa_out_vc       = '0;
    sa_flit         = '0;
    in_credit_valid = '0;
    in_credit_vc    = '0;
  end

  //everything input_port will consume, plus the route_unit parameters; drop with the stub
  logic unused_front;
  assign unused_front = ^{in_flit, in_flit_valid, in_flit_vc, sa_grant, ocredit_avail, ocredit_count,
                          COORD_W'(X_COORD), COORD_W'(Y_COORD), (ROUTE_ALGO == "XY")};

  //granted-VC mux (s7): the final grant picks one VC per input, sa_grant[p] is onehot0 (R07)
  always_comb begin
    for (int unsigned p = 0; p < NUM_PORTS; p++) begin
      xb_flit[p] = '0;
      xb_vc[p]   = '0;
      for (int unsigned v = 0; v < NUM_VCS; v++) begin
        xb_flit[p] |= sa_flit[p][v]   & {FLIT_WIDTH{sa_grant[p][v]}};
        xb_vc[p]   |= sa_out_vc[p][v] & {VC_W{sa_grant[p][v]}};
      end
    end
  end

  switch_allocator #(
    .NUM_VCS (NUM_VCS)//its only parameter; NUM_PORTS and PORT_W come from noc_pkg
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
    .FLIT_WIDTH (FLIT_WIDTH),
    .NUM_VCS    (NUM_VCS)
  ) u_crossbar (
    .xbar_sel   (xbar_sel),//already [o][p], no transpose
    .xb_flit    (xb_flit),
    .xb_vc      (xb_vc),
    .issue_flit (issue_flit),
    .issue_vc   (issue_vc)
  );

  for (genvar o = 0; o < NUM_PORTS; o++) begin : g_out
    output_unit #(
      .FLIT_WIDTH   (FLIT_WIDTH),
      .NUM_VCS      (NUM_VCS),
      .BUFFER_DEPTH (BUFFER_DEPTH)
    ) u_output_unit (
      .clk              (clk),
      .rst_n            (rst_n),
      .issue            (issue[o]),
      .issue_flit       (issue_flit[o]),
      .issue_vc         (issue_vc[o]),
      .out_credit_valid (out_credit_valid[o]),
      .out_credit_vc    (out_credit_vc[o]),
      .ocredit_avail    (ocredit_avail[o]),
      .ocredit_count    (ocredit_count[o]),
      .out_flit_valid   (out_flit_valid[o]),
      .out_flit_vc      (out_flit_vc[o]),
      .out_flit         (out_flit[o])
    );
  end

endmodule
`default_nettype wire
