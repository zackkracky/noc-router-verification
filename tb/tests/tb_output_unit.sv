//tb_output_unit: self-checking TB for output_unit; exact per-VC credit count vs model every cycle, reset depth proved by drain, simultaneous send and return, register loads on issue and clears without one; (F,V,D) = (64,2,4) (32,1,2) (128,4,8) (64,3,4)
/* verilator lint_off DECLFILENAME */

//ou_chk: one DUT at (FW,NV,BD) plus its reference model; drives on negedge, checks after the posedge
module ou_chk
  import noc_pkg::*;
#(
  parameter int unsigned FW   = DEF_FLIT_WIDTH,
  parameter int unsigned NV   = DEF_NUM_VCS,
  parameter int unsigned BD   = DEF_BUFFER_DEPTH,
  parameter int unsigned SEED = 1,
  parameter int unsigned NRND = 5000
) (
  input  wire logic clk,
  output logic      done,
  output int        errs,
  output int        checks
);
  localparam int unsigned VW = vc_w(NV);
  localparam int unsigned CW = cnt_w(BD);

  int unsigned seed_v;
  int          seed_r;
  logic                    rst_n;
  logic                    issue;
  logic [FW-1:0]           issue_flit;
  logic [VW-1:0]           issue_vc;
  logic                    out_credit_valid;
  logic [VW-1:0]           out_credit_vc;
  logic [NV-1:0]           ocredit_avail;
  logic [NV-1:0][CW-1:0]   ocredit_count;
  logic                    out_flit_valid;
  logic [VW-1:0]           out_flit_vc;
  logic [FW-1:0]           out_flit;

  output_unit #(.FLIT_WIDTH(FW), .NUM_VCS(NV), .BUFFER_DEPTH(BD)) dut (.*);

  int unsigned m_cnt [NV];//reference model of the counters

  task automatic chk(input logic cond, input string msg);
    checks++;
    if (!cond) begin
      errs++;
      if (errs <= 10) $display("FAIL F=%0d V=%0d D=%0d %s", FW, NV, BD, msg);
    end
  endtask

  //compare every counter, its avail bit and the model's own range
  task automatic cmp(input string tag);
    for (int unsigned v = 0; v < NV; v++) begin
      chk(ocredit_count[v] === CW'(m_cnt[v]),
          $sformatf("%s: vc%0d count exp %0d got %0d", tag, v, m_cnt[v], ocredit_count[v]));
      chk(ocredit_avail[v] === (m_cnt[v] != 0),
          $sformatf("%s: vc%0d avail exp %0b got %0b", tag, v, (m_cnt[v] != 0), ocredit_avail[v]));
      chk(m_cnt[v] <= BD, $sformatf("%s: model vc%0d out of range %0d", tag, v, m_cnt[v]));
    end
  endtask

  //one cycle: drive on negedge, DUT samples at the posedge, model updates, check after it
  task automatic step(input logic is, input int unsigned iv, input logic rv, input int unsigned cv, input string tag);
    logic [FW-1:0] fl = '0;
    for (int unsigned w = 0; w < FW; w += 32) fl[w +: 32] = $urandom();
    @(negedge clk);
    issue = is; issue_vc = is ? VW'(iv) : '0; issue_flit = is ? fl : '0;
    out_credit_valid = rv; out_credit_vc = rv ? VW'(cv) : '0;
    @(posedge clk);
    if (is && !(rv && cv == iv)) m_cnt[iv]--;//send plus return on one VC nets zero
    if (rv && !(is && cv == iv)) m_cnt[cv]++;
    #1;
    cmp(tag);
    chk(out_flit_valid === is, $sformatf("%s: out_flit_valid exp %0b got %0b", tag, is, out_flit_valid));
    chk(out_flit_vc === (is ? VW'(iv) : '0) && out_flit === (is ? fl : '0),
        $sformatf("%s: out register exp vc%0d %h got vc%0d %h", tag, iv, is ? fl : '0, out_flit_vc, out_flit));
  endtask

  initial begin
    done = 1'b0; errs = 0; checks = 0;
    rst_n = 1'b0; issue = 1'b0; issue_flit = '0; issue_vc = '0;
    out_credit_valid = 1'b0; out_credit_vc = '0;
    foreach (m_cnt[v]) m_cnt[v] = BD;
    if (!$value$plusargs("seed=%d", seed_v)) seed_v = 1;
    seed_r = int'(seed_v * 1000 + SEED);//runtime seed x per-instance offset, as tb_switch_allocator
    void'($urandom(seed_r));

    //reset held over two edges (s8), then every counter reads BUFFER_DEPTH and the register is clear
    repeat (2) @(posedge clk);
    #1 cmp("reset");
    chk(out_flit_valid === 1'b0, "reset: out_flit_valid not low");
    @(negedge clk) rst_n = 1'b1;

    //depth: VC0 stays available for exactly BD sends and goes empty on the last, not before
    for (int unsigned n = 0; n < BD; n++) begin
      chk(ocredit_avail[0] === 1'b1, $sformatf("depth: vc0 lost credit after %0d sends", n));
      step(1'b1, 0, 1'b0, 0, "depth");
    end
    chk(ocredit_avail[0] === 1'b0, "depth: vc0 still available after BD sends");

    //refill VC0 one credit per cycle
    repeat (BD) step(1'b0, 0, 1'b1, 0, "refill");

    //random legal traffic: send only with pre-edge credit, return only below BD
    for (int unsigned t = 0; t < NRND; t++) begin
      int unsigned iv = $urandom_range(NV-1, 0);
      int unsigned cv = $urandom_range(NV-1, 0);
      if (t % 16 == 0 && m_cnt[iv] != 0)
        step(1'b1, iv, 1'b1, iv, "collide");//send and return on one VC in one cycle
      else
        step(($urandom_range(2, 0) != 0) && (m_cnt[iv] != 0), iv,
             ($urandom_range(2, 0) == 0) && (m_cnt[cv] < BD), cv, "random");
    end

    //drain every VC to zero, then one idle cycle: avail stays low and the register clears
    for (int unsigned v = 0; v < NV; v++)
      while (m_cnt[v] != 0) step(1'b1, v, 1'b0, 0, "drain");
    step(1'b0, 0, 1'b0, 0, "idle");

    done = 1'b1;
  end
endmodule

module tb_output_unit;
  logic clk = 1'b0;
  initial forever #5 clk = ~clk;//100 MHz

  logic d1, d2, d3, d4;
  int   e1, e2, e3, e4;
  int   c1, c2, c3, c4;

  ou_chk #(.FW(64),  .NV(2), .BD(4), .SEED(1)) u_def  (.clk(clk), .done(d1), .errs(e1), .checks(c1));//defaults
  ou_chk #(.FW(32),  .NV(1), .BD(2), .SEED(2)) u_min  (.clk(clk), .done(d2), .errs(e2), .checks(c2));//smallest
  ou_chk #(.FW(128), .NV(4), .BD(8), .SEED(3)) u_max  (.clk(clk), .done(d3), .errs(e3), .checks(c3));//largest
  ou_chk #(.FW(64),  .NV(3), .BD(4), .SEED(4)) u_npo2 (.clk(clk), .done(d4), .errs(e4), .checks(c4));//non-power-of-2 VCs

  initial begin
    wait (d1 && d2 && d3 && d4);
    #10 $finish;//verdict printed in final
  end

  final begin
    $display("==========================================");
    $display(" F    V  D  done  errs  checks");
    $display(" 64   2  4  %b     %0d     %0d", d1, e1, c1);
    $display(" 32   1  2  %b     %0d     %0d", d2, e2, c2);
    $display(" 128  4  8  %b     %0d     %0d", d3, e3, c3);
    $display(" 64   3  4  %b     %0d     %0d", d4, e4, c4);
    $display("==========================================");
    if (d1 && d2 && d3 && d4 && (e1 + e2 + e3 + e4) == 0) $display("TEST PASSED");
    else                                                  $display("TEST FAILED errs=%0d", e1 + e2 + e3 + e4);
  end

  string dumpfile;
  initial begin//waves only when make passes +dumpfile= (WAVES=1)
    if ($value$plusargs("dumpfile=%s", dumpfile)) begin
      $dumpfile(dumpfile);
      $dumpvars(0, tb_output_unit);
    end
  end
endmodule
