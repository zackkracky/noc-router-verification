//output_unit: one output port's flit register and per-VC credit counters; issue loads the register and debits issue_vc (INTERFACE.md s5.2, s5.4), credits only
`default_nettype none
module output_unit
  import noc_pkg::*;
#(
  parameter int unsigned FLIT_WIDTH   = DEF_FLIT_WIDTH,
  parameter int unsigned NUM_VCS      = DEF_NUM_VCS,
  parameter int unsigned BUFFER_DEPTH = DEF_BUFFER_DEPTH,
  localparam int unsigned VC_W        = vc_w(NUM_VCS),
  localparam int unsigned CNT_W       = cnt_w(BUFFER_DEPTH)
) (
  input  wire logic                  clk,
  input  wire logic                  rst_n,           //sync, active low
  input  wire logic                  issue,           //final SA grant to this output
  input  wire logic [FLIT_WIDTH-1:0] issue_flit,      //from crossbar
  input  wire logic [VC_W-1:0]       issue_vc,        //downstream VC for that flit
  input  wire logic                  out_credit_valid,//returned by the downstream router
  input  wire logic [VC_W-1:0]       out_credit_vc,
  output logic      [NUM_VCS-1:0]            ocredit_avail,//credit > 0, to input_port
  output logic      [NUM_VCS-1:0][CNT_W-1:0] ocredit_count,//to route_unit.route_credit, ignored by XY
  output logic                       out_flit_valid,
  output logic      [VC_W-1:0]       out_flit_vc,
  output logic      [FLIT_WIDTH-1:0] out_flit
);

  //no vc ownership here, the single busy/owner table stays in vc_allocator (T9)
  logic [NUM_VCS-1:0] send, ret;

  always_comb begin
    for (int unsigned v = 0; v < NUM_VCS; v++) begin
      send[v]          = issue            && (issue_vc      == VC_W'(v));
      ret[v]           = out_credit_valid && (out_credit_vc == VC_W'(v));
      ocredit_avail[v] = (ocredit_count[v] != '0);//pre-edge count, so a same-edge return cannot enable a send
    end
  end

  //credit_next = credit + ret - send (s5.4); reset writes BUFFER_DEPTH
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      for (int unsigned v = 0; v < NUM_VCS; v++) ocredit_count[v] <= CNT_W'(BUFFER_DEPTH);
    end else begin
      for (int unsigned v = 0; v < NUM_VCS; v++) begin
        case ({ret[v], send[v]})
          2'b10:   ocredit_count[v] <= ocredit_count[v] + CNT_W'(1);//return only
          2'b01:   ocredit_count[v] <= ocredit_count[v] - CNT_W'(1);//send only
          default: ocredit_count[v] <= ocredit_count[v];//idle, or send plus return on one VC nets zero
        endcase
      end
    end
  end

  //output register: loads on issue, clears with no new issue, never repeats a flit (s5.2)
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      out_flit_valid <= 1'b0;
      out_flit_vc    <= '0;
      out_flit       <= '0;
    end else begin
      out_flit_valid <= issue;
      out_flit_vc    <= issue ? issue_vc   : '0;//zero when idle, for readable traces (s4)
      out_flit       <= issue ? issue_flit : '0;
    end
  end

  //R11 count range, R12 no issue without credit, R13 increment rule, R14 net zero: tb/sva via bind

endmodule
`default_nettype wire
