
`default_nettype none

module route_unit #(
    parameter string ROUTE_ALGO = "XY",
    parameter logic [2:0] X_COORD = 3'd3,
    parameter logic [2:0] Y_COORD = 3'd3
) (
    input  logic [2:0] dst_x,
    input  logic [2:0] dst_y,

    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [2:0] in_port,
    /* verilator lint_on UNUSEDSIGNAL */

    output logic [4:0] out_port_onehot
);

    localparam int NORTH = 0;
    localparam int EAST  = 1;
    localparam int SOUTH = 2;
    localparam int WEST  = 3;
    localparam int LOCAL = 4;

    generate
        if (ROUTE_ALGO == "XY") begin : gen_xy

            always_comb begin
                out_port_onehot = 5'b00000;

                if (dst_x > X_COORD)
                    out_port_onehot[EAST] = 1'b1;
                else if (dst_x < X_COORD)
                    out_port_onehot[WEST] = 1'b1;
                else if (dst_y > Y_COORD)
                    out_port_onehot[NORTH] = 1'b1;
                else if (dst_y < Y_COORD)
                    out_port_onehot[SOUTH] = 1'b1;
                else
                    out_port_onehot[LOCAL] = 1'b1;
            end

        end else begin : gen_unsupported

            always_comb begin
                out_port_onehot = 5'b00000;
            end

        end
    endgenerate

endmodule

`default_nettype wire
