// router_top.sv — 5-port VC wormhole router top: link/credit ports, RC-VA-SA-XB-OU datapath wiring.

`timescale 1ns/1ps
`default_nettype none

module router_top
  import noc_pkg::*;#(
  parameter int FLIT_WIDTH = 64,
  parameter int NUM_VCS = 2,
  parameter int BUFFER_DEPTH = 4,
  parameter int X_COORD = 0,
  parameter int Y_COORD = 0,
  parameter int MESH_X = 2,
  parameter int MESH_Y = 2,
  parameter string ROUTE_ALGO = "XY",
  localparam int VC_W = (NUM_VCS > 1)? $clog2(NUM_VCS):1
  )(
  input wire logic clk,
  input wire logic rst_n,

  input wire logic [NUM_PORTS-1:0] in_valid,// upstream -> router
  input wire logic [NUM_PORTS-1:0][FLIT_WIDTH-1:0] in_flit,
  input wire logic [NUM_PORTS-1:0][VC_W-1:0] in_vc,
  output logic [NUM_PORTS-1:0] in_credit_valid,// credit returned upstream
  output logic [NUM_PORTS-1:0][VC_W-1:0] in_credit_vc,

  output logic [NUM_PORTS-1:0] out_valid,         // router -> downstream
  output logic [NUM_PORTS-1:0][FLIT_WIDTH-1:0] out_flit,
  output logic [NUM_PORTS-1:0][VC_W-1:0] out_vc,
  input  wire logic [NUM_PORTS-1:0] out_credit_valid,  // credit from downstream
  input  wire logic [NUM_PORTS-1:0][VC_W-1:0] out_credit_vc
);

  localparam int PORT_W = $clog2(NUM_PORTS);  // 3 for 5 ports

  // RC: input_port -> vc_allocator
  logic [NUM_PORTS-1:0][NUM_VCS-1:0] rc_valid;
  logic [NUM_PORTS-1:0][NUM_VCS-1:0][PORT_W-1:0] rc_port;

  // VA: vc_allocator -> input_port
  logic [NUM_PORTS-1:0][NUM_VCS-1:0] va_grant;
  logic [NUM_PORTS-1:0][NUM_VCS-1:0][VC_W-1:0] va_ovc;

  // SA: input_port <-> switch_allocator
  logic [NUM_PORTS-1:0][NUM_VCS-1:0] sa_req;
  logic [NUM_PORTS-1:0][NUM_VCS-1:0][PORT_W-1:0] sa_port;
  logic [NUM_PORTS-1:0][NUM_VCS-1:0] sa_grant;

  // crossbar input side (one winning VC per input port, muxed inside input_port)
  logic [NUM_PORTS-1:0] ip_valid;
  logic [NUM_PORTS-1:0][FLIT_WIDTH-1:0] ip_flit;
  logic [NUM_PORTS-1:0][VC_W-1:0] ip_ovc;

  // crossbar control + output side
  logic [NUM_PORTS-1:0] xb_en;
  logic [NUM_PORTS-1:0][PORT_W-1:0] xb_sel;
  logic [NUM_PORTS-1:0] xb_valid;
  logic [NUM_PORTS-1:0][FLIT_WIDTH-1:0] xb_flit;
  logic [NUM_PORTS-1:0][VC_W-1:0] xb_vc;

  // output_unit feedback
  logic [NUM_PORTS-1:0][NUM_VCS-1:0] ovc_has_credit;  // -> SA eligibility
  logic [NUM_PORTS-1:0][NUM_VCS-1:0] ovc_release;     // tail departed -> VA frees VC

  genvar p;
  generate
    for (p = 0; p < NUM_PORTS; p++) begin : g_input_port
      input_port #(
        .FLIT_WIDTH(FLIT_WIDTH),
        .NUM_VCS(NUM_VCS),
        .BUFFER_DEPTH(BUFFER_DEPTH),
        .X_COORD(X_COORD),
        .Y_COORD(Y_COORD),
        .MESH_X(MESH_X),
        .MESH_Y(MESH_Y),
        .PORT_ID(p),            // arrival port, needed by west-first in Phase 3
        .ROUTE_ALGO(ROUTE_ALGO)
      ) u_input_port (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid[p]),
        .in_flit(in_flit[p]),
        .in_vc(in_vc[p]),
        .credit_valid(in_credit_valid[p]),
        .credit_vc(in_credit_vc[p]),
        .rc_valid(rc_valid[p]),
        .rc_port(rc_port[p]),
        .va_grant(va_grant[p]),
        .va_ovc(va_ovc[p]),
        .ovc_has_credit(ovc_has_credit),   // full array; IP selects by its granted (port,vc)
        .sa_req(sa_req[p]),
        .sa_port(sa_port[p]),
        .sa_grant(sa_grant[p]),
        .xb_valid(ip_valid[p]),
        .xb_flit(ip_flit[p]),
        .xb_vc(ip_ovc[p])
      );
    end

    for (p = 0; p < NUM_PORTS; p++) begin : g_output_unit
      output_unit #(
        .FLIT_WIDTH(FLIT_WIDTH),
        .NUM_VCS(NUM_VCS),
        .BUFFER_DEPTH(BUFFER_DEPTH)
      ) u_output_unit (
        .clk(clk),
        .rst_n(rst_n),
        .xb_valid(xb_valid[p]),
        .xb_flit(xb_flit[p]),
        .xb_vc(xb_vc[p]),
        .credit_in_valid(out_credit_valid[p]),
        .credit_in_vc(out_credit_vc[p]),
        .has_credit(ovc_has_credit[p]),
        .vc_release(ovc_release[p]),   // pulse on tail departure
        .out_valid(out_valid[p]),
        .out_flit(out_flit[p]),
        .out_vc(out_vc[p])
      );
    end
  endgenerate

  vc_allocator #(
    .NUM_VCS (NUM_VCS)
  ) u_vc_allocator (
    .clk(clk),
    .rst_n(rst_n),
    .rc_valid(rc_valid),
    .rc_port(rc_port),
    .vc_release(ovc_release),
    .va_grant(va_grant),
    .va_ovc(va_ovc)
  );

  switch_allocator #(
    .NUM_VCS(NUM_VCS)
  ) u_switch_allocator (
    .clk(clk),
    .rst_n(rst_n),
    .req(sa_req),
    .req_port(sa_port),
    .grant(sa_grant),
    .xb_sel(xb_sel),
    .xb_en(xb_en)
  );

  crossbar #(
    .FLIT_WIDTH(FLIT_WIDTH),
    .VC_W(VC_W)
  ) u_crossbar (
    .in_valid(ip_valid),
    .in_flit(ip_flit),
    .in_vc(ip_ovc),
    .sel(xb_sel),
    .en(xb_en),
    .out_valid(xb_valid),
    .out_flit(xb_flit),
    .out_vc(xb_vc)
  );

endmodule

`default_nettype wire

