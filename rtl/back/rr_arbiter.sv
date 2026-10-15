// rr_arbiter: N-way round-robin arbiter; req[N] in, one-hot grant + grant_idx out (comb), pointer advances past winner when en=1
`default_nettype none

module rr_arbiter #(
  parameter int N     = 5,                          // requesters
  parameter int IDX_W = (N > 1) ? $clog2(N) : 1     // index width
) (
  input  logic             clk,
  input  logic             rst_n,                   // sync, active-low
  input  logic [N-1:0]     req,
  input  logic             en,                      // grant consumed: rotate priority
  output logic [N-1:0]     grant,                   // one-hot or zero
  output logic [IDX_W-1:0] grant_idx,               // valid when grant_vld
  output logic             grant_vld                // |req
);

  logic [IDX_W-1:0] ptr_q;                          // highest-priority index
  logic [N-1:0]     mask, req_m, gnt_m, gnt_u;

  always_comb begin
    for (int unsigned i = 0; i < N; i++)
      mask[i] = (i >= 32'(ptr_q));                  // thermometer: bits >= ptr
  end

  assign req_m     = req & mask;                    // requests at/after ptr
  assign gnt_m     = req_m & (-req_m);              // isolate lowest set bit
  assign gnt_u     = req & (-req);                  // wrap-around candidate
  assign grant     = (|req_m) ? gnt_m : gnt_u;
  assign grant_vld = |req;

  always_comb begin
    grant_idx = '0;
    for (int unsigned i = 0; i < N; i++)
      if (grant[i]) grant_idx = IDX_W'(i);          // one-hot -> binary
  end

  always_ff @(posedge clk) begin
    if (!rst_n)
      ptr_q <= '0;
    else if (en && grant_vld)
      ptr_q <= (grant_idx == IDX_W'(N-1)) ? '0 : grant_idx + IDX_W'(1); // winner gets lowest priority
  end

endmodule

`default_nettype wire