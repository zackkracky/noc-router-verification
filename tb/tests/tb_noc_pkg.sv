tb_noc_pkg:checks noc_pkg widths, helpers, encodings, and hdr round-trip at FLIT_WIDTH 32/64/128
`timescale 1ns/1ps
`default_nettype none

/* verilator lint_off DECLFILENAME */
module pkg_probe
  import noc_pkg::*;
#(
  parameter int unsigned FLIT_WIDTH   = DEF_FLIT_WIDTH,
  parameter int unsigned NUM_VCS      = DEF_NUM_VCS,
  parameter int unsigned BUFFER_DEPTH = DEF_BUFFER_DEPTH,
  parameter int unsigned EXP_VC_W     = 1,
  parameter int unsigned EXP_CNT_W    = 3
)(
  input  wire logic [7:0] stim, //8bit input to vary the data
  output logic            err   //high if one or more checks fail 
);
  //derived widths
  localparam int unsigned VC_W  = vc_w(NUM_VCS);
  localparam int unsigned CNT_W = cnt_w(BUFFER_DEPTH);
  localparam int unsigned PAYLOAD_W = FLIT_WIDTH - HDR_W;//could be 2/34/98

  typedef logic [FLIT_WIDTH-1:0] flit_t;                // local, tracks override

  logic [VC_W-1:0] vc_sig;
  logic [CNT_W-1:0] cnt_sig;
  hdr_t hdr_in, hdr_out;
  logic [PAYLOAD_W-1:0] pay_in, pay_out;
  flit_t flit;

  always_comb
  begin
    vc_sig  = '1;//2^VC_W - 1;
    cnt_sig = '1;
    hdr_in  = '0;//same but all zeroes

    hdr_in.ftype    = ftype_e'(stim[1:0]);
    hdr_in.dst_x    = stim[2:0];
    hdr_in.dst_y    = stim[5:3];
    hdr_in.src_x    = ~stim[2:0];
    hdr_in.src_y    = ~stim[5:3];
    hdr_in.pkt_id   = stim;
    hdr_in.flit_idx = ~stim;
    pay_in          = PAYLOAD_W'({16{stim ^ 8'h5A}}); // 128b pattern, sized to payload
    flit            = {hdr_in, pay_in};               //pack the header+payload into the flit                // construction per s2
    hdr_out         = hdr_t'(flit[FLIT_WIDTH-1 -: HDR_W]);
    pay_out         = flit[PAYLOAD_W-1:0];
    err = (VC_W  != EXP_VC_W) || (32'(vc_sig) != (32'd1 << EXP_VC_W) - 1) || (CNT_W != EXP_CNT_W)
    || (32'(cnt_sig) != (32'd1 << EXP_CNT_W) - 1) || (hdr_out != hdr_in)  || (pay_out != pay_in) '
    || (flit[FLIT_WIDTH-1 -: 2] != hdr_in.ftype);//checks top two bits to confirm consideration of most significant end
  end
endmodule
/* verilator lint_on DECLFILENAME */

module tb_noc_pkg;
  import noc_pkg::*;

  logic [7:0] stim;
  logic [3:0] err;
  string dumpfile;

  //manual inputs
  pkg_probe #(.FLIT_WIDTH(32),  .NUM_VCS(2), .BUFFER_DEPTH(2), .EXP_VC_W(1), .EXP_CNT_W(2)) u_w32 (.stim, .err(err[0]));
  pkg_probe #(.FLIT_WIDTH(64),  .NUM_VCS(3), .BUFFER_DEPTH(4), .EXP_VC_W(2), .EXP_CNT_W(3)) u_w64 (.stim, .err(err[1]));
  pkg_probe #(.FLIT_WIDTH(128), .NUM_VCS(4), .BUFFER_DEPTH(8), .EXP_VC_W(2), .EXP_CNT_W(4)) u_w128(.stim, .err(err[2]));
  pkg_probe #(.FLIT_WIDTH(64),  .NUM_VCS(1), .BUFFER_DEPTH(4), .EXP_VC_W(1), .EXP_CNT_W(3)) u_vc1 (.stim, .err(err[3]));
  
  initial begin
    if ($value$plusargs("dumpfile=%s", dumpfile)) begin // set by make WAVES=1
      $dumpfile(dumpfile);
      $dumpvars(0, tb_noc_pkg);
    end

    if ($bits(hdr_t) != HDR_W) $fatal(1,"hdr_t %0d != %0d", $bits(hdr_t), HDR_W);
    if (PORT_W != 3) $fatal(1,"PORT_W drift");
    if (noc_pkg::L != 3'd4 || noc_pkg::N != 3'd0) $fatal(1, "port_e drift");
    if (HEAD_TAIL != 2'd3) $fatal(1, "ftype_e drift");

    for (int i = 0; i < 256; i += 37) begin       // 7 stimulus steps, visible in waves
      stim = 8'(i);
      #10;
      if (err != '0) $fatal(1, "probe err=%b at stim=%0d", err, i);
    end
    $display("TEST PASSED");
    $finish;
  end
endmodule

`default_nettype wire
