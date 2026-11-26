`default_nettype none

module tb_scoreboard;
  import noc_pkg::*;

  localparam int unsigned FLIT_W = DEF_FLIT_WIDTH;
  localparam int unsigned NVCS   = DEF_NUM_VCS;

  logic clk   = 1'b0;
  logic rst_n = 1'b0;

  initial forever #5 clk = ~clk;

  scoreboard #(
    .FLIT_WIDTH(FLIT_W),
    .NUM_VCS   (NVCS),
    .X_COORD   (3),
    .Y_COORD   (3)
  ) dut (
    .clk   (clk),
    .rst_n (rst_n)
  );

  function automatic logic [FLIT_W-1:0] mk_flit(
    input ftype_e               ft,
    input logic [COORD_W-1:0]   dx,
    input logic [COORD_W-1:0]   dy,
    input logic [PKT_ID_W-1:0]  pid,
    input logic [FLIT_IDX_W-1:0] fidx,
    input logic [33:0]          pay
  );
    hdr_t h;
    h = '{ftype: ft, dst_x: dx, dst_y: dy, src_x: 3'd3, src_y: 3'd3, pkt_id: pid, flit_idx: fidx};
    return {h, pay};
  endfunction

  initial begin
    logic [FLIT_W-1:0] q[$];
    bit ok;

    dut.flush();
    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    // 1. Check XY expected_port across all 5 directions from (3,3)
    assert (dut.expected_port(3'd4, 3'd3) == E) else $fatal(1, "XY E failed");
    assert (dut.expected_port(3'd2, 3'd3) == W) else $fatal(1, "XY W failed");
    assert (dut.expected_port(3'd3, 3'd4) == N) else $fatal(1, "XY N failed");
    assert (dut.expected_port(3'd3, 3'd2) == S) else $fatal(1, "XY S failed");
    assert (dut.expected_port(3'd3, 3'd3) == L) else $fatal(1, "XY L failed");

    // 2. Multi-flit packet (HEAD, BODY, TAIL) from L -> N
    q.delete();
    q.push_back(mk_flit(HEAD, 3'd3, 3'd5, 8'd1, 8'd0, 34'h11));
    q.push_back(mk_flit(BODY, 3'd3, 3'd5, 8'd1, 8'd1, 34'h22));
    q.push_back(mk_flit(TAIL, 3'd3, 3'd5, 8'd1, 8'd2, 34'h33));
    dut.push_sent_pkt(L, 1'b0, q);
    dut.check_egress_flit(10, N, 1'b0, L, 1'b0, q[0]);
    dut.check_egress_flit(11, N, 1'b0, L, 1'b0, q[1]);
    dut.check_egress_flit(12, N, 1'b0, L, 1'b0, q[2]);

    // 3. Single-flit HEAD_TAIL packet from W -> E
    q.delete();
    q.push_back(mk_flit(HEAD_TAIL, 3'd6, 3'd1, 8'd2, 8'd0, 34'h44));
    dut.push_sent_pkt(W, 1'b1, q);
    dut.check_egress_flit(20, E, 1'b1, W, 1'b1, q[0]);

    dut.check_end_of_test(ok);
    if (!ok) $fatal(1, "Scoreboard end-of-test failed");

    $display("TEST PASSED");
    $finish;
  end
endmodule

`default_nettype wire
