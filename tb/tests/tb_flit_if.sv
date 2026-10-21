// tb_flit_if: transaction pack/unpack check (historical test-top name retained).
`default_nettype none
module tb_flit_if;
  flit_pkt #(64) pkt;
  initial begin
    #1; // Allow the optional dump hook to open before this short test finishes.
    pkt = new();
    pkt.unpack(64'hC000_0000_0000_0123);
    if (pkt.hdr.ftype != noc_pkg::HEAD_TAIL || pkt.payload !== 34'h123 ||
        pkt.pack() !== 64'hC000_0000_0000_0123) $fatal(1, "transaction unpack/pack mismatch");
    $display("TEST PASSED");
    $finish;
  end
  string dumpfile;
  initial if ($value$plusargs("dumpfile=%s", dumpfile)) begin // waves only when make passes +dumpfile= (WAVES=1)
    $dumpfile(dumpfile);
    $dumpvars(0, tb_flit_if);
  end
endmodule
`default_nettype wire
