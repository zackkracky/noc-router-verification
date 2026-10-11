// SVA checkers P01 through P06 for input_fifo
`default_nettype none

module fifo_sva #(
  parameter int unsigned DEPTH = 4,
  parameter int unsigned WIDTH = 64
)(
  input  logic                   clk,
  input  logic                   rst_n,
  input  logic                   wr_valid,
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic [WIDTH-1:0]       wr_data,
  /* verilator lint_on UNUSEDSIGNAL */
  input  logic                   rd_ready,
  input  logic                   rd_valid,
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic [WIDTH-1:0]       rd_data,
  /* verilator lint_on UNUSEDSIGNAL */
  input  logic [$clog2(DEPTH):0] count,
  input  logic                   full,
  input  logic                   empty,
  input  logic                   credit_out
);

  localparam int unsigned COUNT_W = $clog2(DEPTH) + 1;

/* p01 no write when full*/
  property p_no_write_when_full;
    @(posedge clk) disable iff (!rst_n)
      full |-> !wr_valid;
  endproperty
  a_p01_no_write_when_full: assert property (p_no_write_when_full)
    else $error("P01 write when full");

/*p02 no read when empty*/
  property p_no_read_when_empty;
    @(posedge clk) disable iff (!rst_n)
      empty |-> !rd_ready;
  endproperty
  a_p02_no_read_when_empty: assert property (p_no_read_when_empty)
    else $error("P02 read when empty");

/*p03 count in range*/
  property p_count_in_range;
    @(posedge clk) disable iff (!rst_n)
      count <= COUNT_W'(DEPTH);
  endproperty
  a_p03_count_in_range: assert property (p_count_in_range)
    else $error("P03 count out of range");

/*p04 count inc*/
  property p_count_inc;
    @(posedge clk) disable iff (!rst_n)
      (wr_valid && !full && !rd_ready) |=> (count == $past(count) + 1'b1);
  endproperty
  a_p04_count_inc: assert property (p_count_inc)
    else $error("P04 count increment mismatch");

/*p05 count dec*/
  property p_count_dec;
    @(posedge clk) disable iff (!rst_n)
      (rd_ready && rd_valid && (!wr_valid || full)) |=> (count == $past(count) - 1'b1);
  endproperty
  a_p05_count_dec: assert property (p_count_dec)
    else $error("P05 count decrement mismatch");

/*p06 credit iff dequeue*/
  property p_credit_iff_dequeue;
    @(posedge clk) disable iff (!rst_n)
      credit_out == (rd_ready && rd_valid);
  endproperty
  a_p06_credit_iff_dequeue: assert property (p_credit_iff_dequeue)
    else $error("P06 credit mismatch");

endmodule

`default_nettype wire