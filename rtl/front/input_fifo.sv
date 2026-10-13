 // input_fifo: synchronous FWFT FIFO; credit_out pulses one cycle after an accepted dequeue
`default_nettype none

module input_fifo #(
    parameter int unsigned WIDTH = 64,
    parameter int unsigned DEPTH = 4
) (
    input  logic             clk,
    input  logic             rst_n,

    input  logic             wr_valid,
    input  logic [WIDTH-1:0] wr_data,

    input  logic             rd_ready,

    output logic             rd_valid,
    output logic [WIDTH-1:0] rd_data,

    output logic [$clog2(DEPTH + 1)-1:0] count,
    output logic             full,
    output logic             empty,

    output logic             credit_out
);

    localparam int unsigned COUNT_W = $clog2(DEPTH + 1);
    localparam int unsigned PTR_W   = $clog2(DEPTH);

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

    initial begin
        if (DEPTH < 2 || (DEPTH & (DEPTH - 1)) != 0) begin
            $error("input_fifo: DEPTH must be a power of two and at least 2");
        end
    end

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

`ifndef SYNTHESIS

    logic sva_past_valid;

    always_ff @(posedge clk) begin
        if (!rst_n)
            sva_past_valid <= 1'b0;
        else
            sva_past_valid <= 1'b1;
    end

    property no_overflow;
        @(posedge clk) disable iff (!rst_n)
            full |-> !do_write;
    endproperty

    property no_underflow;
        @(posedge clk) disable iff (!rst_n)
            empty |-> !do_read;
    endproperty

    property count_in_range;
        @(posedge clk) disable iff (!rst_n)
            count_reg <= COUNT_W'(DEPTH);
    endproperty

    property count_increments_correctly;
        @(posedge clk) disable iff (!rst_n)
            sva_past_valid && $past(do_write && !do_read)
            |-> count_reg == $past(count_reg) + 1'b1;
    endproperty

    property count_decrements_correctly;
        @(posedge clk) disable iff (!rst_n)
            sva_past_valid && $past(do_read && !do_write)
            |-> count_reg == $past(count_reg) - 1'b1;
    endproperty

    property count_holds_correctly;
        @(posedge clk) disable iff (!rst_n)
            sva_past_valid && $past(do_write == do_read)
            |-> count_reg == $past(count_reg);
    endproperty

    assert property (no_overflow)
        else $error("FIFO overflow protection failed");

    assert property (no_underflow)
        else $error("FIFO underflow protection failed");

    assert property (count_in_range)
        else $error("FIFO count out of range");

    assert property (count_increments_correctly)
        else $error("FIFO count failed to increment");

    assert property (count_decrements_correctly)
        else $error("FIFO count failed to decrement");

    assert property (count_holds_correctly)
        else $error("FIFO count failed to hold");

`endif

endmodule

`default_nettype wire
