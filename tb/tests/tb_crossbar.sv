//tb_crossbar: zero-grant check, exhaustive one-hot sweep, random permutations and partial matchings
module tb_crossbar;

  localparam int NUM_PORTS = noc_pkg::NUM_PORTS;
  localparam int DATA_W    = noc_pkg::DEF_FLIT_WIDTH;
  localparam int N_PERM    = 200;

  logic [NUM_PORTS-1:0][DATA_W-1:0]    data_i;
  logic [NUM_PORTS-1:0][NUM_PORTS-1:0] grant_i;
  logic [NUM_PORTS-1:0][DATA_W-1:0]    data_o;
  logic [NUM_PORTS-1:0]                valid_o;

  int errors = 0;
  int checks = 0;
  int seed;

  crossbar #(.NUM_PORTS(NUM_PORTS), .DATA_W(DATA_W)) dut (.*);

  string dumpfile;
  initial begin                                        //waves only when make passes +dumpfile= (WAVES=1)
    if ($value$plusargs("dumpfile=%s", dumpfile)) begin
      $dumpfile(dumpfile);
      $dumpvars(0, tb_crossbar);
    end
  end

  function automatic void chk(input int o, input logic exp_v, input logic [DATA_W-1:0] exp_d, input string tag);
    checks++;
    if (valid_o[o] !== exp_v) begin
      errors++;
      $error("%s: out%0d valid exp %0b got %0b", tag, o, exp_v, valid_o[o]);
    end else if (exp_v && (data_o[o] !== exp_d)) begin
      errors++;
      $error("%s: out%0d data exp %h got %h", tag, o, exp_d, data_o[o]);
    end
  endfunction

  initial begin
    if (!$value$plusargs("seed=%d", seed)) seed = 1;
    void'($urandom(seed));

    for (int i = 0; i < NUM_PORTS; i++) data_i[i] = DATA_W'($urandom());

    //1. zero grant on every output
    grant_i = '0;
    #1;
    for (int o = 0; o < NUM_PORTS; o++) chk(o, 1'b0, '0, "zero-grant");

    //2. exhaustive single one-hot, every (out,in) pair, other outputs must stay idle
    for (int o = 0; o < NUM_PORTS; o++) begin
      for (int i = 0; i < NUM_PORTS; i++) begin
        grant_i = '0;
        grant_i[o][i] = 1'b1;
        #1;
        for (int oo = 0; oo < NUM_PORTS; oo++) begin
          if (oo == o) chk(oo, 1'b1, data_i[i], "one-hot");
          else         chk(oo, 1'b0, '0,        "one-hot-idle");
        end
      end
    end

    //3. random permutations, every output driven by a distinct input (maximum matching)
    for (int t = 0; t < N_PERM; t++) begin
      automatic int perm [NUM_PORTS];
      for (int i = 0; i < NUM_PORTS; i++) begin
        perm[i]   = i;
        data_i[i] = DATA_W'($urandom());
      end
      for (int i = NUM_PORTS-1; i > 0; i--) begin//fisher-yates
        /* verilator lint_off UNUSEDSIGNAL */
        automatic int j = $urandom_range(i, 0);//int, only low bits used
        /* verilator lint_on UNUSEDSIGNAL */
        automatic int tmp = perm[i]; perm[i] = perm[j]; perm[j] = tmp;
      end
      grant_i = '0;
      for (int o = 0; o < NUM_PORTS; o++) grant_i[o][perm[o]] = 1'b1;
      #1;
      for (int o = 0; o < NUM_PORTS; o++) chk(o, 1'b1, data_i[perm[o]], "perm");
    end

    //4. partial matching, random subset of outputs active on distinct inputs
    for (int t = 0; t < N_PERM; t++) begin
      automatic logic [NUM_PORTS-1:0] used = '0;
      automatic int src [NUM_PORTS];
      grant_i = '0;
      for (int o = 0; o < NUM_PORTS; o++) begin
        src[o] = -1;
        if ($urandom_range(1, 0) == 1) begin//explicit compare, avoids WIDTHTRUNC
          for (int i = 0; i < NUM_PORTS; i++) begin
            if (!used[i] && src[o] == -1) begin
              used[i] = 1'b1;
              src[o]  = i;
              grant_i[o][i] = 1'b1;
            end
          end
        end
      end
      for (int i = 0; i < NUM_PORTS; i++) data_i[i] = DATA_W'($urandom());
      #1;
      for (int o = 0; o < NUM_PORTS; o++) begin
        if (src[o] == -1) chk(o, 1'b0, '0, "partial-idle");
        else              chk(o, 1'b1, data_i[src[o]], "partial");
      end
    end

    $display("tb_crossbar: %0d checks, seed %0d", checks, seed);
    if (errors == 0) $display("TEST PASSED");
    else             $display("TEST FAILED errs=%0d", errors);
    $finish;
  end

endmodule
