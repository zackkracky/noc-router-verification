//output_unit: per-VC credit tracking for the downstream input buffer plus flit launch register, credits only
module output_unit #(
  parameter int unsigned FLIT_W       = noc_pkg::DEF_FLIT_WIDTH,
  parameter int unsigned NUM_VCS      = noc_pkg::DEF_NUM_VCS,
  parameter int unsigned BUFFER_DEPTH = noc_pkg::DEF_BUFFER_DEPTH,
  localparam int unsigned VC_W        = noc_pkg::vc_w(NUM_VCS),
  localparam int unsigned CRED_W      = noc_pkg::cnt_w(BUFFER_DEPTH)//holds 0..BUFFER_DEPTH inclusive
) (
  input  wire logic                clk,
  input  wire logic                rst_n,          //sync, active low

  input  wire logic                send_valid_i,   //SA granted this output this cycle
  input  wire logic [VC_W-1:0]     send_vc_i,
  input  wire logic [FLIT_W-1:0]   send_flit_i,

  input  wire logic                credit_valid_i, //credit returned by downstream router
  input  wire logic [VC_W-1:0]     credit_vc_i,

  output logic      [NUM_VCS-1:0]  vc_has_credit_o,//to vc_allocator and switch_allocator
  output logic                     flit_valid_o,
  output logic      [VC_W-1:0]     flit_vc_o,
  output logic      [FLIT_W-1:0]   flit_o
);

  //no vc ownership here, the single busy/owner table stays in vc_allocator
  logic [NUM_VCS-1:0][CRED_W-1:0] credit_q;
  logic                           dec [NUM_VCS];
  logic                           inc [NUM_VCS];

  always_comb begin
    for (int v = 0; v < NUM_VCS; v++) begin
      dec[v] = send_valid_i   && (send_vc_i   == VC_W'(v));
      inc[v] = credit_valid_i && (credit_vc_i == VC_W'(v));
      vc_has_credit_o[v] = (credit_q[v] != '0);
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      for (int v = 0; v < NUM_VCS; v++) credit_q[v] <= CRED_W'(BUFFER_DEPTH);//start full
    end else begin
      for (int v = 0; v < NUM_VCS; v++) begin
        case ({inc[v], dec[v]})
          2'b10:   credit_q[v] <= credit_q[v] + CRED_W'(1);//return only
          2'b01:   credit_q[v] <= credit_q[v] - CRED_W'(1);//send only
          default: credit_q[v] <= credit_q[v];//idle, or simultaneous inc/dec which cancels
        endcase
      end
    end
  end

  //launch register, one cycle of output pipelining, matches INTERFACE.md s7.2
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      flit_valid_o <= 1'b0;
      flit_vc_o    <= '0;
      flit_o       <= '0;
    end else begin
      flit_valid_o <= send_valid_i;
      flit_vc_o    <= send_vc_i;
      flit_o       <= send_flit_i;
    end
  end

  //underflow (dec at credit 0) and overflow (credit > BUFFER_DEPTH) live in sva/output_unit_sva.sv via bind

endmodule
