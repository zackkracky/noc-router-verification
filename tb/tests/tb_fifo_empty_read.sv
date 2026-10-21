// tb_fifo_empty_read: deliberate illegal s6 requests test FIFO guards, not consumer compliance.
`default_nettype none
module tb_fifo_empty_read;
  logic clk = 0, rst_n = 0, wr_valid = 0, rd_ready = 0;
  always #5 clk <= ~clk;
  logic [31:0] wr_data = 32'hA5C3_1234, rd_data;
  logic rd_valid, full, empty, credit_out;
  logic [2:0] count;
  input_fifo #(.WIDTH(32), .DEPTH(4)) dut(
    .clk, .rst_n, .wr_valid, .wr_data, .rd_ready,
    .rd_valid, .rd_data, .count, .full, .empty, .credit_out);

  task automatic check_empty;
    if (count !== 0 || !empty || full || rd_valid || credit_out)
      $fatal(1, "empty-read guard changed occupancy or returned credit");
  endtask

  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1; rd_ready = 1;
    // P02 is intentionally not bound in this test's filelist (INTERFACE s6).
    repeat (3) begin
      @(negedge clk);
      check_empty();
    end
    // Ready remains asserted across empty -> nonempty -> empty.
    wr_valid = 1;
    @(negedge clk); wr_valid = 0;
    if (count !== 1 || !rd_valid || !credit_out || rd_data !== wr_data)
      $fatal(1, "empty-read probe did not enqueue a real flit");
    @(negedge clk);
    check_empty();
    repeat (3) begin
      @(negedge clk);
      check_empty();
    end
    $display("TEST PASSED");
    $finish;
  end

  string dumpfile;
  initial if ($value$plusargs("dumpfile=%s", dumpfile)) begin
    $dumpfile(dumpfile);
    $dumpvars(0, tb_fifo_empty_read);
  end
endmodule
`default_nettype wire
