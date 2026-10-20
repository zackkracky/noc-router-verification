// tb_flit_if: raw-signal link probe for the Verilator 5.020 baseline.
`default_nettype none
module tb_flit_if;
  logic clk = 0, rst_n = 0;
  always #5 clk <= ~clk;
  flit_if link(clk, rst_n);
  flit_pkt #(64) pkt;
  initial begin
    pkt = new();
    pkt.unpack(64'hC000_0000_0000_0123);
    if (pkt.hdr.ftype != noc_pkg::HEAD_TAIL || pkt.payload !== 34'h123 ||
        pkt.pack() !== 64'hC000_0000_0000_0123) $fatal(1, "transaction unpack/pack mismatch");
    link.flit = '0; link.flit_valid = 0; link.flit_vc = '0;
    link.credit_valid = 0; link.credit_vc = '0;
    repeat (2) @(negedge clk);
    rst_n = 1;
    for (int unsigned v = 0; v < 2; v++) begin
      @(negedge clk);
      link.flit = 64'hCAFE + 64'(v); link.flit_vc = 1'(v); link.flit_valid = 1;
      link.credit_vc = 1'(v); link.credit_valid = 1;
      @(posedge link.clk);
      if (!link.rst_n || !link.flit_valid || link.flit !== 64'hCAFE + 64'(v) || link.flit_vc !== 1'(v) ||
          !link.credit_valid || link.credit_vc !== 1'(v)) $fatal(1, "link probe mismatch");
    end
    @(negedge clk); link.flit_valid = 0; link.credit_valid = 0;
    @(posedge link.clk);
    if (link.flit_valid || link.credit_valid) $fatal(1, "link valids did not clear");
    $display("TEST PASSED");
    $finish;
  end
  initial begin
    #500;
    $fatal(1, "link probe timeout");
  end
endmodule
`default_nettype wire
