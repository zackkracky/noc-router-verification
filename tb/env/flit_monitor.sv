// flit_monitor: passive pre-edge sampling, VC bounds and per-VC packet framing.
`default_nettype none
module flit_monitor #(
  parameter int unsigned FLIT_WIDTH = 64,
  parameter int unsigned NUM_VCS = 2,
  localparam int unsigned VC_W = noc_pkg::vc_w(NUM_VCS)
)(
  flit_if.mon link,
  output logic observed,
  output logic [FLIT_WIDTH-1:0] observed_flit,
  output logic [VC_W-1:0] observed_vc
);
  import noc_pkg::*;
  bit packet_open [NUM_VCS];
  logic [PKT_ID_W-1:0] packet_id [NUM_VCS];
  int unsigned next_idx [NUM_VCS];
  hdr_t h;
  logic [VC_W-1:0] v;

  // Raw sampling at posedge sees the same pre-NBA link values as the FIFO.
  // Procedural TB framing state is updated immediately within one observation.
  /* verilator lint_off BLKSEQ */
  always @(posedge link.clk) begin
    observed <= 1'b0;
    observed_flit <= '0;
    observed_vc <= '0;
    if (!link.rst_n) begin
      for (int unsigned i = 0; i < NUM_VCS; i++) begin
        packet_open[i] = 0;
        packet_id[i] = '0;
        next_idx[i] = 0;
      end
    end else begin
      if ($isunknown({link.flit_valid, link.credit_valid})) $fatal(1, "monitor: unknown valid");
      if (link.credit_valid && ($isunknown(link.credit_vc) || int'(link.credit_vc) >= NUM_VCS))
        $fatal(1, "monitor: invalid credit VC");
      if (link.flit_valid) begin
        if ($isunknown({link.flit, link.flit_vc}) || int'(link.flit_vc) >= NUM_VCS)
          $fatal(1, "monitor: invalid flit/VC");
        v = link.flit_vc;
        h = hdr_t'(link.flit[FLIT_WIDTH-1 -: HDR_W]);
        if ($isunknown(h)) $fatal(1, "monitor: unknown header");
        case (h.ftype)
          HEAD, HEAD_TAIL: begin
            if (packet_open[v] || h.flit_idx != 0) $fatal(1, "monitor: invalid packet start");
            packet_open[v] = (h.ftype == HEAD);
            packet_id[v] = h.pkt_id;
            next_idx[v] = 1;
          end
          BODY, TAIL: begin
            if (!packet_open[v] || packet_id[v] != h.pkt_id || int'(h.flit_idx) != next_idx[v])
              $fatal(1, "monitor: packet framing/order mismatch");
            next_idx[v]++;
            if (h.ftype == TAIL) packet_open[v] = 0;
          end
          default: $fatal(1, "monitor: unknown flit type");
        endcase
        observed <= 1'b1;
        observed_flit <= link.flit;
        observed_vc <= link.flit_vc;
      end
    end
  end
  /* verilator lint_on BLKSEQ */
endmodule
`default_nettype wire
