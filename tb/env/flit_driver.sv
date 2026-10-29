// flit_driver: command admission reserves credit before the registered link output.
`default_nettype none
module flit_driver #(
  parameter int unsigned FLIT_WIDTH = 64,
  parameter int unsigned NUM_VCS = 2,
  parameter int unsigned BUFFER_DEPTH = 4,
  localparam int unsigned VC_W = noc_pkg::vc_w(NUM_VCS)
)(
  flit_if.tx link,
  input wire logic cmd_valid,
  input wire logic [FLIT_WIDTH-1:0] cmd_flit,
  input wire logic [VC_W-1:0] cmd_vc,
  output logic cmd_ready,
  output int unsigned credits [NUM_VCS]
);
  // A return at zero cannot enable admission at the same edge.
  always_comb begin
    cmd_ready = 1'b0;
    if (link.rst_n && int'(cmd_vc) < NUM_VCS)
      cmd_ready = (credits[cmd_vc] > 0);
  end

  always @(posedge link.clk) begin
    if (!link.rst_n) begin
      link.flit_valid <= 1'b0;
      link.flit <= '0;
      link.flit_vc <= '0;
      for (int unsigned v = 0; v < NUM_VCS; v++) credits[v] <= BUFFER_DEPTH;
    end else begin
      if (cmd_valid && int'(cmd_vc) >= NUM_VCS) $fatal(1, "driver: invalid command VC");
      if (link.credit_valid && int'(link.credit_vc) >= NUM_VCS)
        $fatal(1, "driver: invalid credit VC");
      link.flit_valid <= cmd_valid && cmd_ready;
      link.flit <= (cmd_valid && cmd_ready) ? cmd_flit : '0;
      link.flit_vc <= (cmd_valid && cmd_ready) ? cmd_vc : '0;
      for (int unsigned v = 0; v < NUM_VCS; v++) begin
        case ({(cmd_valid && cmd_ready && int'(cmd_vc) == v),
               (link.credit_valid && int'(link.credit_vc) == v)})
          2'b10: credits[v] <= credits[v] - 1;
          2'b01: begin
            if (credits[v] >= BUFFER_DEPTH) $fatal(1, "driver: duplicate credit");
            credits[v] <= credits[v] + 1;
          end
          default: ; // simultaneous same-VC reserve/return nets zero
        endcase
      end
    end
  end
endmodule
`default_nettype wire
