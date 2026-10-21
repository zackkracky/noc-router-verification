// fifo_link_case: TB-only multi-VC FIFO adapter and independent queue checks.
`default_nettype none
module fifo_link_case #(
  parameter int unsigned F = 64, V = 2, D = 4,
  localparam int unsigned VW = noc_pkg::vc_w(V), CW = noc_pkg::cnt_w(D)
)(output bit done);
  import noc_pkg::*;
  typedef logic [F-1:0] flit_t;
  logic clk = 0, rst_n = 0, cmd_valid = 0, drain = 0;
  always #5 clk <= ~clk;
  logic [F-1:0] cmd_flit = '0;
  logic [VW-1:0] cmd_vc = '0;
  logic cmd_ready, observed;
  logic [F-1:0] observed_flit;
  logic [VW-1:0] observed_vc;
  logic observed_credit, sampled_credit;
  logic [VW-1:0] observed_credit_vc, sampled_credit_vc;
  int unsigned credits [V];
  int unsigned drain_vc = 0;
  logic [V-1:0] rd_valid, rd_ready, credit, full, empty;
  logic [F-1:0] rd_data [V];
  logic [CW-1:0] count [V];
  logic popped;
  flit_t popped_flit;
  logic [VW-1:0] popped_vc;
  bit admitted;
  flit_t admitted_flit;
  logic [VW-1:0] admitted_vc;
  int unsigned same_vc = 0, different_vc = 0, last_credit = 0;
  int unsigned b2b_edges = 0;
  bit previous_valid = 0;
  flit_if #(.FLIT_WIDTH(F), .NUM_VCS(V)) link(clk, rst_n);
  flit_driver #(.FLIT_WIDTH(F), .NUM_VCS(V), .BUFFER_DEPTH(D)) driver(
    .link(link), .cmd_valid, .cmd_flit, .cmd_vc, .cmd_ready, .credits);
  flit_monitor #(.FLIT_WIDTH(F), .NUM_VCS(V)) monitor(
    .link(link), .observed, .observed_flit, .observed_vc,
    .observed_credit, .observed_credit_vc);

  // Check command-to-link timing/data; this mirrors the driver's admission rule.
  always @(posedge clk) begin
    if (!rst_n) begin
      admitted <= 0;
      admitted_flit <= '0;
      admitted_vc <= '0;
    end else begin
      if (link.flit_valid !== admitted ||
          (admitted && {link.flit_vc, link.flit} !== {admitted_vc, admitted_flit}))
        $fatal(1, "driver command-to-link mismatch");
      admitted <= cmd_valid && cmd_ready;
      admitted_flit <= cmd_flit;
      admitted_vc <= cmd_vc;
    end
  end

  for (genvar v = 0; v < V; v++) begin : g_fifo
    input_fifo #(.WIDTH(F), .DEPTH(D)) u_fifo(
      .clk, .rst_n, .wr_valid(rst_n && link.flit_valid && int'(link.flit_vc) == v),
      .wr_data(link.flit), .rd_ready(rd_ready[v]), .rd_valid(rd_valid[v]),
      .rd_data(rd_data[v]), .count(count[v]), .full(full[v]), .empty(empty[v]), .credit_out(credit[v]));
    // Normal traffic obeys s6/P02; tb_fifo_empty_read probes illegal requests separately.
    assign rd_ready[v] = rst_n && drain && drain_vc == v && rd_valid[v];
  end

  // Models input_port's single return register, not an extra FIFO register.
  always @(posedge clk) begin
    link.credit_valid <= 0;
    link.credit_vc <= '0;
    popped <= 0;
    popped_flit <= '0;
    popped_vc <= 0;
    sampled_credit <= rst_n && link.credit_valid;
    sampled_credit_vc <= (rst_n && link.credit_valid) ? link.credit_vc : '0;
    previous_valid <= rst_n && link.flit_valid;
    if (rst_n) begin
      if (previous_valid && link.flit_valid) b2b_edges <= b2b_edges + 1;
      for (int unsigned v = 0; v < V; v++) begin
        if (credit[v] !== (rd_ready[v] && rd_valid[v]))
          $fatal(1, "FIFO credit is not same-cycle dequeue");
        if (rd_ready[v] && rd_valid[v]) begin
          popped <= 1;
          popped_flit <= rd_data[v];
          popped_vc <= VW'(v);
          link.credit_valid <= 1;
          link.credit_vc <= VW'(v);
        end
      end
      if (cmd_valid && cmd_ready && link.credit_valid) begin
        if (cmd_vc == link.credit_vc) same_vc <= same_vc + 1;
        else different_vc <= different_vc + 1;
      end
      if (link.flit_valid && credits[link.flit_vc] == 0) last_credit <= last_credit + 1;
    end
  end

  always @(negedge clk) begin
    if (rst_n && (observed_credit !== sampled_credit ||
        observed_credit_vc !== sampled_credit_vc))
      $fatal(1, "monitor credit observation mismatch");
  end

  // A separate queue per generated VC avoids dynamic queue-array tool limitations.
  for (genvar v = 0; v < V; v++) begin : g_check
    flit_t expected[$];
    // Queue operations must take effect immediately before comparing the head.
    /* verilator lint_off BLKSEQ */
    always @(negedge clk) begin : check_queue
      flit_t wanted;
      if (!rst_n) expected.delete();
      else begin
        if (observed && int'(observed_vc) == v) expected.push_back(observed_flit);
        if (popped && int'(popped_vc) == v) begin
          if (expected.size() == 0) $fatal(1, "unexpected FIFO output");
          wanted = expected.pop_front();
          if (popped_flit !== wanted) $fatal(1, "FIFO data corruption/reordering");
        end
        if (int'(count[v]) != expected.size() ||
            empty[v] != (count[v] == 0) || full[v] != (int'(count[v]) == D))
          $fatal(1, "FIFO occupancy mismatch");
        if (credits[v] + int'(count[v]) +
            int'(link.flit_valid && int'(link.flit_vc) == v) +
            int'(link.credit_valid && int'(link.credit_vc) == v) != D)
          $fatal(1, "credit conservation failure");
      end
    end
    /* verilator lint_on BLKSEQ */
  end

  function automatic flit_t make_flit(input int unsigned id, idx, len);
    flit_pkt #(F) pkt = new();
    pkt.hdr.ftype = len == 1 ? HEAD_TAIL : idx == 0 ? HEAD : idx == len-1 ? TAIL : BODY;
    pkt.hdr.pkt_id = PKT_ID_W'(id);
    pkt.hdr.flit_idx = FLIT_IDX_W'(idx);
    pkt.hdr.dst_x = 3'd3;
    pkt.hdr.dst_y = 3'd4;
    pkt.payload = (F-HDR_W)'({4{32'hA5C3_1234}} ^ (128'(id) * 128'(19) + 128'(idx)));
    return pkt.pack();
  endfunction

  // b2b=1: caller sits at a negedge (previous send just returned), load the next command in the same
  // low phase so flit_valid stays high on consecutive edges (INTERFACE.md s4). b2b=0: one idle cycle.
  task automatic send(input int unsigned vc, id, idx, len, input bit b2b = 0);
    int unsigned waited = 0;
    if (vc >= (1 << VW)) $fatal(1, "test command VC cannot be encoded");
    if (!b2b || clk) @(negedge clk);
    cmd_vc = VW'(vc); cmd_flit = make_flit(id, idx, len); cmd_valid = 1;
    do begin
      @(posedge clk);
      waited++;
      if (waited > 200) $fatal(1, "driver admission timeout");
    end while (!cmd_ready);
    @(negedge clk); cmd_valid = 0;
  endtask

  // Caller may assert reset immediately in a low phase with a transfer pending.
  task automatic reset_now;
    rst_n = 0; cmd_valid = 0; drain = 0;
    repeat (3) @(negedge clk);
    for (int unsigned v = 0; v < V; v++)
      if (credits[v] != D || count[v] != 0) $fatal(1, "reset state mismatch");
    if (link.flit_valid || link.credit_valid) $fatal(1, "reset valid mismatch");
    rst_n = 1;
  endtask

  task automatic reset_link;
    @(negedge clk);
    reset_now();
  endtask

  task automatic drain_one(input int unsigned vc);
    @(negedge clk); drain_vc = vc; drain = 1;
    repeat (D+5) @(negedge clk);
    drain = 0;
    if (credits[vc] != D || count[vc] != 0) $fatal(1, "drain did not restore credits");
  endtask

  initial begin
    done = 0;
    reset_link();
    if ($test$plusargs("bad_framing")) send(0, 1, 1, 3);
    if ($test$plusargs("bad_vc") && V == 3) send(V, 1, 0, 1);
    for (int unsigned v = 0; v < V; v++) begin
      drain = 0;
      for (int unsigned i = 0; i < D; i++) send(v, v, i, D+2);
      repeat (3) @(negedge clk);
      if (credits[v] != 0 || int'(count[v]) != D) $fatal(1, "FIFO never filled");
      fork
        begin
          send(v, v, D, D+2);
          send(v, v, D+1, D+2);
        end
        begin
          repeat (3) @(negedge clk);
          if (cmd_ready || link.flit_valid) $fatal(1, "zero-credit stall failed");
          drain_vc = v; drain = 1;
        end
      join
      drain_one(v);
    end
    // Interleave VC packets, with a return for VC0 while reserving VC1.
    if (V > 1) begin
      send(0, 32, 0, 2);
      send(1, 33, 0, 2);
      @(negedge clk); drain_vc = 0; drain = 1;
      @(negedge clk);
      cmd_vc = VW'(1); cmd_flit = make_flit(33, 1, 2); cmd_valid = 1;
      @(negedge clk);
      if (!(link.flit_valid && link.flit_vc == VW'(1)))
        $fatal(1, "coincident VC1 send not admitted");
      cmd_valid = 0; drain = 0;
      send(0, 32, 1, 2);
      for (int unsigned v = 0; v < V; v++) drain_one(v);
    end
    // Full-rate fill: D consecutive valid edges per VC, then drain while the tail of the packet
    // is still arriving (simultaneous enq/deq, s6 table row "between empty/full, 1, 1").
    for (int unsigned v = 0; v < V; v++) begin
      automatic int unsigned b2b_before = b2b_edges;
      drain = 0;
      for (int unsigned i = 0; i < D; i++) send(v, 80+v, i, D+2, 1'b1);
      if (int'(count[v]) != D-1) $fatal(1, "full-rate fill lost a flit");
      drain_vc = v; drain = 1;
      // The last registered fill flit is accepted at the next rising edge.
      @(posedge clk); @(negedge clk);
      if (b2b_edges - b2b_before < D-1) $fatal(1, "missing back-to-back valid edges");
      send(v, 80+v, D, D+2, 1'b1);
      send(v, 80+v, D+1, D+2, 1'b1);
      drain_one(v);
    end
    // Seeded packets, VC choice and consumer delay exercise repeated wraparound.
    for (int unsigned n = 0; n < 20; n++) begin
      automatic int unsigned rv = $urandom_range(0, V-1);
      automatic int unsigned len = $urandom_range(1, D+3);
      automatic int unsigned delay_cycles = $urandom_range(1, D+3);
      automatic bit b2b = 1'($urandom_range(0, 1)); // half the packets at full link rate
      drain = 0;
      fork
        begin
          for (int unsigned i = 0; i < len; i++) send(rv, 100+n, i, len, b2b);
        end
        begin
          repeat (delay_cycles) @(negedge clk);
          drain_vc = rv; drain = 1;
        end
      join
      drain_one(rv);
    end
    // Retain the buffered-head flush test as well as the pending-transfer cases.
    send(0, 39, 0, 3);
    @(negedge clk);
    if (count[0] != 1) $fatal(1, "reset test missed buffered head");
    reset_now();
    // Interrupt a pending flit before its FIFO acceptance edge.
    send(0, 40, 0, 3);
    if (!link.flit_valid) $fatal(1, "reset test missed pending flit");
    reset_now();
    // Interrupt a registered return before the driver can consume its credit.
    send(0, 41, 0, 3);
    @(negedge clk); drain_vc = 0; drain = 1;
    @(negedge clk);
    if (!link.credit_valid) $fatal(1, "reset test missed pending credit");
    reset_now();
    for (int unsigned v = 0; v < V; v++) begin
      send(v, 64+v, 0, 1);
      drain_one(v);
    end
    if (same_vc == 0 || (V > 1 && different_vc == 0) || last_credit == 0)
      $fatal(1, "missing credit corner-case stimulus");
    $display("F=%0d V=%0d D=%0d PASS: same=%0d different=%0d last=%0d",
             F, V, D, same_vc, different_vc, last_credit);
    done = 1;
  end
endmodule
`default_nettype wire
