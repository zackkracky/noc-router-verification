// Bind declarations for SVA checkers
`default_nettype none

bind input_fifo fifo_sva #(
  .DEPTH(DEPTH),
  .WIDTH(WIDTH)
) u_fifo_sva (
  .clk        (clk),
  .rst_n      (rst_n),
  .wr_valid   (wr_valid),
  .wr_data    (wr_data),
  .rd_ready   (rd_ready),
  .rd_valid   (rd_valid),
  .rd_data    (rd_data),
  .count      (count),
  .full       (full),
  .empty      (empty),
  .credit_out (credit_out)
);

`default_nettype wire
