// tb_switch_allocator: self-checking TB for switch_allocator; reference model, s7 contract checks, stage-2-loss pointer hold, stage-1 commitment loss vs max matching, fairness, starvation bound, out-of-range route, random + reset, efficiency; NUM_VCS = 1,2,3,4
`timescale 1ns/1ps
/* verilator lint_off DECLFILENAME */

/*
---------------------------------------------------------------------------
sa_chk: one DUT at NUM_VCS = VC_COUNT plus its reference model and checks
---------------------------------------------------------------------------
*/
module sa_chk
  import noc_pkg::*;
#(
    parameter int unsigned VC_COUNT = 2,
    parameter int unsigned SEED = 1
    ) (
    input  logic clk,
    output logic done, //all phases finished
    output int errs, //error count
    output int max_wait //phase 5 result, reported by the top
    );

    localparam int unsigned PORT_COUNT = NUM_PORTS;
    localparam int unsigned N_SA = VC_COUNT * PORT_COUNT - 1; //PLAN.md R09 bound: (VC_COUNT-1) stage-1 turns of <= PORT_COUNT cycles, then <= PORT_COUNT-1 at stage 2

    logic rst_n;
    logic [PORT_COUNT-1:0][VC_COUNT-1:0] sa_req;
    logic [PORT_COUNT-1:0][VC_COUNT-1:0][PORT_W-1:0] sa_out_port;
    logic [PORT_COUNT-1:0][VC_COUNT-1:0] sa_grant;
    logic [PORT_COUNT-1:0][PORT_COUNT-1:0] xbar_sel;
    logic [PORT_COUNT-1:0] issue;

    switch_allocator #(.NUM_VCS(VC_COUNT)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .sa_req(sa_req),
        .sa_out_port(sa_out_port),
        .sa_grant(sa_grant),
        .xbar_sel(xbar_sel),
        .issue(issue)
    );

    // ---------------- reference model, written independently of the RTL ----------------
    int unsigned m_s1_ptr [PORT_COUNT]; // per input, over VCs
    int unsigned m_s2_ptr [PORT_COUNT]; // per output, over inputs
    int m_s1_win [PORT_COUNT];// stage-1 pick per input, -1 = none
    int m_s2_win [PORT_COUNT];// stage-2 winner input per output, -1 = none
    logic [PORT_COUNT-1:0] m_in_won;
    logic [PORT_COUNT-1:0][VC_COUNT-1:0] exp_grant;
    logic [PORT_COUNT-1:0][PORT_COUNT-1:0] exp_sel;
    logic [PORT_COUNT-1:0] exp_issue;

    // lowest-index requester at or after ptr, wrapping; -1 when none
    function automatic int rr_pick (logic [31:0] r, int unsigned n, int unsigned ptr);
        for (int unsigned k = 0; k < n; k++)
            if (r[(ptr + k) % n]) return int'((ptr + k) % n);
        return -1;
    endfunction

    /* 
    Pure combinational view of the current inputs and pointer state.Called both at check
    time and at the sampling edge, so its blocking assignments are intentional:BLKSEQ is
    a false positive for a procedural evaluation task.
    */
    
    /* verilator lint_off BLKSEQ */
    task automatic model_eval();
        logic [31:0] s2r;
        for (int unsigned p = 0; p < PORT_COUNT; p++)
            m_s1_win[p] = rr_pick(32'(sa_req[p]), VC_COUNT, m_s1_ptr[p]);

        for (int unsigned o = 0; o < PORT_COUNT; o++) begin
            s2r = '0;
        for (int unsigned p = 0; p < PORT_COUNT; p++)
            if (m_s1_win[p] >= 0 && sa_out_port[p][m_s1_win[p]] == PORT_W'(o)) s2r[p] = 1'b1;
        m_s2_win[o]  = rr_pick(s2r, PORT_COUNT, m_s2_ptr[o]);
        exp_sel[o]   = (m_s2_win[o] < 0) ? '0 : (PORT_COUNT'(1) << m_s2_win[o]);
        exp_issue[o] = (m_s2_win[o] >= 0);
        end

        for (int unsigned p = 0; p < PORT_COUNT; p++) begin
        m_in_won[p]  = 1'b0;
        for (int unsigned o = 0; o < PORT_COUNT; o++) if (m_s2_win[o] == int'(p)) m_in_won[p] = 1'b1;
        exp_grant[p] = m_in_won[p] ? (VC_COUNT'(1) << m_s1_win[p]) : '0;
        end
    endtask
    /* verilator lint_on BLKSEQ */

    // ---------------- s7 contract checks, independent of the model ----------------
    task automatic contract(string tag);
        int hits;
        int o_of;
        for (int unsigned o = 0; o < PORT_COUNT; o++) begin
        if (!$onehot0(xbar_sel[o])) begin
            errs++;
            if (errs <= 10) $display("FAIL VC_COUNT=%0d %s: xbar_sel[%0d] not onehot0 %b", VC_COUNT, tag, o, xbar_sel[o]);
        end
        if (issue[o] !== (|xbar_sel[o])) begin
            errs++;
            if (errs <= 10) $display("FAIL VC_COUNT=%0d %s: issue[%0d]=%b |xbar_sel=%b", VC_COUNT, tag, o, issue[o], |xbar_sel[o]);
        end
        end
        for (int unsigned p = 0; p < PORT_COUNT; p++) begin
        if (!$onehot0(sa_grant[p])) begin
            errs++;
            if (errs <= 10) $display("FAIL VC_COUNT=%0d %s: sa_grant[%0d] not onehot0 %b", VC_COUNT, tag, p, sa_grant[p]);
        end
        if ((sa_grant[p] & ~sa_req[p]) != '0) begin // SA never re-checks credit: grant must be a subset of req
            errs++;
            if (errs <= 10) $display("FAIL VC_COUNT=%0d %s: grant outside req p=%0d %b/%b", VC_COUNT, tag, p, sa_grant[p], sa_req[p]);
        end
        // every asserted sa_grant[p][v] has exactly one xbar_sel[o][p], at o == sa_out_port[p][v]
        for (int unsigned v = 0; v < VC_COUNT; v++)
            if (sa_grant[p][v]) begin
            hits = 0;
            o_of = int'(sa_out_port[p][v]);
            for (int unsigned o = 0; o < PORT_COUNT; o++)
                if (xbar_sel[o][p]) begin
                hits++;
                if (int'(o) != o_of) begin
                    errs++;
                    if (errs <= 10) $display("FAIL VC_COUNT=%0d %s: grant p=%0d v=%0d routed to %0d but sel at o=%0d", VC_COUNT, tag, p, v, o_of, o);
                end
                end
            if (hits != 1) begin
                errs++;
                if (errs <= 10) $display("FAIL VC_COUNT=%0d %s: grant p=%0d v=%0d has %0d sel columns", VC_COUNT, tag, p, v, hits);
            end
            end
        // reverse direction: a selected input has exactly one final grant
        hits = 0;
        for (int unsigned o = 0; o < PORT_COUNT; o++) if (xbar_sel[o][p]) hits++;
        if (hits > 1) begin
            errs++;
            if (errs <= 10) $display("FAIL VC_COUNT=%0d %s: input %0d selected at %0d outputs", VC_COUNT, tag, p, hits);
        end
        if (hits != ((|sa_grant[p]) ? 1 : 0)) begin
            errs++;
            if (errs <= 10) $display("FAIL VC_COUNT=%0d %s: input %0d sel=%0d grant=%b", VC_COUNT, tag, p, hits, |sa_grant[p]);
        end
        end
    endtask

    task automatic check(string tag);
        model_eval();
        if (sa_grant !== exp_grant || xbar_sel !== exp_sel || issue !== exp_issue) begin
        errs++;
        if (errs <= 10) begin
            $display("FAIL VC_COUNT=%0d %s: model mismatch", VC_COUNT, tag);
            $display("  req=%p oport=%p", sa_req, sa_out_port);
            $display("  grant got=%p exp=%p", sa_grant, exp_grant);
            $display("  sel   got=%p exp=%p", xbar_sel, exp_sel);
            $display("  issue got=%b exp=%b  s1ptr=%p s2ptr=%p", issue, exp_issue, m_s1_ptr, m_s2_ptr);
        end
        end
        contract(tag);
    endtask

    // Model pointers update on the same edge the DUT samples, re-evaluating the inputs
    // present at that edge. Stimulus must therefore be stable from the check to the posedge.
    always @(posedge clk) begin
        if (!rst_n) begin
        for (int unsigned i = 0; i < PORT_COUNT; i++) begin
            m_s1_ptr[i] <= 0;
            m_s2_ptr[i] <= 0;
        end
        end else begin
        model_eval();
        for (int unsigned p = 0; p < PORT_COUNT; p++)                          // stage 1 rotates on final grant only (s7.2)
            if (m_in_won[p]) m_s1_ptr[p] <= (int'(m_s1_win[p]) + 1) % VC_COUNT;
        for (int unsigned o = 0; o < PORT_COUNT; o++)                          // stage 2 rotates on its own grant
            if (m_s2_win[o] >= 0) m_s2_ptr[o] <= (int'(m_s2_win[o]) + 1) % PORT_COUNT;
        end
    end

    // stimulus is driven after the negedge and held past the posedge, as in tb_rr_arbiter
    task automatic hold_step(string tag);                             // stimulus unchanged this cycle
        @(negedge clk);
        #1 check(tag);
    endtask

    task automatic clr();
        sa_req = '0;
        for (int unsigned p = 0; p < PORT_COUNT; p++)
        for (int unsigned v = 0; v < VC_COUNT; v++) sa_out_port[p][v] = PORT_W'(0);
    endtask

    task automatic put(int unsigned p, int unsigned v, logic [PORT_W-1:0] o); // request on (p,v) routed to o
        sa_req[p][v]      = 1'b1;
        sa_out_port[p][v] = o;
    endtask

    // Max bipartite matching over all requesting (input, VC) edges: the upper bound for any allocator.
    // Kuhn's augmenting paths. Edges with out-of-range codes (>= NUM_PORTS) are excluded.
    bit mm_adj  [PORT_COUNT][PORT_COUNT];
    int mm_mo   [PORT_COUNT];              // output -> matched input, -1 = free
    bit mm_seen [PORT_COUNT];

    function automatic bit mm_aug(int p);
        for (int o = 0; o < PORT_COUNT; o++)
        if (mm_adj[p][o] && !mm_seen[o]) begin
            mm_seen[o] = 1'b1;
            if (mm_mo[o] < 0 || mm_aug(mm_mo[o])) begin
            mm_mo[o] = p;
            return 1'b1;
            end
        end
        return 1'b0;
    endfunction

    function automatic int max_match();
        int n;
        n = 0;
        for (int p = 0; p < PORT_COUNT; p++)
        for (int o = 0; o < PORT_COUNT; o++) mm_adj[p][o] = 1'b0;
        for (int p = 0; p < PORT_COUNT; p++)
        for (int v = 0; v < VC_COUNT; v++)
            if (sa_req[p][v] && int'(sa_out_port[p][v]) < PORT_COUNT) mm_adj[p][int'(sa_out_port[p][v])] = 1'b1;
        for (int o = 0; o < PORT_COUNT; o++) mm_mo[o] = -1;
        for (int p = 0; p < PORT_COUNT; p++) begin
        for (int o = 0; o < PORT_COUNT; o++) mm_seen[o] = 1'b0;
        if (mm_aug(p)) n++;
        end
        return n;
    endfunction

    int mmv, g_n;                 // max matching this cycle, grants this cycle
    int eff_g, eff_m;             // phase 7 accumulators

    int unsigned gcnt [PORT_COUNT];        // phase 4: grants per input
    int unsigned wait_c [PORT_COUNT][VC_COUNT];   // phase 5: cycles each sticky request has waited
    logic [PORT_COUNT-1:0][VC_COUNT-1:0] held;
    int unsigned seed_v;
    int          seed_r;
    int unsigned pairs;
    int unsigned vc_seen [VC_COUNT];     // phase 3: VC spread on the contending inputs
    int unsigned worst_p, worst_v, worst_o;

    initial begin
        done = 1'b0;
        errs = 0;
        max_wait = 0;
        worst_p = 0; worst_v = 0; worst_o = 0;
        rst_n = 1'b0;
        clr();

        if (!$value$plusargs("seed=%d", seed_v)) seed_v = 1;
        seed_r = int'(seed_v * 1000 + SEED);
        void'($urandom(seed_r));
        repeat (2) @(negedge clk);

        //1 reset: pointers 0, so with every VC of every input requesting output 0, input 0 VC 0 wins
        @(negedge clk);
        rst_n = 1'b1;
        for (int unsigned p = 0; p < PORT_COUNT; p++)
        for (int unsigned v = 0; v < VC_COUNT; v++) put(p, v, PORT_W'(0));
        #1 check("reset");
        if (sa_grant[0][0] !== 1'b1 || xbar_sel[0] !== PORT_COUNT'(1)) begin
        errs++; $display("FAIL VC_COUNT=%0d reset: expected grant to p0/v0, got grant=%p sel=%b", VC_COUNT, sa_grant, xbar_sel[0]);
        end

        //2 contract sweep: every (input, VC, output) triple alone -> always granted, uncontended
        pairs = 0;
        for (int unsigned p = 0; p < PORT_COUNT; p++)
        for (int unsigned v = 0; v < VC_COUNT; v++)
            for (int unsigned o = 0; o < PORT_COUNT; o++) begin
            @(negedge clk);
            clr(); put(p, v, PORT_W'(o));
            #1 check("single");
            pairs++;
            if (sa_grant[p][v] !== 1'b1 || xbar_sel[o][p] !== 1'b1 || issue[o] !== 1'b1) begin
                errs++;
                if (errs <= 10) $display("FAIL VC_COUNT=%0d single: p=%0d v=%0d o=%0d not granted", VC_COUNT, p, v, o);
            end
            end
        $display("VC_COUNT=%0d contract: %0d (input,VC,output) triples granted uncontended", VC_COUNT, pairs);

        //3 stage-2 loss holds the stage-1 pointer (kills en = s1_pick_vld[p])
        //  inputs 0 and 1 drive every VC at output 2; the loser must re-offer the same VC, not rotate
        if (VC_COUNT > 1) begin
        for (int unsigned v = 0; v < VC_COUNT; v++) vc_seen[v] = 0;
        @(negedge clk);
        clr();
        for (int unsigned v = 0; v < VC_COUNT; v++) begin put(0, v, PORT_W'(2)); put(1, v, PORT_W'(2)); end
        #1 check("s2loss");
        for (int unsigned c = 0; c < 4 * VC_COUNT * PORT_COUNT; c++) begin
            hold_step("s2loss");
            for (int unsigned p = 0; p < 2; p++)
            for (int unsigned v = 0; v < VC_COUNT; v++) if (sa_grant[p][v]) vc_seen[v]++;
        end
        for (int unsigned v = 0; v < VC_COUNT; v++)                          // a rotate-on-pick bug starves the high VCs
            if (vc_seen[v] == 0) begin
            errs++; $display("FAIL VC_COUNT=%0d s2loss: VC %0d never granted", VC_COUNT, v);
            end
        $display("VC_COUNT=%0d stage-2 loss: VC grant spread %p over %0d cycles", VC_COUNT, vc_seen, 4 * VC_COUNT * PORT_COUNT);
        end

        //3b characterization: in0 VC0->2; in1 VC0->2, VC1->3. Stage 1 commits in1 to VC0, so output 3 idles.
        //  Full-edge maximum matching is 2; the allocator grants 1. Documented loss, not a bug.
        if (VC_COUNT > 1) begin
        @(negedge clk);
        rst_n = 1'b0;                                                    // fresh pointers: directed case assumes ptr = 0
        @(negedge clk);
        rst_n = 1'b1;
        clr();
        put(0, 0, PORT_W'(2));
        put(1, 0, PORT_W'(2));
        put(1, 1, PORT_W'(3));
        #1 check("loss");
        mmv = max_match();
        if (xbar_sel[2] !== PORT_COUNT'(1) || xbar_sel[3] !== '0 || sa_grant[1] !== '0 || mmv != 2) begin
            errs++;
            $display("FAIL VC_COUNT=%0d loss: expected {0->2} only with max matching 2; sel=%p grant=%p max=%0d", VC_COUNT, xbar_sel, sa_grant, mmv);
        end
        $display("VC_COUNT=%0d characterization: 1 grant vs max matching %0d (stage-1 VC commitment)", VC_COUNT, mmv);
        end

        //4 fairness: every input drives one VC at output 0 -> exactly one grant each per PORT_COUNT cycles
        for (int unsigned p = 0; p < PORT_COUNT; p++) gcnt[p] = 0;
        @(negedge clk);
        clr();
        for (int unsigned p = 0; p < PORT_COUNT; p++) put(p, 0, PORT_W'(0));
        #1 check("fair");
        for (int unsigned p = 0; p < PORT_COUNT; p++) if (sa_grant[p][0]) gcnt[p]++;
        for (int unsigned c = 0; c < PORT_COUNT * 20 - 1; c++) begin
        hold_step("fair");
        for (int unsigned p = 0; p < PORT_COUNT; p++) if (sa_grant[p][0]) gcnt[p]++;
        end
        for (int unsigned p = 0; p < PORT_COUNT; p++)
        if (gcnt[p] != 20) begin
            errs++; $display("FAIL VC_COUNT=%0d fair: input %0d got %0d of 20", VC_COUNT, p, gcnt[p]);
        end
        $display("VC_COUNT=%0d fairness: %0d grants each over %0d cycles", VC_COUNT, 20, PORT_COUNT * 20);

        //5 starvation bound: sticky requests with fixed routes; held request granted within N_SA cycles
        held = '0;
        for (int unsigned p = 0; p < PORT_COUNT; p++)
        for (int unsigned v = 0; v < VC_COUNT; v++) wait_c[p][v] = 0;
        @(negedge clk);
        clr();
        for (int unsigned c = 0; c < 4000; c++) begin
        if (c != 0) @(negedge clk);
        for (int unsigned p = 0; p < PORT_COUNT; p++)                          // a new request picks a route and keeps it until granted
            for (int unsigned v = 0; v < VC_COUNT; v++)
            if (!held[p][v]) begin
                held[p][v] = 1'($urandom);
                if (held[p][v]) sa_out_port[p][v] = PORT_W'($urandom_range(0, PORT_COUNT-1));
            end
        sa_req = held;
        #1 check("starve");
        for (int unsigned p = 0; p < PORT_COUNT; p++)
            for (int unsigned v = 0; v < VC_COUNT; v++) begin
            if (sa_grant[p][v]) begin
                wait_c[p][v] = 0;
                held[p][v]   = 1'b0;                                  // granted: the request may drop
            end else if (held[p][v]) begin
                wait_c[p][v]++;
                if (wait_c[p][v] > max_wait) begin
                max_wait = wait_c[p][v];
                worst_p = p; worst_v = v; worst_o = int'(sa_out_port[p][v]);
                end
            end
            end
        end
        if (max_wait > N_SA) begin
        errs++;
        $display("FAIL VC_COUNT=%0d starve: max wait %0d > N_SA %0d, worst (p=%0d,v=%0d,o=%0d)", VC_COUNT, max_wait, N_SA, worst_p, worst_v, worst_o);
        end
        $display("VC_COUNT=%0d starvation: max wait %0d cycles (bound N_SA = VC_COUNT*PORT_COUNT-1 = %0d), worst (p=%0d,v=%0d,o=%0d)",
                 VC_COUNT, max_wait, N_SA, worst_p, worst_v, worst_o);

        //6 out-of-range route: PORT_W carries 8 codes, only 5 are outputs; safety holds, no grant
        if (PORT_COUNT < (1 << PORT_W)) begin
        @(negedge clk);
        clr(); put(0, 0, PORT_W'(PORT_COUNT));                                 // code 5 matches no output
        #1 check("oor");
        if (sa_grant[0][0] !== 1'b0 || issue !== '0) begin
            errs++; $display("FAIL VC_COUNT=%0d oor: out-of-range route granted, grant=%p issue=%b", VC_COUNT, sa_grant, issue);
        end
        $display("VC_COUNT=%0d out-of-range: code %0d yields no grant and blocks the input (needs an assume in formal/assume.sv)", VC_COUNT, PORT_COUNT);
        end

        //7 random: random requests, random in-contract routes, occasional reset, model compared every cycle
        //  also accumulates grants vs max matching for efficiency; grants never exceed the bound
        eff_g = 0; eff_m = 0;
        for (int unsigned c = 0; c < 20000; c++) begin
        @(negedge clk);
        rst_n = ($urandom_range(0, 199) != 0);
        for (int unsigned p = 0; p < PORT_COUNT; p++)
            for (int unsigned v = 0; v < VC_COUNT; v++) begin
            sa_req[p][v]      = 1'($urandom);
            sa_out_port[p][v] = PORT_W'($urandom_range(0, PORT_COUNT-1));
            end
        #1 if (rst_n) begin
            check("random");
            g_n = $countones(xbar_sel);
            mmv = max_match();
            if (g_n > mmv) begin
            errs++;
            if (errs <= 10) $display("FAIL VC_COUNT=%0d random: %0d grants exceed max matching %0d", VC_COUNT, g_n, mmv);
            end
            eff_g += g_n;
            eff_m += mmv;
            end
        end
        @(negedge clk);
        rst_n = 1'b1;
        $display("VC_COUNT=%0d random: 20000 cycles", VC_COUNT);
        $display("VC_COUNT=%0d efficiency: %0d grants / %0d max matching = %0.4f", VC_COUNT, eff_g, eff_m, real'(eff_g) / real'(eff_m));

        done = 1'b1;
    end

endmodule

// ---------------------------------------------------------------------------
// tb_switch_allocator: top, runs all VC counts in parallel
// ---------------------------------------------------------------------------
module tb_switch_allocator
  import noc_pkg::*;
;
  logic clk = 1'b0;
  initial forever #5 clk = ~clk;                                      // 100 MHz

  logic d1, d2, d3, d4;
  int   e1, e2, e3, e4;
  int   w1, w2, w3, w4;

  sa_chk #(.VC_COUNT(1), .SEED(1)) u_v1 (.clk(clk), .done(d1), .errs(e1), .max_wait(w1)); // degenerate stage 1
  sa_chk #(.VC_COUNT(2), .SEED(2)) u_v2 (.clk(clk), .done(d2), .errs(e2), .max_wait(w2)); // DEF_NUM_VCS
  sa_chk #(.VC_COUNT(3), .SEED(3)) u_v3 (.clk(clk), .done(d3), .errs(e3), .max_wait(w3)); // non-power-of-2: unused ptr code
  sa_chk #(.VC_COUNT(4), .SEED(4)) u_v4 (.clk(clk), .done(d4), .errs(e4), .max_wait(w4));

  initial begin
    wait (d1 && d2 && d3 && d4);
    #10;
    $finish;                                                          // verdict printed in final
  end

  final begin                                                         // runs on $finish, incl. watchdog
    $display("==========================================");
    $display(" VC_COUNT   done  errs  maxwait  N_SA  result");
    $display(" 1   %b     %0d     %0d       %0d     %s", d1, e1, w1, 1*NUM_PORTS-1, (d1 && e1 == 0) ? "PASS" : "FAIL");
    $display(" 2   %b     %0d     %0d       %0d     %s", d2, e2, w2, 2*NUM_PORTS-1, (d2 && e2 == 0) ? "PASS" : "FAIL");
    $display(" 3   %b     %0d     %0d       %0d    %s", d3, e3, w3, 3*NUM_PORTS-1, (d3 && e3 == 0) ? "PASS" : "FAIL");
    $display(" 4   %b     %0d     %0d       %0d    %s", d4, e4, w4, 4*NUM_PORTS-1, (d4 && e4 == 0) ? "PASS" : "FAIL");
    $display("==========================================");
    if (d1 && d2 && d3 && d4 && ((e1 + e2 + e3 + e4) == 0))
      $display("TEST PASSED");
    else
      $display("TEST FAILED errs=%0d", e1 + e2 + e3 + e4);
  end

  string dumpfile;
  initial begin                                                       // waves only when make passes +dumpfile= (WAVES=1)
    if ($value$plusargs("dumpfile=%s", dumpfile)) begin
      $dumpfile(dumpfile);
      $dumpvars(0, tb_switch_allocator);
    end
  end

  initial begin                                                       // watchdog
    #50ms;
    $display("watchdog timeout");
    $finish;
  end

endmodule
