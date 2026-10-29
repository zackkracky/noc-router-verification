// fifo_sva: P01-P06 for input_fifo (INTERFACE.md s6); attached by bind_all.sv, clk / sync rst_n
`default_nettype none

module fifo_sva #(
  parameter int unsigned DEPTH = 4                       // input_fifo.DEPTH; WIDTH not needed (no data properties)
) (
  input  wire logic                         clk,
  input  wire logic                         rst_n,
  input  wire logic                         wr_valid,
  input  wire logic                         rd_ready,
  input  wire logic                         rd_valid,
  input  wire logic [$clog2(DEPTH + 1)-1:0] count,            // same width as input_fifo.count
  input  wire logic                         full,
  input  wire logic                         empty,
  input  wire logic                         credit_out
);

  localparam int unsigned COUNT_W = $clog2(DEPTH + 1);

  property p_no_write_when_full;                         // P01 protocol (environment): producer never writes when full
    @(posedge clk) disable iff (!rst_n)
      full |-> !wr_valid;
  endproperty

  property p_no_read_when_empty;                         // P02 protocol (environment): rd_ready is a pop strobe, never when empty
    @(posedge clk) disable iff (!rst_n)
      empty |-> !rd_ready;
  endproperty

  property p_count_in_range;                             // P03 safety: occupancy never exceeds DEPTH
    @(posedge clk) disable iff (!rst_n)
      count <= COUNT_W'(DEPTH);
  endproperty

  property p_count_inc;                                  // P04 safety: write-only cycle adds exactly one
    @(posedge clk) disable iff (!rst_n)
      (wr_valid && !full && !rd_ready) |=> (count == $past(count) + 1'b1);
  endproperty

  property p_count_dec;                                  // P05 safety: read-only cycle removes exactly one
    @(posedge clk) disable iff (!rst_n)
      (rd_ready && rd_valid && (!wr_valid || full)) |=> (count == $past(count) - 1'b1);
  endproperty

  property p_credit_iff_dequeue;                         // P06 protocol: credit_out combinational, same cycle as dequeue
    @(posedge clk) disable iff (!rst_n)
      credit_out == (rd_ready && rd_valid);
  endproperty

`ifdef FORMAL
  a_p01_no_write_when_full: assume property (p_no_write_when_full);    // constraint on free inputs in formal
  a_p02_no_read_when_empty: assume property (p_no_read_when_empty);
`else
  a_p01_no_write_when_full: assert property (p_no_write_when_full)
    else $error("P01 write when full");
  a_p02_no_read_when_empty: assert property (p_no_read_when_empty)
    else $error("P02 read when empty");
`endif

  a_p03_count_in_range: assert property (p_count_in_range)
    else $error("P03 count out of range");

  a_p04_count_inc: assert property (p_count_inc)
    else $error("P04 count increment mismatch");

  a_p05_count_dec: assert property (p_count_dec)
    else $error("P05 count decrement mismatch");

  a_p06_credit_iff_dequeue: assert property (p_credit_iff_dequeue)
    else $error("P06 credit mismatch");

endmodule

`default_nettype wire
