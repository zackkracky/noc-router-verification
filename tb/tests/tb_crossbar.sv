//tb_crossbar: self-checking TB for crossbar; zero-select, exhaustive (o,p) one-hot sweep, random permutations and partial matchings, unselected outputs read zero; (FLIT_WIDTH,NUM_VCS) = (64,2) (32,1) (128,4) (64,3)
/* verilator lint_off DECLFILENAME */

//xb_chk: one DUT at (FW,NV) plus its checks, combinational so stimulus settles on #1
module xb_chk
  import noc_pkg::*;
#(
  parameter int unsigned FW   = DEF_FLIT_WIDTH,
  parameter int unsigned NV   = DEF_NUM_VCS,
  parameter int unsigned SEED = 1,
  parameter int unsigned NRND = 200
) (
  input  wire logic start,
  output logic      done,
  output int        errs,
  output int        checks
);
  localparam int unsigned VW = vc_w(NV);

  int unsigned seed_v;
  int          seed_r;
  logic [NUM_PORTS-1:0][NUM_PORTS-1:0] xbar_sel;
  logic [NUM_PORTS-1:0][FW-1:0]        xb_flit;
  logic [NUM_PORTS-1:0][VW-1:0]        xb_vc;
  logic [NUM_PORTS-1:0][FW-1:0]        issue_flit;
  logic [NUM_PORTS-1:0][VW-1:0]        issue_vc;

  crossbar #(.FLIT_WIDTH(FW), .NUM_VCS(NV)) dut (.*);

  //src[o] = input selected for output o, or -1 for none
  task automatic expect_map(input int src [NUM_PORTS], input string tag);
    for (int unsigned o = 0; o < NUM_PORTS; o++) begin
      logic [FW-1:0] ef = (src[o] < 0) ? '0 : xb_flit[src[o]];//unselected must read zero
      logic [VW-1:0] ev = (src[o] < 0) ? '0 : xb_vc[src[o]];
      checks++;
      if (issue_flit[o] !== ef || issue_vc[o] !== ev) begin
        errs++;
        if (errs <= 10) $display("FAIL FW=%0d NV=%0d %s: out%0d exp src %0d flit %h vc %0d, got flit %h vc %0d",
                                 FW, NV, tag, o, src[o], ef, ev, issue_flit[o], issue_vc[o]);
      end
    end
  endtask

  task automatic drive_map(input int src [NUM_PORTS]);
    xbar_sel = '0;
    for (int unsigned o = 0; o < NUM_PORTS; o++) if (src[o] >= 0) xbar_sel[o][src[o]] = 1'b1;
  endtask

  task automatic rand_data();
    for (int unsigned p = 0; p < NUM_PORTS; p++) begin
      xb_flit[p] = '0;
      for (int unsigned w = 0; w < FW; w += 32) xb_flit[p][w +: 32] = $urandom();//wide flits, 32 bits at a time
      xb_vc[p]   = VW'($urandom_range(NV-1, 0));//legal VC ids only
    end
  endtask

  initial begin
    int src [NUM_PORTS];
    done = 1'b0; errs = 0; checks = 0;
    xbar_sel = '0; xb_flit = '0; xb_vc = '0;
    if (!$value$plusargs("seed=%d", seed_v)) seed_v = 1;
    seed_r = int'(seed_v * 1000 + SEED);//runtime seed x per-instance offset, as tb_switch_allocator
    void'($urandom(seed_r));
    wait (start);

    //1. zero select: every output reads zero
    rand_data();
    foreach (src[o]) src[o] = -1;
    drive_map(src); #1; expect_map(src, "zero-select");

    //2. exhaustive single one-hot, every (o,p), all other outputs zero
    for (int o = 0; o < NUM_PORTS; o++)
      for (int p = 0; p < NUM_PORTS; p++) begin
        rand_data();
        foreach (src[k]) src[k] = -1;
        src[o] = p;
        drive_map(src); #1; expect_map(src, "one-hot");
      end

    //3. random full permutations, maximum matching
    repeat (NRND) begin
      int perm [NUM_PORTS];
      foreach (perm[i]) perm[i] = i;
      for (int i = NUM_PORTS-1; i > 0; i--) begin//fisher-yates
        logic [PORT_W-1:0] j = PORT_W'($urandom_range(i, 0));//sized to the index, no unused bits
        int t = perm[i]; perm[i] = perm[j]; perm[j] = t;
      end
      rand_data(); drive_map(perm); #1; expect_map(perm, "perm");
    end

    //4. random partial matchings on distinct inputs
    repeat (NRND) begin
      logic [NUM_PORTS-1:0] used = '0;
      foreach (src[o]) begin
        src[o] = -1;
        if ($urandom_range(1, 0) == 1)
          for (int p = 0; p < NUM_PORTS; p++)
            if (!used[p] && src[o] == -1) begin used[p] = 1'b1; src[o] = p; end
      end
      rand_data(); drive_map(src); #1; expect_map(src, "partial");
    end

    done = 1'b1;
  end
endmodule

module tb_crossbar;
  logic start = 1'b0;
  logic d1, d2, d3, d4;
  int   e1, e2, e3, e4;
  int   c1, c2, c3, c4;

  xb_chk #(.FW(64),  .NV(2), .SEED(1)) u_def  (.start(start), .done(d1), .errs(e1), .checks(c1));//defaults
  xb_chk #(.FW(32),  .NV(1), .SEED(2)) u_min  (.start(start), .done(d2), .errs(e2), .checks(c2));//narrowest, VC_W floor 1
  xb_chk #(.FW(128), .NV(4), .SEED(3)) u_max  (.start(start), .done(d3), .errs(e3), .checks(c3));//widest
  xb_chk #(.FW(64),  .NV(3), .SEED(4)) u_npo2 (.start(start), .done(d4), .errs(e4), .checks(c4));//non-power-of-2 VCs

  initial begin
    #1 start = 1'b1;
    wait (d1 && d2 && d3 && d4);
    #1 $finish;//verdict printed in final
  end

  final begin
    $display("==========================================");
    $display(" FW   NV  done  errs  checks");
    $display(" 64   2   %b     %0d     %0d", d1, e1, c1);
    $display(" 32   1   %b     %0d     %0d", d2, e2, c2);
    $display(" 128  4   %b     %0d     %0d", d3, e3, c3);
    $display(" 64   3   %b     %0d     %0d", d4, e4, c4);
    $display("==========================================");
    if (d1 && d2 && d3 && d4 && (e1 + e2 + e3 + e4) == 0) $display("TEST PASSED");
    else                                                  $display("TEST FAILED errs=%0d", e1 + e2 + e3 + e4);
  end

  string dumpfile;
  initial begin//waves only when make passes +dumpfile= (WAVES=1)
    if ($value$plusargs("dumpfile=%s", dumpfile)) begin
      $dumpfile(dumpfile);
      $dumpvars(0, tb_crossbar);
    end
  end
endmodule
