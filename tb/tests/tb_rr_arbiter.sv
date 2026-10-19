// tb_rr_arbiter:self-checking TB for rr_arbiter; exhaustive (ptr x req) sweep, random vs reference model, fairness, starvation bound, en-hold, reset; N = 1,2,3,4,5,8
`timescale 1ns/1ps
/* verilator lint_off DECLFILENAME */  // two modules in one TB file by design

// ---------------------------------------------------------------------------
// rr_arbiter_chk: one DUT of width N plus its reference model and checks
// ---------------------------------------------------------------------------
module rr_arbiter_chk #(
    parameter int N = 5,
    parameter int IDX_W = (N > 1)?$clog2(N):1,
    parameter int SEED = 1
    ) (
    input  logic clk,
    output logic done,// all phases finished
    output int   errs // error count
    );

    logic rst_n;
    logic [N-1:0] req;
    logic en;
    logic [N-1:0] grant;
    logic [IDX_W-1:0] grant_idx;
    logic grant_vld;

    rr_arbiter #(.N(N)) dut (
        .clk (clk),
        .rst_n (rst_n),
        .req (req),
        .en (en),
        .grant (grant),
        .grant_idx (grant_idx),
        .gra
        
        
        
        
        
        
        nt_vld (grant_vld)
    );

    // ---------------- reference model, written independently of the RTL ----------------
    int unsigned ref_ptr;

    function automatic int ref_idx(logic [N-1:0] r, int unsigned p); //r = request vector & p = priority pointer
        for (int unsigned k = 0; k < N; k++)
        if (r[(p+k) % N]) return int'((p+k) % N);
        return -1;
    endfunction

    task automatic check(string tag);
        int e; //expected winning index
        logic [N-1:0] eg; //expected one hot grant
        e   = ref_idx(req, ref_ptr);
        eg  = (e < 0)? '0 : (N'(1) << e);
        if (grant !== eg || grant_vld !== (e >= 0) || (e >= 0 && grant_idx !== IDX_W'(e)))
        begin
        errs++;
        if (errs <= 10)
            $display("FAIL N=%0d %s: ptr=%0d req=%b grant=%b exp=%b idx=%0d vld=%b", N, tag, ref_ptr, req, grant, eg, grant_idx, grant_vld);
        end
        if (!$onehot0(grant))
        begin
        errs++;
        if (errs <= 10) $display("FAIL N=%0d %s: grant not onehot0 %b", N, tag, grant);
        end
        if ((grant & ~req) != '0)
        begin
        errs++; 
        if (errs <= 10) $display("FAIL N=%0d %s: grant outside req %b/%b", N, tag, grant, req);
        end
    endtask

    //model update on the same edge the DUT samples
    always @(posedge clk) begin
        if (!rst_n) ref_ptr <= 0;
        else if (en && (|req)) ref_ptr <= (int'(ref_idx(req, ref_ptr)) + 1) % N;
    end

    //drive on negedge, check comb outputs after settle, before next posedge
    task automatic step(logic [N-1:0] r, logic e, string tag);
        @(negedge clk);
        req = r; en = e;
        #1 check(tag);
    endtask
    //deliberately place the pointer at a chosen requester
    task automatic set_ptr(int unsigned k);
        step(N'(1) << ((k + N-1) % N), 1'b1, "set_ptr");
        @(negedge clk); req = '0; en = 1'b0;
        if (ref_ptr != k) begin errs++; $display("FAIL N=%0d set_ptr: wanted %0d got %0d", N, k, ref_ptr); end
    endtask

    int unsigned cnt [N];   //count
    int unsigned wait_c [N];//how long each continous requestor waits
    int unsigned max_wait;  //largest observed wait  
    logic [N-1:0] held;     //requesters held
    int unsigned seed_v;
    int seed_r;

    initial 
    begin
        done = 1'b0;
        errs = 0;
        rst_n = 1'b0;
        req = '0;
        en = 1'b0;

        if (!$value$plusargs("seed=%d", seed_v)) seed_v = 1;
        
        seed_r = int'(seed_v * 1000 + SEED);
        void'($urandom(seed_r));
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        //1 reset value: ptr = 0, so lowest requester wins
        step('1, 1'b0, "reset");

        //2 exhaustive: every pointer state x every request vector, en=0 so ptr holds
        for (int unsigned k = 0; k < N; k++) 
        begin
            set_ptr(k);
            for (int unsigned r = 0; r < (1 << N); r++) step(N'(r), 1'b0, "exhaustive");
        end
        $display("N=%0d exhaustive: %0d (ptr,req) pairs checked", N, N * (1 << N));
        
        //3 en=0 hold: same req for 3N cycles, grant must not change
        set_ptr(0);
        for (int unsigned c = 0; c < 3 * N; c++) step('1, 1'b0, "enable hold");

        //4 fairness: all request, en=1, N*K cycles -> exactly K grants each
        for (int unsigned i = 0; i < N; i++) cnt[i] = 0;
        for (int unsigned c = 0; c < N*20; c++) 
        begin
            step('1, 1'b1, "fair");
            cnt[grant_idx]++;
        end
        for (int unsigned i = 0; i < N; i++)
        if (cnt[i] != 20) 
        begin 
            errs++; $display("FAIL N=%0d fair: req %0d got %0d of 20", N, i, cnt[i]); 
        end
        $display("N=%0d fairness: %0d grants each over %0d cycles", N, 20, N * 20);

        //5 starvation bound: sticky requests, en=1; a held request is granted within N-1 other grants
        held = '0; max_wait = 0;
        for (int unsigned i = 0; i < N; i++) wait_c[i] = 0;
        for (int unsigned c = 0; c < 2000; c++) 
        begin
            held = held | N'($urandom);// requests stay up until granted
            step(held, 1'b1, "starve");
            for (int unsigned i = 0; i < N; i++) 
                begin
                    if (grant[i]) 
                        begin 
                            wait_c[i] = 0; 
                            held[i] = 1'($urandom); 
                        end
                    else if (held[i]) 
                        begin 
                            wait_c[i]++; 
                            if (wait_c[i] > max_wait) max_wait = wait_c[i];
                        end
                end
        end
        if (max_wait > N - 1)
            begin 
                errs++;
                $display("FAIL N=%0d starve: max wait %0d > %0d", N, max_wait, N - 1); 
            end
        $display("N=%0d starvation: max wait %0d cycles (bound %0d)", N, max_wait, N - 1);

        //6         random: random req, random en, occasional reset, model compared every cycle
        for (int unsigned c = 0; c < 5000; c++) 
        begin
            @(negedge clk);
            rst_n = ($urandom_range(0, 199) != 0);
            req   = N'($urandom);
            en    = 1'($urandom);
            #1 if (rst_n) check("random");
        end
        rst_n = 1'b1;
        $display("N=%0d random: 5000 cycles", N);

        done = 1'b1;
    end

endmodule

// ---------------------------------------------------------------------------
// tb_rr_arbiter: top, runs all widths in parallel
// ---------------------------------------------------------------------------
module tb_rr_arbiter;
  logic clk = 1'b0;
  initial forever #5 clk = ~clk;// 100 MHz

  logic d1, d2, d3, d4, d5, d8;
  int   e1, e2, e3, e4, e5, e8;

  rr_arbiter_chk #(.N(1), .SEED(1)) u_n1 (.clk(clk), .done(d1), .errs(e1));
  rr_arbiter_chk #(.N(2), .SEED(2)) u_n2 (.clk(clk), .done(d2), .errs(e2));
  rr_arbiter_chk #(.N(3), .SEED(3)) u_n3 (.clk(clk), .done(d3), .errs(e3)); //non-power-of-2: unused ptr code
  rr_arbiter_chk #(.N(4), .SEED(4)) u_n4 (.clk(clk), .done(d4), .errs(e4));
  rr_arbiter_chk #(.N(5), .SEED(5)) u_n5 (.clk(clk), .done(d5), .errs(e5)); //SA stage 2 width
  rr_arbiter_chk #(.N(8), .SEED(8)) u_n8 (.clk(clk), .done(d8), .errs(e8)); //full 3-bit ptr, power-of-2

  initial begin
    wait (d1 && d2 && d3 && d4 && d5 && d8);
    #10;
    $finish;                                                  // verdict printed in final
  end

  final begin                                                 // runs on $finish, incl. watchdog
    $display("==========================================");
    $display(" N   done  errs  result");
    $display(" 1   %b     %0d     %s", d1, e1, (d1 && e1 == 0) ? "PASS" : "FAIL");
    $display(" 2   %b     %0d     %s", d2, e2, (d2 && e2 == 0) ? "PASS" : "FAIL");
    $display(" 3   %b     %0d     %s", d3, e3, (d3 && e3 == 0) ? "PASS" : "FAIL");
    $display(" 4   %b     %0d     %s", d4, e4, (d4 && e4 == 0) ? "PASS" : "FAIL");
    $display(" 5   %b     %0d     %s", d5, e5, (d5 && e5 == 0) ? "PASS" : "FAIL");
    $display(" 8   %b     %0d     %s", d8, e8, (d8 && e8 == 0) ? "PASS" : "FAIL");
    $display("==========================================");
    if (d1 && d2 && d3 && d4 && d5 && d8 && ((e1 + e2 + e3 + e4 + e5 + e8) == 0))
      $display("TEST PASSED");
    else
      $display("TEST FAILED errs=%0d", e1 + e2 + e3 + e4 + e5 + e8);
  end

  string dumpfile;
  initial begin                                               // waves only when make passes +dumpfile= (WAVES=1)
    if ($value$plusargs("dumpfile=%s", dumpfile)) begin
      $dumpfile(dumpfile);
      $dumpvars(0, tb_rr_arbiter);
    end
  end

  initial begin                                               // watchdog
    #50ms;
    $display("watchdog timeout");
    $finish;
  end

endmodule
