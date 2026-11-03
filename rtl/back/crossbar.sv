//crossbar: NUM_PORTS x NUM_PORTS flit and VC mux, xbar_sel[o][p] one-hot-or-zero picks input p for output o (INTERFACE.md s7), combinational
`default_nettype none
module crossbar
  import noc_pkg::*;
#(
  parameter int unsigned FLIT_WIDTH = DEF_FLIT_WIDTH,
  parameter int unsigned NUM_VCS    = DEF_NUM_VCS,
  localparam int unsigned VC_W      = vc_w(NUM_VCS)
) (
  input  wire logic [NUM_PORTS-1:0][NUM_PORTS-1:0]  xbar_sel,  //[o][p], from switch_allocator
  input  wire logic [NUM_PORTS-1:0][FLIT_WIDTH-1:0] xb_flit,   //[p], granted-VC flit
  input  wire logic [NUM_PORTS-1:0][VC_W-1:0]       xb_vc,     //[p], its held output VC
  output logic      [NUM_PORTS-1:0][FLIT_WIDTH-1:0] issue_flit,//[o], to output_unit
  output logic      [NUM_PORTS-1:0][VC_W-1:0]       issue_vc   //[o]
);

  //and-or mux, no priority encoder, no latch; an unselected output reads zero (s7)
  always_comb begin
    for (int unsigned o = 0; o < NUM_PORTS; o++) begin
      issue_flit[o] = '0;
      issue_vc[o]   = '0;
      for (int unsigned p = 0; p < NUM_PORTS; p++) begin
        issue_flit[o] |= xb_flit[p] & {FLIT_WIDTH{xbar_sel[o][p]}};
        issue_vc[o]   |= xb_vc[p]   & {VC_W{xbar_sel[o][p]}};
      end
    end
  end

  //onehot0(xbar_sel[o]) is R06 and the data path is R10, both in tb/sva via bind

endmodule
`default_nettype wire
