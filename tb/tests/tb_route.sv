
`timescale 1ns/1ps
`default_nettype none

module tb_route;

    logic [2:0] dst_x;
    logic [2:0] dst_y;
    logic [2:0] in_port;
    logic [4:0] out_port_onehot;

    integer x;
    integer y;
    integer checks;

    route_unit #(
        .ROUTE_ALGO("XY"),
        .X_COORD(3'd3),
        .Y_COORD(3'd3)
    ) dut (
        .dst_x(dst_x),
        .dst_y(dst_y),
        .in_port(in_port),
        .out_port_onehot(out_port_onehot)
    );

    function automatic logic [4:0] reference_route(
        input logic [2:0] target_x,
        input logic [2:0] target_y
    );
        begin
            if (target_x == 3'd3 && target_y == 3'd3)
                reference_route = 5'b10000;
            else if (target_x != 3'd3)
                reference_route = (target_x > 3'd3)
                                  ? 5'b00010 : 5'b01000;
            else
                reference_route = (target_y > 3'd3)
                                  ? 5'b00001 : 5'b00100;
        end
    endfunction

    initial begin
        dst_x = '0;
        dst_y = '0;
        in_port = 3'd4;
        checks = 0;

        for (x = 0; x < 8; x = x + 1) begin
            for (y = 0; y < 8; y = y + 1) begin
                dst_x = x[2:0];
                dst_y = y[2:0];

                #1;

                if (out_port_onehot !== reference_route(dst_x, dst_y)) begin
                    $error(
                        "FAIL dst=(%0d,%0d) expected=%b actual=%b",
                        x, y,
                        reference_route(dst_x, dst_y),
                        out_port_onehot
                    );
                    $fatal(1);
                end

                if ($countones(out_port_onehot) != 1)
                    $fatal(1, "Output is not one-hot at (%0d,%0d)", x, y);

                checks = checks + 1;
            end
        end

        $display("Checked %0d destination combinations", checks);
        $display("TEST PASSED");
        $finish;
    end

endmodule

`default_nettype wire
