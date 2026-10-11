
`default_nettype none

module t_fifo;

    localparam int unsigned WIDTH = 8;
    localparam int unsigned DEPTH = 4;
    localparam int unsigned COUNT_W = $clog2(DEPTH + 1);

    logic clk = 0;
    logic rst_n = 0;
    logic wr_valid = 0;
    logic [WIDTH-1:0] wr_data = 0;
    logic rd_ready = 0;

    logic rd_valid;
    logic [WIDTH-1:0] rd_data;
    logic [COUNT_W-1:0] count;
    logic full;
    logic empty;
    logic credit_out;

    int checks = 0;

    input_fifo #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_valid(wr_valid),
        .wr_data(wr_data),
        .rd_ready(rd_ready),
        .rd_valid(rd_valid),
        .rd_data(rd_data),
        .count(count),
        .full(full),
        .empty(empty),
        .credit_out(credit_out)
    );

    always #5 clk <= ~clk;

    initial begin
        $dumpfile("tb/tests/waves/input_fifo.vcd");
        $dumpvars(0, t_fifo);
    end

    task automatic check(
        input logic condition,
        input string message
    );
        checks++;
        if (condition !== 1'b1)
            $fatal(1, "FAIL: %s at time %0t", message, $time);
    endtask

    task automatic reset_fifo;
        @(negedge clk);
        rst_n = 0;
        wr_valid = 0;
        rd_ready = 0;
        wr_data = 0;

        repeat (2) @(negedge clk);
        check(count == 0, "reset count");
        check(empty, "reset empty");
        check(!full, "reset not full");
        check(!rd_valid, "reset read invalid");

        rst_n = 1;
        @(negedge clk);
    endtask

    task automatic push(input logic [WIDTH-1:0] data);
        @(negedge clk);
        wr_valid = 1;
        wr_data = data;
        rd_ready = 0;

        @(negedge clk);
        wr_valid = 0;
        wr_data = 0;
    endtask

    task automatic pop_expect(input logic [WIDTH-1:0] expected);
        @(negedge clk);
        rd_ready = 1;
        wr_valid = 0;

        check(rd_valid, "read valid before dequeue");
        check(rd_data == expected, "FIFO data ordering");

        @(negedge clk);
        rd_ready = 0;

        check(credit_out, "credit returned after dequeue");
    endtask

    initial begin
        $display("=== INPUT FIFO TESTS START ===");

        // 1. Basic write/read ordering
        reset_fifo();

        push(8'hA5);
        push(8'h3C);

        check(count == 2, "basic count after writes");
        check(rd_data == 8'hA5, "first word is A5");

        pop_expect(8'hA5);
        pop_expect(8'h3C);

        check(empty, "basic FIFO drained");
        check(count == 0, "basic final count");

        $display("PASS: basic write/read");

        // 2. Full FIFO and rejected overflow write
        reset_fifo();

        push(8'h11);
        push(8'h22);
        push(8'h33);
        push(8'h44);

        check(full, "FIFO reaches full");
        check(count == COUNT_W'(DEPTH), "full count equals depth");

        @(negedge clk);
        wr_valid = 1;
        wr_data = 8'hFF;

        @(negedge clk);
        wr_valid = 0;
        wr_data = 0;

        check(full, "overflow attempt keeps FIFO full");
        check(count == COUNT_W'(DEPTH), "overflow does not increase count");
        check(rd_data == 8'h11, "overflow preserves oldest word");

        pop_expect(8'h11);
        pop_expect(8'h22);
        pop_expect(8'h33);
        pop_expect(8'h44);

        check(empty, "FIFO drained after overflow test");

        $display("PASS: full and overflow protection");

        // 3. Circular buffer pointer wraparound
        reset_fifo();

        push(8'h10);
        push(8'h20);
        push(8'h30);
        push(8'h40);

        pop_expect(8'h10);
        pop_expect(8'h20);

        push(8'h50);
        push(8'h60);

        check(full, "FIFO full after wraparound writes");
        check(count == COUNT_W'(DEPTH), "wraparound count");

        pop_expect(8'h30);
        pop_expect(8'h40);
        pop_expect(8'h50);
        pop_expect(8'h60);

        check(empty, "wraparound FIFO drained");

        $display("PASS: circular buffer wraparound");

        // 4. Rejected read while empty
        reset_fifo();

        @(negedge clk);
        rd_ready = 1;

        check(empty, "FIFO stays empty before rejected read");
        check(!rd_valid, "read valid low while empty");

        @(negedge clk);
        check(count == 0, "empty read does not change count");
        check(empty, "empty read does not change empty flag");
        check(!credit_out, "rejected read returns no credit");

        rd_ready = 0;
        @(negedge clk);

        $display("PASS: underflow protection");

        // 5. Simultaneous accepted read and write
        reset_fifo();

        push(8'h66);
        push(8'h77);

        @(negedge clk);
        wr_valid = 1;
        wr_data = 8'h88;
        rd_ready = 1;

        check(rd_valid, "simultaneous operation has valid head");
        check(rd_data == 8'h66, "simultaneous read sees old head");

        @(negedge clk);
        wr_valid = 0;
        wr_data = 0;
        rd_ready = 0;

        check(count == 2, "simultaneous read/write preserves count");
        check(credit_out, "simultaneous read returns credit");
        check(rd_data == 8'h77, "oldest remaining word is 77");

        pop_expect(8'h77);
        pop_expect(8'h88);

        check(empty, "simultaneous test FIFO drained");

        $display("PASS: simultaneous read/write");
        $display("TOTAL CHECKS PASSED: %0d", checks);
        $display("TEST PASSED");

        $finish;
    end

endmodule

`default_nettype wire
