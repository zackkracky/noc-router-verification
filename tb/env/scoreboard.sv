// scoreboard.sv - End-to-end NoC router scoreboard v1 + XY reference model
`default_nettype none

module scoreboard #(
  parameter int unsigned FLIT_WIDTH    = noc_pkg::DEF_FLIT_WIDTH,
  parameter int unsigned NUM_VCS       = noc_pkg::DEF_NUM_VCS,
  parameter int unsigned X_COORD       = 3,
  parameter int unsigned Y_COORD       = 3,
  parameter int unsigned MAX_PKT_FLITS = 16,
  parameter int unsigned MAX_Q_DEPTH   = 64
) (
  /* verilator lint_off UNUSEDSIGNAL */
  input wire logic clk,
  input wire logic rst_n
  /* verilator lint_on UNUSEDSIGNAL */
);
  import noc_pkg::*;

  localparam int unsigned VC_W      = vc_w(NUM_VCS);
  localparam int unsigned NUM_Q     = NUM_PORTS * NUM_VCS;
  localparam int unsigned Q_W       = $clog2(NUM_Q);
  localparam logic [COORD_W-1:0] XC = COORD_W'(X_COORD);
  localparam logic [COORD_W-1:0] YC = COORD_W'(Y_COORD);

  // -------------------------------------------------------------------------
  // Golden XY Reference Model (independent of Revanth's route_unit RTL)
  // Direct comparisons avoid 3-bit unsigned-subtraction underflow.
  // Edge guards (0 / 7) prevent Verilator UNSIGNED / CMPCONST warnings.
  // -------------------------------------------------------------------------
  function automatic port_e expected_port(
    input logic [COORD_W-1:0] dst_x,
    input logic [COORD_W-1:0] dst_y
  );
    if ((X_COORD < 7) && (dst_x > XC))      return E;
    else if ((X_COORD > 0) && (dst_x < XC)) return W;
    else if ((Y_COORD < 7) && (dst_y > YC)) return N;
    else if ((Y_COORD > 0) && (dst_y < YC)) return S;
    else                                    return L;
  endfunction

  function automatic logic [Q_W-1:0] q_idx(
    input port_e           p,
    input logic [VC_W-1:0] v
  );
    return Q_W'((int'(p) * int'(NUM_VCS)) + int'(v));
  endfunction

  // -------------------------------------------------------------------------
  // Packet storage & v1 ring buffers (flattened [src_port * NUM_VCS + src_vc])
  // -------------------------------------------------------------------------
  typedef struct {
    logic [PKT_ID_W-1:0]   pkt_id;
    port_e                 exp_port;
    int unsigned           len;
    logic [FLIT_WIDTH-1:0] flits [MAX_PKT_FLITS];
  } pkt_t;

  pkt_t        sent_buf [NUM_Q][MAX_Q_DEPTH];
  int unsigned q_head   [NUM_Q];
  int unsigned q_tail   [NUM_Q];
  int unsigned q_cnt    [NUM_Q];
  int unsigned rx_flits [NUM_Q];
  int unsigned err_count = 0;

  // -------------------------------------------------------------------------
  // Scoreboard v2 Design (Phase 1b: 14-17 Dec)
  // - Track active open packets per (output_port, out_vc) in a table:
  //   open_pkt[NUM_PORTS * NUM_VCS] + active_valid[NUM_PORTS * NUM_VCS].
  // - On HEAD: look up matching sent packet, bind to open_pkt[out_port, out_vc],
  //   and check exp_port == out_port.
  // - On BODY: attribute flit directly to open_pkt[out_port, out_vc] so
  //   interleaved BODY flits across different VCs on the same link never collide.
  // - On TAIL / HEAD_TAIL: complete verification and clear active_valid.
  // -------------------------------------------------------------------------

  // Flush queues on reset so mid-traffic reset tests do not false-fail
  task automatic flush();
    for (int i = 0; i < int'(NUM_Q); i++) begin
      q_head[i]   = 0;
      q_tail[i]   = 0;
      q_cnt[i]    = 0;
      rx_flits[i] = 0;
    end
    err_count = 0;
  endtask

  // Driver hook: push a complete packet when injected on (src_port, src_vc)
  task automatic push_sent_pkt(
    input port_e                 src_port,
    input logic [VC_W-1:0]       src_vc,
    input logic [FLIT_WIDTH-1:0] pkt_flits[$]
  );
    pkt_t pkt;
    /* verilator lint_off UNUSEDSIGNAL */
    hdr_t head_hdr;
    /* verilator lint_on UNUSEDSIGNAL */
    logic [Q_W-1:0] qi;

    if (pkt_flits.size() == 0 || pkt_flits.size() > int'(MAX_PKT_FLITS)) begin
      $error("scoreboard: invalid pkt_flits size %0d", pkt_flits.size());
      err_count++;
      return;
    end
    qi = q_idx(src_port, src_vc);
    if (q_cnt[qi] >= MAX_Q_DEPTH) begin
      $error("scoreboard: queue overflow on src=%0d vc=%0d", src_port, src_vc);
      err_count++;
      return;
    end

    head_hdr     = hdr_t'(pkt_flits[0][FLIT_WIDTH-1 -: HDR_W]);
    pkt.pkt_id   = head_hdr.pkt_id;
    pkt.exp_port = expected_port(head_hdr.dst_x, head_hdr.dst_y);
    pkt.len      = pkt_flits.size();
    for (int i = 0; i < pkt_flits.size(); i++) begin
      pkt.flits[i] = pkt_flits[i];
    end

    sent_buf[qi][q_tail[qi]] = pkt;
    q_tail[qi] = (q_tail[qi] + 1) % MAX_Q_DEPTH;
    q_cnt[qi]++;
  endtask

  // Monitor hook: check egress flits (v1 checks complete packet on TAIL / HEAD_TAIL)
  task automatic check_egress_flit(
    input int unsigned           cycle,
    input port_e                 out_port,
    input logic [VC_W-1:0]       out_vc,
    input port_e                 src_port,
    input logic [VC_W-1:0]       src_vc,
    input logic [FLIT_WIDTH-1:0] flit
  );
    /* verilator lint_off UNUSEDSIGNAL */
    hdr_t hdr;
    /* verilator lint_on UNUSEDSIGNAL */
    pkt_t exp_pkt;
    logic [Q_W-1:0] qi;
    int unsigned    idx;

    qi  = q_idx(src_port, src_vc);
    hdr = hdr_t'(flit[FLIT_WIDTH-1 -: HDR_W]);

    if (q_cnt[qi] == 0) begin
      $error("SCOREBOARD MISMATCH: pkt_id=%0d cycle=%0d unexpected flit on empty queue (src=%0d vc=%0d)",
             hdr.pkt_id, cycle, src_port, out_vc);
      err_count++;
      return;
    end

    exp_pkt = sent_buf[qi][q_head[qi]];
    idx     = rx_flits[qi];

    if (hdr.pkt_id != exp_pkt.pkt_id) begin
      $error("SCOREBOARD MISMATCH: cycle=%0d expected pkt_id=%0d, got pkt_id=%0d",
             cycle, exp_pkt.pkt_id, hdr.pkt_id);
      err_count++;
    end

    if (out_port != exp_pkt.exp_port) begin
      $error("SCOREBOARD MISMATCH: pkt_id=%0d cycle=%0d expected port=%0d, got port=%0d",
             hdr.pkt_id, cycle, exp_pkt.exp_port, out_port);
      err_count++;
    end

    if (idx >= exp_pkt.len) begin
      $error("SCOREBOARD MISMATCH: pkt_id=%0d cycle=%0d extra flit (expected len=%0d)",
             hdr.pkt_id, cycle, exp_pkt.len);
      err_count++;
    end else if (flit !== exp_pkt.flits[idx]) begin
      $error("SCOREBOARD MISMATCH: pkt_id=%0d cycle=%0d flit[%0d] expected=%h, got=%h",
             hdr.pkt_id, cycle, idx, exp_pkt.flits[idx], flit);
      err_count++;
    end

    rx_flits[qi]++;

    if ((hdr.ftype == TAIL) || (hdr.ftype == HEAD_TAIL)) begin
      if (rx_flits[qi] != exp_pkt.len) begin
        $error("SCOREBOARD MISMATCH: pkt_id=%0d cycle=%0d expected flit_count=%0d, got=%0d",
               hdr.pkt_id, cycle, exp_pkt.len, rx_flits[qi]);
        err_count++;
      end
      q_head[qi]   = (q_head[qi] + 1) % MAX_Q_DEPTH;
      q_cnt[qi]--;
      rx_flits[qi] = 0;
    end
  endtask

  // End-of-test check: every queue must be empty (no_flit_lost / P18)
  task automatic check_end_of_test(output bit ok);
    ok = (err_count == 0);
    for (int i = 0; i < int'(NUM_Q); i++) begin
      if (q_cnt[i] != 0) begin
        ok = 1'b0;
                for (int k = 0; k < int'(q_cnt[i]); k++) begin
          $error("SCOREBOARD FAIL: undelivered pkt_id=%0d in queue=%0d",
                 sent_buf[i][(q_head[i] + k) % MAX_Q_DEPTH].pkt_id, i);
        end
      end
    end
  endtask

endmodule

`default_nettype wire
