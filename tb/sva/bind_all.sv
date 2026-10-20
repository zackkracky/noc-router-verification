// bind_all: attaches every <block>_sva checker to its RTL module; the only place SVA meets RTL
`default_nettype none

bind input_fifo fifo_sva #(
  .DEPTH (DEPTH)
) u_fifo_sva (
  .clk        (clk),
  .rst_n      (rst_n),
  .wr_valid   (wr_valid),
  .rd_ready   (rd_ready),
  .rd_valid   (rd_valid),
  .count      (count),
  .full       (full),
  .empty      (empty),
  .credit_out (credit_out)
);

`default_nettype wire
