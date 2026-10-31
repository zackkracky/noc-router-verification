// skeleton_stubs.sv — tie-off stubs for unmerged submodules; lint-only, never in filelist.f.
`timescale 1ns/1ps
`default_nettype none
/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNDRIVEN */

module input_port 
    import noc_pkg::*; #(
        parameter int FLIT_WIDTH=64, NUM_VCS=2, BUFFER_DEPTH=4,
        parameter int X_COORD=0, Y_COORD=0, MESH_X=2, MESH_Y=2, PORT_ID=0,
        parameter string ROUTE_ALGO="XY",
        localparam int VC_W=(NUM_VCS>1)?$clog2(NUM_VCS):1,
        localparam int PORT_W=$clog2(NUM_PORTS)
    )(
        input  wire logic clk,
        input  wire logic rst_n,
        input  wire logic in_valid,
        input  wire logic [FLIT_WIDTH-1:0] in_flit,
        input  wire logic [VC_W-1:0] in_vc,
        output logic credit_valid,
        output logic [VC_W-1:0] credit_vc,
        output logic [NUM_VCS-1:0] rc_valid,
        output logic [NUM_VCS-1:0][PORT_W-1:0] rc_port,
        input  wire logic [NUM_VCS-1:0] va_grant,
        input  wire logic [NUM_VCS-1:0][VC_W-1:0] va_ovc,
        input  wire logic [NUM_PORTS-1:0][NUM_VCS-1:0] ovc_has_credit,
        output logic [NUM_VCS-1:0] sa_req,
        output logic [NUM_VCS-1:0][PORT_W-1:0] sa_port,
        input  wire logic [NUM_VCS-1:0] sa_grant,
        output logic xb_valid,
        output logic [FLIT_WIDTH-1:0] xb_flit,
        output logic [VC_W-1:0] xb_vc
    );
        assign credit_valid='0;
        assign credit_vc='0;
        assign rc_valid='0; 
        assign rc_port='0;
        assign sa_req='0;
        assign sa_port='0;
        assign xb_valid='0;
        assign xb_flit='0;
        assign xb_vc='0;
    endmodule

    module vc_allocator import noc_pkg::*; #(
    parameter int NUM_VCS=2,
    localparam int VC_W=(NUM_VCS>1)?$clog2(NUM_VCS):1,
    localparam int PORT_W=$clog2(NUM_PORTS)
    )(
    input  wire logic clk,
    input  wire logic rst_n,
    input  wire logic [NUM_PORTS-1:0][NUM_VCS-1:0] rc_valid,
    input  wire logic [NUM_PORTS-1:0][NUM_VCS-1:0][PORT_W-1:0] rc_port,
    input  wire logic [NUM_PORTS-1:0][NUM_VCS-1:0] vc_release,
    output      logic [NUM_PORTS-1:0][NUM_VCS-1:0] va_grant,
    output      logic [NUM_PORTS-1:0][NUM_VCS-1:0][VC_W-1:0] va_ovc
    );
    assign va_grant='0; assign va_ovc='0;
    endmodule

    module output_unit #(
    parameter int FLIT_WIDTH=64, NUM_VCS=2, BUFFER_DEPTH=4,
    localparam int VC_W=(NUM_VCS>1)?$clog2(NUM_VCS):1
    )(
    input  wire logic clk,
    input  wire logic rst_n,
    input  wire logic xb_valid,
    input  wire logic [FLIT_WIDTH-1:0] xb_flit,
    input  wire logic [VC_W-1:0] xb_vc,
    input  wire logic credit_in_valid,
    input  wire logic [VC_W-1:0] credit_in_vc,
    output      logic [NUM_VCS-1:0] has_credit,
    output      logic [NUM_VCS-1:0] vc_release,
    output      logic out_valid,
    output      logic [FLIT_WIDTH-1:0] out_flit,
    output      logic [VC_W-1:0] out_vc
    );
    assign has_credit='0; assign vc_release='0;
    assign out_valid='0;  assign out_flit='0; assign out_vc='0;
    endmodule

    module crossbar import noc_pkg::*; #(
    parameter int FLIT_WIDTH=64, VC_W=1,
    localparam int PORT_W=$clog2(NUM_PORTS)
    )(
    input  wire logic [NUM_PORTS-1:0] in_valid,
    input  wire logic [NUM_PORTS-1:0][FLIT_WIDTH-1:0] in_flit,
    input  wire logic [NUM_PORTS-1:0][VC_W-1:0] in_vc,
    input  wire logic [NUM_PORTS-1:0][PORT_W-1:0] sel,
    input  wire logic [NUM_PORTS-1:0] en,
    output      logic [NUM_PORTS-1:0] out_valid,
    output      logic [NUM_PORTS-1:0][FLIT_WIDTH-1:0] out_flit,
    output      logic [NUM_PORTS-1:0][VC_W-1:0] out_vc
    );
    assign out_valid='0; assign out_flit='0; assign out_vc='0;
    endmodule

/* verilator lint_on UNDRIVEN */
/* verilator lint_on UNUSEDSIGNAL */
`default_nettype wire