//tb_output_unit: exact reset depth by drain, credit model, simultaneous inc/dec, launch pipeline
//stimulus is driven on negedge and sampled on posedge, never both in one timestep
module tb_output_unit;

  localparam int FLIT_W       = noc_pkg::DEF_FLIT_WIDTH;
  localparam int NUM_VCS      = noc_pkg::DEF_NUM_VCS;
  localparam int BUFFER_DEPTH = noc_pkg::DEF_BUFFER_DEPTH;
  localparam int VC_W         = noc_pkg::vc_w(NUM_VCS);
  localparam int N_RAND       = 5000;

  logic                clk = 1'b0;
  logic                rst_n;
  logic                send_valid_i;
  logic [VC_W-1:0]     send_vc_i;
  logic [FLIT_W-1:0]   send_flit_i;
  logic                credit_valid_i;
  logic [VC_W-1:0]     credit_vc_i;
  logic [NUM_VCS-1:0]  vc_has_credit_o;
  logic                flit_valid_o;
  logic [VC_W-1:0]     flit_vc_o;
  logic [FLIT_W-1:0]   flit_o;

  int ref_credit [NUM_VCS];//reference model
  int errors = 0, checks = 0, seed;

  /* verilator lint_off BLKSEQ */
  always #5 clk = ~clk;//standard tb clock idiom
  /* verilator lint_on BLKSEQ */

  output_unit #(
    .FLIT_W(FLIT_W), .NUM_VCS(NUM_VCS), .BUFFER_DEPTH(BUFFER_DEPTH)
  ) dut (.*);

  string dumpfile;
  initial begin                                        //waves only when make passes +dumpfile= (WAVES=1)
    if ($value$plusargs("dumpfile=%s", dumpfile)) begin
      $dumpfile(dumpfile);
      $dumpvars(0, tb_output_unit);
    end
  end

  function automatic void chk(input logic cond, input string msg);
    checks++;
    if (!cond) begin errors++; $error("%s", msg); end
  endfunction

  //compare has_credit on every vc against the model
  function automatic void cmp_credits(input string tag);
    for (int v = 0; v < NUM_VCS; v++) begin
      chk(vc_has_credit_o[v] === (ref_credit[v] != 0),
          $sformatf("%s: vc%0d has_credit exp %0b got %0b (ref %0d)",
                    tag, v, (ref_credit[v] != 0), vc_has_credit_o[v], ref_credit[v]));
    end
  endfunction

  //drive one cycle of stimulus: set on negedge, dut samples on the following posedge
  task automatic drive(input logic sv, input logic [VC_W-1:0] svc, input logic [FLIT_W-1:0] fl,
                       input logic cv, input logic [VC_W-1:0] cvc);
    logic              exp_valid;
    logic [VC_W-1:0]   exp_vc;
    logic [FLIT_W-1:0] exp_flit;
    @(negedge clk);
    send_valid_i = sv; send_vc_i = svc; send_flit_i = fl;
    credit_valid_i = cv; credit_vc_i = cvc;
    exp_valid = sv; exp_vc = svc; exp_flit = fl;
    @(posedge clk);
    //model: a simultaneous inc and dec on the same vc cancels
    if (sv && !(cv && cvc == svc)) ref_credit[svc]--;
    if (cv && !(sv && cvc == svc)) ref_credit[cvc]++;
    #1;
    chk(flit_valid_o === exp_valid,
        $sformatf("launch: valid exp %0b got %0b", exp_valid, flit_valid_o));
    if (exp_valid) begin
      chk(flit_o === exp_flit && flit_vc_o === exp_vc,
          $sformatf("launch: exp vc%0d %h got vc%0d %h", exp_vc, exp_flit, flit_vc_o, flit_o));
    end
    for (int v = 0; v < NUM_VCS; v++) begin
      chk(ref_credit[v] >= 0 && ref_credit[v] <= BUFFER_DEPTH,
          $sformatf("model credit vc%0d out of range: %0d", v, ref_credit[v]));
    end
  endtask

  task automatic idle();
    drive(1'b0, '0, '0, 1'b0, '0);
  endtask

  initial begin
    if (!$value$plusargs("seed=%d", seed)) seed = 1;
    void'($urandom(seed));

    rst_n = 1'b0;
    send_valid_i = 1'b0; send_vc_i = '0; send_flit_i = '0;
    credit_valid_i = 1'b0; credit_vc_i = '0;
    for (int v = 0; v < NUM_VCS; v++) ref_credit[v] = BUFFER_DEPTH;

    repeat (3) @(posedge clk);
    #1;
    cmp_credits("reset");//every vc comes out of reset with credit
    chk(flit_valid_o === 1'b0, "reset: flit_valid_o not low");
    @(negedge clk) rst_n = 1'b1;//release off-edge, no race with the dut sampling

    //phase 1: prove the reset depth is exactly BUFFER_DEPTH through the interface alone.
    //vc0 must stay credited for exactly BUFFER_DEPTH sends and go empty on the last one.
    for (int n = 0; n < BUFFER_DEPTH; n++) begin
      chk(vc_has_credit_o[0] === 1'b1,
          $sformatf("depth: vc0 lost credit after only %0d sends", n));
      drive(1'b1, '0, FLIT_W'($urandom()), 1'b0, '0);
    end
    chk(vc_has_credit_o[0] === 1'b0,
        $sformatf("depth: vc0 still credited after %0d sends, reset depth is not %0d",
                  BUFFER_DEPTH, BUFFER_DEPTH));
    cmp_credits("drained");

    //phase 2: refill vc0 and confirm it comes back
    for (int n = 0; n < BUFFER_DEPTH; n++) begin
      drive(1'b0, '0, '0, 1'b1, '0);
      chk(vc_has_credit_o[0] === 1'b1, "refill: vc0 not credited after a returned credit");
    end
    cmp_credits("refilled");

    //phase 3: random traffic against the model
    for (int t = 0; t < N_RAND; t++) begin
      /* verilator lint_off UNUSEDSIGNAL */
      automatic int sv = $urandom_range(NUM_VCS-1, 0);//int, only low bits used
      automatic int cv = $urandom_range(NUM_VCS-1, 0);
      /* verilator lint_on UNUSEDSIGNAL */
      automatic logic do_send = ($urandom_range(2, 0) != 0) && (ref_credit[sv] != 0);
      automatic logic do_cred = ($urandom_range(2, 0) == 0) && (ref_credit[cv] < BUFFER_DEPTH);
      //only send where the model says credit exists, that is the protocol precondition not a dut guard
      if (t % 16 == 0 && ref_credit[sv] != 0 && ref_credit[sv] < BUFFER_DEPTH) begin
        drive(1'b1, VC_W'(sv), FLIT_W'($urandom()), 1'b1, VC_W'(sv));//force the inc/dec collision
      end else begin
        drive(do_send, VC_W'(sv), FLIT_W'($urandom()), do_cred, VC_W'(cv));
      end
      cmp_credits($sformatf("rand t=%0d", t));
    end

    //phase 4: drain vc0 to empty and confirm has_credit deasserts exactly at zero
    while (ref_credit[0] > 0) begin
      drive(1'b1, '0, FLIT_W'($urandom()), 1'b0, '0);
      cmp_credits("drain");
    end
    chk(vc_has_credit_o[0] === 1'b0, "drain: vc0 has_credit stuck high at zero");
    idle();
    chk(vc_has_credit_o[0] === 1'b0, "drain: vc0 has_credit returned without a credit");

    $display("tb_output_unit: %0d checks, seed %0d", checks, seed);
    if (errors == 0) $display("TEST PASSED");
    else             $display("TEST FAILED errs=%0d", errors);
    $finish;
  end

endmodule
