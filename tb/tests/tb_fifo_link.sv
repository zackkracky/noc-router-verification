// tb_fifo_link: parameter matrix for driver/monitor against real input_fifo RTL.
`default_nettype none
module tb_fifo_link;
  bit d32, d64, d128;
  fifo_link_case #(.F(32), .V(2), .D(2)) u_w32(.done(d32));
  fifo_link_case #(.F(64), .V(3), .D(4)) u_w64(.done(d64));
  fifo_link_case #(.F(128), .V(4), .D(8)) u_w128(.done(d128));
  initial begin
    wait (d32 && d64 && d128);
    $display("TEST PASSED");
    $finish;
  end
  string dumpfile;
  initial if ($value$plusargs("dumpfile=%s", dumpfile)) begin
    $dumpfile(dumpfile);
    $dumpvars(0, tb_fifo_link);
  end
  initial begin
    #100000;
    $fatal(1, "FIFO link watchdog timeout");
  end
endmodule
`default_nettype wire
