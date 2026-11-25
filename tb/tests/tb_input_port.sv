
`timescale 1ns/1ps
`default_nettype none

module tb_input_port;

    localparam int unsigned FLIT_WIDTH   = 64;
    localparam int unsigned NUM_VCS      = 2;
    localparam int unsigned BUFFER_DEPTH = 4;
    localparam int unsigned VC_W         = noc_pkg::vc_w(NUM_VCS);
    localparam int unsigned CNT_W        = noc_pkg::cnt_w(BUFFER_DEPTH);

    localparam logic [1:0] FTYPE_HEAD_TAIL = 2'd3;
    localparam logic [2:0] ROUTER_X = 3'd3;
    localparam logic [2:0] ROUTER_Y = 3'd3;

    logic clk;
    logic rst_n;

    logic [FLIT_WIDTH-1:0] in_flit;
    logic in_flit_valid;
    logic [VC_W-1:0] in_flit_vc;

    logic [4:0][NUM_VCS-1:0] ocredit_avail;
    logic [4:0][NUM_VCS-1:0][CNT_W-1:0] ocredit_count;

    logic [NUM_VCS-1:0] va_req;
    logic [NUM_VCS-1:0][2:0] va_out_port;
    logic [NUM_VCS-1:0] va_grant;
    logic [NUM_VCS-1:0][VC_W-1:0] va_out_vc;
    logic [NUM_VCS-1:0] va_release;

    logic [NUM_VCS-1:0] sa_req;
    logic [NUM_VCS-1:0][2:0] sa_out_port;
    logic [NUM_VCS-1:0][VC_W-1:0] sa_out_vc;
    logic [NUM_VCS-1:0][FLIT_WIDTH-1:0] sa_flit;
    logic [NUM_VCS-1:0] sa_grant;

    logic in_credit_valid;
    logic [VC_W-1:0] in_credit_vc;

    integer checks;
    logic unused_tb_outputs;

    always #5 clk <= ~clk;

    assign unused_tb_outputs = ^{va_req, va_out_port, va_release, sa_req, sa_out_port, sa_out_vc, sa_flit};

    input_port #(
        .FLIT_WIDTH   (FLIT_WIDTH),
        .NUM_VCS      (NUM_VCS),
        .BUFFER_DEPTH (BUFFER_DEPTH),
        .X_COORD      (3),
        .Y_COORD      (3),
        .ROUTE_ALGO   ("XY"),
        .IN_PORT      (4)
    ) dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_flit          (in_flit),
        .in_flit_valid    (in_flit_valid),
        .in_flit_vc       (in_flit_vc),
        .ocredit_avail    (ocredit_avail),
        .ocredit_count    (ocredit_count),
        .va_req           (va_req),
        .va_out_port      (va_out_port),
        .va_grant         (va_grant),
        .va_out_vc        (va_out_vc),
        .va_release       (va_release),
        .sa_req           (sa_req),
        .sa_out_port      (sa_out_port),
        .sa_out_vc        (sa_out_vc),
        .sa_flit          (sa_flit),
        .sa_grant         (sa_grant),
        .in_credit_valid  (in_credit_valid),
        .in_credit_vc     (in_credit_vc)
    );

    initial begin
        clk             = 1'b0;
        rst_n           = 1'b0;
        in_flit         = '0;
        in_flit_valid   = 1'b0;
        in_flit_vc      = '0;
        ocredit_avail   = '0;
        ocredit_count   = '0;
        va_grant        = '0;
        va_out_vc       = '0;
        sa_grant        = '0;
        checks          = 0;

        // Reset
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        // Construct a local-destination HEAD_TAIL flit.
        in_flit = '0;
        in_flit[FLIT_WIDTH-1 -: 2] = FTYPE_HEAD_TAIL;
        in_flit[FLIT_WIDTH-3 -: 3] = ROUTER_X;
        in_flit[FLIT_WIDTH-6 -: 3] = ROUTER_Y;

        // Inject into input VC 0.
        @(negedge clk);
        in_flit_vc    = '0;
        in_flit_valid = 1'b1;

        @(negedge clk);
        in_flit_valid = 1'b0;

        // Allow IDLE -> ROUTING -> WAIT_VC.
        repeat (3) @(negedge clk);

        #1;
        if (va_req[0] !== 1'b1)
            $fatal(1, "Expected VA request on input VC 0");

        if (va_out_port[0] !== 3'd4)
            $fatal(1, "Expected LOCAL route, got %0d", va_out_port[0]);

        checks = checks + 1;

        // Grant output VC 1 to input VC 0.
        va_out_vc[0] = VC_W'(1);
        va_grant[0]  = 1'b1;

        @(negedge clk);
        va_grant[0] = 1'b0;

        // Output credit is unavailable: SA request must remain low.
        repeat (2) @(negedge clk);
        #1;
        if (sa_req[0] !== 1'b0)
            $fatal(1, "SA request asserted without output credit");

        checks = checks + 1;

        // Make output LOCAL VC 1 available.
        ocredit_avail[4][1] = 1'b1;

        #1;
        if (sa_req[0] !== 1'b1)
            $fatal(1, "Expected SA request after output credit became available");

        if (sa_out_port[0] !== 3'd4 || sa_out_vc[0] !== VC_W'(1))
            $fatal(1, "Incorrect held output route or VC");

        if (sa_flit[0] !== in_flit)
            $fatal(1, "SA flit does not match injected flit");

        checks = checks + 1;

        // Final switch grant dequeues the HEAD_TAIL flit.
        sa_grant[0] = 1'b1;

        #1;
        if (va_release[0] !== 1'b1)
            $fatal(1, "Expected VA release on HEAD_TAIL dequeue");

        @(negedge clk);
        sa_grant[0] = 1'b0;

        #1;
        if (in_credit_valid !== 1'b1)
            $fatal(1, "Expected registered upstream credit return");

        if (in_credit_vc !== VC_W'(0))
            $fatal(1, "Expected upstream credit for input VC 0");

        checks = checks + 1;

        // Credit valid must clear on the following cycle.
        @(negedge clk);
        #1;
        if (in_credit_valid !== 1'b0)
            $fatal(1, "Upstream credit valid did not clear");

        checks = checks + 1;


        // --------------------------------------------------------
        // Multi-flit packet: HEAD -> BODY -> TAIL
        // --------------------------------------------------------

        // Inject HEAD into input VC 0.
        in_flit = '0;
        in_flit[FLIT_WIDTH-1 -: 2] = 2'd0; // HEAD
        in_flit[FLIT_WIDTH-3 -: 3] = ROUTER_X;
        in_flit[FLIT_WIDTH-6 -: 3] = ROUTER_Y;

        @(negedge clk);
        in_flit_vc    = '0;
        in_flit_valid = 1'b1;

        @(negedge clk);
        in_flit_valid = 1'b0;

        repeat (3) @(negedge clk);
        #1;
        if (va_req[0] !== 1'b1)
            $fatal(1, "Multi-flit HEAD did not request VA");

        // Grant the same output VC 1.
        va_out_vc[0] = VC_W'(1);
        va_grant[0]  = 1'b1;

        @(negedge clk);
        va_grant[0] = 1'b0;

        // Queue BODY followed by TAIL.
        in_flit[FLIT_WIDTH-1 -: 2] = 2'd1; // BODY
        in_flit_valid = 1'b1;

        @(negedge clk);
        in_flit[FLIT_WIDTH-1 -: 2] = 2'd2; // TAIL

        @(negedge clk);
        in_flit_valid = 1'b0;

        // HEAD must be presented first.
        #1;
        if (sa_req[0] !== 1'b1 || sa_flit[0][FLIT_WIDTH-1 -: 2] !== 2'd0)
            $fatal(1, "Expected HEAD at switch allocator");

        if (va_req[0] !== 1'b0)
            $fatal(1, "Unexpected VA request while packet is active");

        checks = checks + 1;

        // Dequeue HEAD. It must not release the output VC.
        sa_grant[0] = 1'b1;
        #1;
        if (va_release[0] !== 1'b0)
            $fatal(1, "HEAD incorrectly released output VC");

        @(negedge clk);
        sa_grant[0] = 1'b0;
        #1;
        if (in_credit_valid !== 1'b1 || in_credit_vc !== VC_W'(0))
            $fatal(1, "Missing upstream credit after HEAD dequeue");

        // BODY must now be at the FIFO head.
        @(negedge clk);
        #1;
        if (sa_req[0] !== 1'b1 || sa_flit[0][FLIT_WIDTH-1 -: 2] !== 2'd1)
            $fatal(1, "Expected BODY at switch allocator");

        if (va_release[0] !== 1'b0)
            $fatal(1, "BODY incorrectly released output VC");

        checks = checks + 1;

        // Dequeue BODY. Allocation must remain active.
        sa_grant[0] = 1'b1;
        #1;
        if (va_release[0] !== 1'b0)
            $fatal(1, "BODY asserted VC release");

        @(negedge clk);
        sa_grant[0] = 1'b0;
        #1;
        if (in_credit_valid !== 1'b1 || in_credit_vc !== VC_W'(0))
            $fatal(1, "Missing upstream credit after BODY dequeue");

        // TAIL must be next and must release the output VC on grant.
        @(negedge clk);
        #1;
        if (sa_req[0] !== 1'b1 || sa_flit[0][FLIT_WIDTH-1 -: 2] !== 2'd2)
            $fatal(1, "Expected TAIL at switch allocator");

        sa_grant[0] = 1'b1;
        #1;
        if (va_release[0] !== 1'b1)
            $fatal(1, "TAIL did not release output VC");

        @(negedge clk);
        sa_grant[0] = 1'b0;
        #1;
        if (in_credit_valid !== 1'b1 || in_credit_vc !== VC_W'(0))
            $fatal(1, "Missing upstream credit after TAIL dequeue");

        checks = checks + 1;

        @(negedge clk);
        #1;
        if (va_req[0] !== 1'b0 || sa_req[0] !== 1'b0)
            $fatal(1, "Input VC did not return to idle after TAIL");


        // --------------------------------------------------------
        // Two independent input VCs with different routes
        // --------------------------------------------------------

        // VC 0: LOCAL destination, output VC 1.
        in_flit = '0;
        in_flit[FLIT_WIDTH-1 -: 2] = 2'd3; // HEAD_TAIL
        in_flit[FLIT_WIDTH-3 -: 3] = 3'd3;
        in_flit[FLIT_WIDTH-6 -: 3] = 3'd3;

        @(negedge clk);
        in_flit_vc    = VC_W'(0);
        in_flit_valid = 1'b1;

        @(negedge clk);
        in_flit_valid = 1'b0;

        // VC 1: EAST destination, output VC 0.
        in_flit = '0;
        in_flit[FLIT_WIDTH-1 -: 2] = 2'd3; // HEAD_TAIL
        in_flit[FLIT_WIDTH-3 -: 3] = 3'd4;
        in_flit[FLIT_WIDTH-6 -: 3] = 3'd3;

        @(negedge clk);
        in_flit_vc    = VC_W'(1);
        in_flit_valid = 1'b1;

        @(negedge clk);
        in_flit_valid = 1'b0;

        repeat (3) @(negedge clk);
        #1;

        if (va_req !== 2'b11)
            $fatal(1, "Expected independent VA requests from both VCs");

        if (va_out_port[0] !== 3'd4)
            $fatal(1, "VC 0 expected LOCAL route");

        if (va_out_port[1] !== 3'd1)
            $fatal(1, "VC 1 expected EAST route");

        checks = checks + 1;

        // Grant different output VCs to the two input VCs.
        va_out_vc[0] = VC_W'(1);
        va_out_vc[1] = VC_W'(0);
        va_grant = 2'b11;

        @(negedge clk);
        va_grant = '0;

        // Both output VCs now have credit.
        ocredit_avail[1][0] = 1'b1;
        ocredit_avail[4][1] = 1'b1;

        #1;
        if (sa_req !== 2'b11)
            $fatal(1, "Expected both active VCs to request switch service");

        if (sa_out_port[0] !== 3'd4 || sa_out_vc[0] !== VC_W'(1))
            $fatal(1, "VC 0 lost its LOCAL/output-VC-1 allocation");

        if (sa_out_port[1] !== 3'd1 || sa_out_vc[1] !== VC_W'(0))
            $fatal(1, "VC 1 lost its EAST/output-VC-0 allocation");

        checks = checks + 1;

        // Grant VC 0 only.
        sa_grant = 2'b01;
        #1;
        if (va_release[0] !== 1'b1 || va_release[1] !== 1'b0)
            $fatal(1, "Incorrect release signals for VC 0 grant");

        @(negedge clk);
        sa_grant = '0;
        #1;

        if (in_credit_valid !== 1'b1 || in_credit_vc !== VC_W'(0))
            $fatal(1, "VC 0 dequeue returned incorrect upstream credit");

        if (sa_req[1] !== 1'b1)
            $fatal(1, "VC 1 request was lost after VC 0 grant");

        checks = checks + 1;

        // Grant VC 1 in the following cycle.
        @(negedge clk);
        sa_grant[1] = 1'b1;
        #1;
        if (va_release[1] !== 1'b1)
            $fatal(1, "VC 1 did not release its output VC");

        @(negedge clk);
        sa_grant = '0;
        #1;

        if (in_credit_valid !== 1'b1 || in_credit_vc !== VC_W'(1))
            $fatal(1, "VC 1 dequeue returned incorrect upstream credit");

        checks = checks + 1;

        @(negedge clk);
        #1;
        if (sa_req !== '0 || va_req !== '0)
            $fatal(1, "Both input VCs should be idle after their packets");

        // --------------------------------------------------------
        // Backpressure: no grant, credit withdrawal and recovery
        // --------------------------------------------------------

        // Prepare a new LOCAL HEAD_TAIL packet on input VC 0.
        // Begin with output credit unavailable.
        ocredit_avail[4][1] = 1'b0;

        in_flit = '0;
        in_flit[FLIT_WIDTH-1 -: 2] = FTYPE_HEAD_TAIL;
        in_flit[FLIT_WIDTH-3 -: 3] = ROUTER_X;
        in_flit[FLIT_WIDTH-6 -: 3] = ROUTER_Y;

        @(negedge clk);
        in_flit_vc    = VC_W'(0);
        in_flit_valid = 1'b1;

        @(negedge clk);
        in_flit_valid = 1'b0;

        repeat (3) @(negedge clk);
        #1;
        if (va_req[0] !== 1'b1)
            $fatal(1, "Backpressure packet did not request VA");

        // Allocate output VC 1.
        va_out_vc[0] = VC_W'(1);
        va_grant[0]  = 1'b1;

        @(negedge clk);
        va_grant[0] = 1'b0;

        // No output credit: no SA request.
        #1;
        if (sa_req[0] !== 1'b0)
            $fatal(1, "SA request asserted without output credit");

        checks = checks + 1;

        // Restore credit, but deliberately do not grant the flit.
        ocredit_avail[4][1] = 1'b1;
        #1;
        if (sa_req[0] !== 1'b1)
            $fatal(1, "SA request did not assert after credit restoration");

        if (sa_flit[0] !== in_flit)
            $fatal(1, "Incorrect flit at start of backpressure test");

        // Hold off the grant for two cycles.
        repeat (2) begin
            @(negedge clk);
            #1;
            if (sa_req[0] !== 1'b1)
                $fatal(1, "SA request dropped while waiting for grant");

            if (sa_flit[0] !== in_flit)
                $fatal(1, "FIFO head changed without an SA grant");

            if (in_credit_valid !== 1'b0)
                $fatal(1, "Upstream credit returned without dequeue");
        end

        checks = checks + 1;

        // Withdraw output credit while the flit is still stalled.
        ocredit_avail[4][1] = 1'b0;
        #1;
        if (sa_req[0] !== 1'b0)
            $fatal(1, "SA request remained asserted after credit withdrawal");

        if (sa_flit[0] !== in_flit)
            $fatal(1, "FIFO head changed after output credit withdrawal");

        if (in_credit_valid !== 1'b0)
            $fatal(1, "Credit returned after output credit withdrawal");

        checks = checks + 1;

        // Restore credit and now grant the flit.
        ocredit_avail[4][1] = 1'b1;
        #1;
        if (sa_req[0] !== 1'b1)
            $fatal(1, "SA request did not recover after credit restoration");

        sa_grant[0] = 1'b1;
        #1;
        if (va_release[0] !== 1'b1)
            $fatal(1, "HEAD_TAIL did not release VC on final grant");

        @(negedge clk);
        sa_grant[0] = 1'b0;
        #1;
        if (in_credit_valid !== 1'b1 || in_credit_vc !== VC_W'(0))
            $fatal(1, "Missing upstream credit after backpressure dequeue");

        checks = checks + 1;

        @(negedge clk);
        #1;
        if (sa_req[0] !== 1'b0 || va_req[0] !== 1'b0)
            $fatal(1, "Input VC did not return to idle after backpressure test");

        // --------------------------------------------------------
        // Reset during activity: clear a pending VA request
        // --------------------------------------------------------

        in_flit = '0;
        in_flit[FLIT_WIDTH-1 -: 2] = FTYPE_HEAD_TAIL;
        in_flit[FLIT_WIDTH-3 -: 3] = ROUTER_X;
        in_flit[FLIT_WIDTH-6 -: 3] = ROUTER_Y;

        @(negedge clk);
        in_flit_vc    = VC_W'(0);
        in_flit_valid = 1'b1;

        @(negedge clk);
        in_flit_valid = 1'b0;

        repeat (3) @(negedge clk);
        #1;

        if (va_req[0] !== 1'b1)
            $fatal(1, "Reset test failed to create pending VA request");

        // Reset before the allocator grants the output VC.
        @(negedge clk);
        rst_n = 1'b0;

        repeat (2) @(negedge clk);
        #1;

        if (va_req !== '0 || sa_req !== '0)
            $fatal(1, "Reset did not clear pending allocator requests");

        if (in_credit_valid !== 1'b0)
            $fatal(1, "Reset did not clear upstream credit valid");

        // Release reset and verify that no stale packet reappears.
        @(negedge clk);
        rst_n = 1'b1;

        repeat (3) @(negedge clk);
        #1;

        if (va_req !== '0 || sa_req !== '0)
            $fatal(1, "Stale packet request remained after reset");

        if (in_credit_valid !== 1'b0)
            $fatal(1, "Unexpected upstream credit after reset recovery");

        checks = checks + 1;

        $display("Checked %0d input_port behaviours", checks);
        $display("TEST PASSED");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "TEST TIMEOUT");
    end

endmodule

`default_nettype wire
