// output_unit.sv -- per-output-port link stage: output-VC ownership, credit-based flow control counters, registered flit to the downstream link.
`default_nettype none

module output_unit #(
  parameter  int unsigned FLIT_WIDTH   = 32,
  parameter  int unsigned NUM_VCS      = 2,
  parameter  int unsigned BUFFER_DEPTH = 4,                      // downstream buffer depth per VC
  parameter  int unsigned FTYPE_MSB    = FLIT_WIDTH-1,           // flit-type field, must match noc_pkg
  parameter  int unsigned FTYPE_LSB    = FLIT_WIDTH-2,           // field must be exactly 2 bits
  parameter  logic [1:0]  FT_TAIL      = 2'b10,
  parameter  logic [1:0]  FT_HEADTAIL  = 2'b11,
  localparam int unsigned VC_W         = (NUM_VCS > 1) ? $clog2(NUM_VCS) : 1,
  localparam int unsigned CRD_W        = $clog2(BUFFER_DEPTH + 1)
) (
  input  logic                  clk,
  input  logic                  rst_n,

  input  logic                  xb_valid_i,                      // from crossbar, <= 1 flit/cycle
  input  logic [FLIT_WIDTH-1:0] xb_flit_i,
  input  logic [VC_W-1:0]       xb_vc_i,                         // output VC id, carried with the flit

  input  logic                  alloc_valid_i,                   // vc_allocator claims an output VC
  input  logic [VC_W-1:0]       alloc_vc_i,

  input  logic                  credit_valid_i,                  // credit returned by downstream
  input  logic [VC_W-1:0]       credit_vc_i,

  output logic                  link_valid_o,
  output logic [FLIT_WIDTH-1:0] link_flit_o,
  output logic [VC_W-1:0]       link_vc_o,

  output logic [NUM_VCS-1:0]    vc_free_o,                       // to vc_allocator
  output logic [NUM_VCS-1:0]    vc_credit_avail_o                // to switch_allocator
);

  logic [NUM_VCS-1:0][CRD_W-1:0] credit_q;
  logic [NUM_VCS-1:0]            vc_busy_q;
  logic [NUM_VCS-1:0]            dec, inc, set, clr;
  logic [1:0]                    ftype;
  logic                          tail_depart;

  assign ftype       = xb_flit_i[FTYPE_MSB:FTYPE_LSB];
  assign tail_depart = xb_valid_i && ((ftype == FT_TAIL) || (ftype == FT_HEADTAIL));

  always_comb begin
    for (int unsigned v = 0; v < NUM_VCS; v++) begin
      dec[v] = xb_valid_i     && (xb_vc_i     == VC_W'(v));      // flit sent on v
      inc[v] = credit_valid_i && (credit_vc_i == VC_W'(v));      // buffer freed downstream on v
      set[v] = alloc_valid_i  && (alloc_vc_i  == VC_W'(v));
      clr[v] = tail_depart    && (xb_vc_i     == VC_W'(v));
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int unsigned v = 0; v < NUM_VCS; v++) credit_q[v] <= CRD_W'(BUFFER_DEPTH);
      vc_busy_q    <= '0;
      link_valid_o <= 1'b0;
      link_flit_o  <= '0;
      link_vc_o    <= '0;
    end else begin
      for (int unsigned v = 0; v < NUM_VCS; v++) begin
        case ({inc[v], dec[v]})
          2'b10:   credit_q[v] <= credit_q[v] + CRD_W'(1);
          2'b01:   credit_q[v] <= credit_q[v] - CRD_W'(1);
          default: credit_q[v] <= credit_q[v];                   // 00 idle, 11 send+return cancel
        endcase
        if      (set[v]) vc_busy_q[v] <= 1'b1;                   // alloc wins over same-cycle tail
        else if (clr[v]) vc_busy_q[v] <= 1'b0;
      end
      link_valid_o <= xb_valid_i;
      if (xb_valid_i) begin
        link_flit_o <= xb_flit_i;                                // data gated to cut switching power
        link_vc_o   <= xb_vc_i;
      end
    end
  end

  assign vc_free_o = ~vc_busy_q;                                 // registered: VC reuse costs 1 cycle

  always_comb begin
    for (int unsigned v = 0; v < NUM_VCS; v++)
      vc_credit_avail_o[v] = (credit_q[v] != CRD_W'(0));
  end

endmodule

`default_nettype wire