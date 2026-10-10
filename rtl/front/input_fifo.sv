// input_fifo: synchronous FWFT FIFO with credit return on dequeue
`default_nettype none

module input_fifo #(
    parameter int unsigned WIDTH = 64,
    parameter int unsigned DEPTH = 4,
    parameter int unsigned COUNT_W = $clog2(DEPTH + 1),
    parameter int unsigned PTR_W = $clog2(DEPTH)
) (
    input  logic              clk,
    input  logic              rst_n,

    input  logic              wr_valid,
    input  logic [WIDTH-1:0]  wr_data,

    input  logic              rd_ready,

    output logic              rd_valid,
    output logic [WIDTH-1:0]  rd_data,

    output logic [COUNT_W-1:0] count,
    output logic              full,
    output logic              empty,

    output logic              credit_out
);

logic [WIDTH-1:0] mem [0:DEPTH-1];

logic [PTR_W-1:0] wr_ptr;
logic [PTR_W-1:0] rd_ptr;

logic [COUNT_W-1:0] count_reg;

logic do_write;
logic do_read;

assign full  = (count_reg == COUNT_W'(DEPTH));
assign empty = (count_reg == 0);
assign count = count_reg;

assign do_write = wr_valid && !full;
assign do_read  = rd_ready && !empty;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        wr_ptr <= '0;
    end
    else if (do_write) begin
        mem[wr_ptr] <= wr_data;
        wr_ptr <= wr_ptr + 1'b1;
    end
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        rd_ptr <= '0;
    end
    else if (do_read) begin
        rd_ptr <= rd_ptr + 1'b1;
    end
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        count_reg <= '0;
    end
    else begin
        case ({do_write, do_read})
            2'b10: count_reg <= count_reg + 1'b1;
            2'b01: count_reg <= count_reg - 1'b1;
            default: count_reg <= count_reg;
        endcase
    end
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        credit_out <= 1'b0;
    end
    else begin
        credit_out <= do_read;
    end
end

assign rd_data  = mem[rd_ptr];
assign rd_valid = !empty;

endmodule

`default_nettype wire
