`timescale 1ns/1ps

module t_flit_if;
  logic clk = 0;
  logic rst_n = 0;

  always #5 clk <= ~clk;

  flit_if #(.FLIT_WIDTH(64), .NUM_VCS(2)) link (
    .clk(clk),
    .rst_n(rst_n)
  );

  initial begin
    link.flit = '0;
    link.flit_valid = 0;
    link.flit_vc = '0;
    link.credit_valid = 0;
    link.credit_vc = '0;

    repeat (2) @(negedge clk);
    rst_n = 1;

    // Values driven before the rising edge are offered at that edge.
    link.flit = 64'hA5A5_1234_5678_9ABC;
    link.flit_valid = 1;
    link.flit_vc = 1;
    link.credit_valid = 1;
    link.credit_vc = 1;

    @(posedge clk);
    if (!rst_n || !link.flit_valid ||
        link.flit_vc !== 1'b1 ||
        link.flit !== 64'hA5A5_1234_5678_9ABC ||
        !link.credit_valid || link.credit_vc !== 1'b1)
      $fatal(1, "VC1 flit or reverse credit mismatch");

    @(negedge clk);
    link.flit = 64'h0123_4567_89AB_CDEF;
    link.flit_vc = 0;
    link.credit_vc = 0;

    @(posedge clk);
    if (link.flit_vc !== 1'b0 ||
        link.flit !== 64'h0123_4567_89AB_CDEF ||
        link.credit_vc !== 1'b0)
      $fatal(1, "VC0 flit or reverse credit mismatch");

    @(negedge clk);
    link.flit_valid = 0;
    link.credit_valid = 0;

    @(posedge clk);
    if (link.flit_valid || link.credit_valid)
      $fatal(1, "valid signals did not clear");

    $display("TEST PASSED");
    $finish;
  end

  initial begin
    #200;
    $fatal(1, "interface test timed out");
  end
endmodule
