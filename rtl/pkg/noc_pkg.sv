// noc_pkg.sv-shared constants,enums,fixed 30-bit header for the 5-port NoC router
`default_nettype none
package noc_pkg;
  /* verilator lint_off UNUSEDPARAM */
  
  //INTERFACE.md section-1
  localparam int unsigned NUM_PORTS   = 5;
  localparam int unsigned PORT_W      = $clog2(NUM_PORTS);//returns 3
  localparam int unsigned COORD_W     = 3;
  localparam int unsigned FTYPE_W     = 2;
  localparam int unsigned PKT_ID_W    = 8;
  localparam int unsigned FLIT_IDX_W  = 8;
  localparam int unsigned HDR_W       = 30;

  //modules override FLIT_WIDTH/NUM_VCS/BUFFER_DEPTH/coords
  localparam int unsigned DEF_FLIT_WIDTH   = 64;//can support 32/128 as well
  //default parameters to fall back
  localparam int unsigned DEF_NUM_VCS      = 2;
  localparam int unsigned DEF_BUFFER_DEPTH = 4;

  /*
  VC_W/CNT_W:derived per module via vc_w()/cnt_w()
  never hardcode vc_w and cnt_w and should be parameter depended
  flit_t: declare locally as logic [FLIT_WIDTH-1:0];
  */

  function automatic int unsigned vc_w(input int unsigned nvcs);
    return (nvcs > 1) ? $clog2(nvcs) : 1;
  endfunction

  function automatic int unsigned cnt_w(input int unsigned depth);
    return $clog2(depth + 1);//DEPTH inclusive
  endfunction

  //Packet structure definition
  typedef enum logic [FTYPE_W-1:0] {
    HEAD = 2'd0,
    BODY = 2'd1,
    TAIL = 2'd2,
    HEAD_TAIL = 2'd3
  } ftype_e;

  //Router Port definition
  typedef enum logic [PORT_W-1:0] {
    N = 3'd0,
    E = 3'd1,
    S = 3'd2,
    W = 3'd3,
    L = 3'd4
  } port_e;

  //VC-states
  typedef enum logic [1:0] {
    IDLE = 2'd0,
    ROUTING = 2'd1,
    WAIT_VC = 2'd2,
    ACTIVE = 2'd3
  } vc_state_e;

  //
  typedef struct packed {
    ftype_e                ftype;     //[29:28]
    logic [COORD_W-1:0]    dst_x;     //[27:25]
    logic [COORD_W-1:0]    dst_y;     //[24:22]
    logic [COORD_W-1:0]    src_x;     //[21:19]
    logic [COORD_W-1:0]    src_y;     //[18:16]
    logic [PKT_ID_W-1:0]   pkt_id;    //[15:8]
    logic [FLIT_IDX_W-1:0] flit_idx;  //[7:0]
  } hdr_t;
  /* verilator lint_on UNUSEDPARAM */
endpackage

`default_nettype wire
