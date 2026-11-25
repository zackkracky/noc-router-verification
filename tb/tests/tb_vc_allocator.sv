`timescale 1ns/1ps

module tb_vc_allocator;

    import noc_pkg::*;

    localparam int NUM_VCS_T = DEF_NUM_VCS;
    localparam int VC_W_T = vc_w(NUM_VCS_T);

    logic clk = 0;
    logic rst_n;

    logic [NUM_PORTS-1:0][NUM_VCS_T-1:0] va_req;
    logic [NUM_PORTS-1:0][NUM_VCS_T-1:0][PORT_W-1:0] va_out_port;
    logic [NUM_PORTS-1:0][NUM_VCS_T-1:0] va_release;

    logic [NUM_PORTS-1:0][NUM_VCS_T-1:0] va_grant;
    logic [NUM_PORTS-1:0][NUM_VCS_T-1:0][VC_W_T-1:0] va_out_vc;
    logic [NUM_PORTS-1:0][NUM_VCS_T-1:0] ovc_free;

    int errors = 0;

    always #5 clk <= ~clk;

    vc_allocator #(
        .NUM_VCS(NUM_VCS_T)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .va_req(va_req),
        .va_out_port(va_out_port),
        .va_release(va_release),
        .va_grant(va_grant),
        .va_out_vc(va_out_vc),
        .ovc_free(ovc_free)
    );

    task automatic check(input logic condition, input string message);
        if ((^va_out_vc) === 1'bx) begin
            errors++;
            $display("FAIL: va_out_vc contains unknown bits");
        end
        if (condition !== 1'b1) begin
            errors++;
            $display("FAIL: %s", message);
        end else begin
            $display("PASS: %s", message);
        end
    endtask

    task automatic reset_dut;
        @(negedge clk);
        rst_n = 0;
        va_req = '0;
        va_release = '0;
        va_out_port = '0;
        repeat (2) @(posedge clk);
        #1;
        check(&ovc_free, "reset makes every output VC free");
        @(negedge clk);
        rst_n = 1;
        #1;
    endtask

    initial begin
        rst_n = 0;
        va_req = '0;
        va_release = '0;
        va_out_port = '0;

        reset_dut();

        // Test 1: one requester receives an allocation.
        @(negedge clk);
        va_req[0][0] = 1;
        va_out_port[0][0] = PORT_W'(1);
        #1;
        check(va_grant[0][0], "single requester receives grant");
        check(va_out_vc[0][0] == VC_W_T'(0), "first free output VC is selected");

        @(posedge clk);
        #1;
        check(!ovc_free[1][0], "allocated output VC becomes busy");

        // Test 2: allocated input VC cannot receive another grant.
        #1;
        check(!va_grant[0][0], "active input VC is not granted again");

        // Test 3: another requester can use the remaining output VC.
        @(negedge clk);
        va_req[1][0] = 1;
        va_out_port[1][0] = PORT_W'(1);
        #1;
        check(va_grant[1][0], "second requester receives remaining free VC");
        check(va_out_vc[1][0] == VC_W_T'(1), "second requester receives output VC 1");

        @(posedge clk);
        #1;
        check(!ovc_free[1][1], "second output VC becomes busy");

        // Test 4: release frees the original allocation.
        @(negedge clk);
        va_release[0][0] = 1;
        #1;
        check(!ovc_free[1][0], "release does not free VC before clock edge");

        @(posedge clk);
        #1;
        check(ovc_free[1][0], "release frees output VC after clock edge");

        @(negedge clk);
        va_release[0][0] = 0;
        va_release[1][0] = 1;

        @(posedge clk);
        #1;
        check(ovc_free[1][1], "second allocation can also be released");

        // Test 5: simultaneous requesters cannot receive duplicate grants.
        reset_dut();

        @(negedge clk);
        va_req[0][0] = 1;
        va_req[1][0] = 1;
        va_out_port[0][0] = PORT_W'(2);
        va_out_port[1][0] = PORT_W'(2);
        #1;

        check($countones(va_grant) == 1,
              "simultaneous contenders produce only one initial grant");

        @(posedge clk);
        #1;

        // The second requester should receive the other output VC.
        #1;
        check(va_grant[1][0],
              "waiting requester receives another free output VC");

        check($countones(va_grant) <= 1,
              "no input VC receives duplicate grants");

        if (errors == 0) begin
            $display("--------------------------------");
            $display("TEST PASSED");
        end else begin
            $display("--------------------------------");
            $display("TEST FAILED: %0d errors", errors);
            $fatal(1);
        end

        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "TIMEOUT");
    end

endmodule
