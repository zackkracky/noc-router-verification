
`default_nettype none

module route_unit #(
    parameter string ROUTE_ALGO = "XY",
    parameter int unsigned X_COORD = 0,
    parameter int unsigned Y_COORD = 0,
    parameter int unsigned NUM_VCS = noc_pkg::DEF_NUM_VCS,
    parameter int unsigned BUFFER_DEPTH = noc_pkg::DEF_BUFFER_DEPTH
) (
    input  logic [noc_pkg::COORD_W-1:0] dst_x,
    input  logic [noc_pkg::COORD_W-1:0] dst_y,

    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [noc_pkg::PORT_W-1:0] in_port,
    input  logic [noc_pkg::NUM_PORTS-1:0][NUM_VCS-1:0]
                [noc_pkg::cnt_w(BUFFER_DEPTH)-1:0] route_credit,
    /* verilator lint_on UNUSEDSIGNAL */

    output logic [noc_pkg::NUM_PORTS-1:0] out_port_onehot
);

    localparam int unsigned COORD_W = noc_pkg::COORD_W;

    localparam logic [COORD_W-1:0] XC = COORD_W'(X_COORD);
    localparam logic [COORD_W-1:0] YC = COORD_W'(Y_COORD);

    localparam int unsigned NORTH = 0;
    localparam int unsigned EAST  = 1;
    localparam int unsigned SOUTH = 2;
    localparam int unsigned WEST  = 3;
    localparam int unsigned LOCAL = 4;

    generate
        if (ROUTE_ALGO == "XY") begin : gen_xy

            always_comb begin
                out_port_onehot = '0;

                if ((X_COORD < 7) && (dst_x > XC))
                    out_port_onehot[EAST] = 1'b1;
                else if ((X_COORD > 0) && (dst_x < XC))
                    out_port_onehot[WEST] = 1'b1;
                else if ((Y_COORD < 7) && (dst_y > YC))
                    out_port_onehot[NORTH] = 1'b1;
                else if ((Y_COORD > 0) && (dst_y < YC))
                    out_port_onehot[SOUTH] = 1'b1;
                else
                    out_port_onehot[LOCAL] = 1'b1;
            end

        end else begin : gen_unsupported

            always_comb begin
                out_port_onehot = '0;
            end

            $error("Unsupported ROUTE_ALGO: %s", ROUTE_ALGO);

        end
    endgenerate

endmodule

`default_nettype wire
