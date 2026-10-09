// flit_if: one forward flit link with credits returning in the reverse direction
interface flit_if #(
  parameter int unsigned FLIT_WIDTH = 64,
  parameter int unsigned NUM_VCS = 2
) (
  input logic clk,
  input logic rst_n
);
  localparam int unsigned VC_W = $clog2(NUM_VCS);

  logic [FLIT_WIDTH-1:0] flit;
  logic                  flit_valid;
  logic [VC_W-1:0]       flit_vc;
  logic                  credit_valid;
  logic [VC_W-1:0]       credit_vc;

  modport tx (
    input  clk, rst_n, credit_valid, credit_vc,
    output flit, flit_valid, flit_vc
  );

  modport rx (
    input  clk, rst_n, flit, flit_valid, flit_vc,
    output credit_valid, credit_vc
  );

  modport mon (
    input clk, rst_n, flit, flit_valid, flit_vc,
          credit_valid, credit_vc
  );

  /* verilator lint_off UNUSEDSIGNAL */
  clocking cb @(posedge clk);
    default input #1step output #0;
    input  rst_n, credit_valid, credit_vc;
    output flit, flit_valid, flit_vc;
  endclocking

  clocking rx_cb @(posedge clk);
    default input #1step output #0;
    input  rst_n, flit, flit_valid, flit_vc;
    output credit_valid, credit_vc;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input rst_n, flit, flit_valid, flit_vc,
          credit_valid, credit_vc;
  endclocking
  /* verilator lint_on UNUSEDSIGNAL */
endinterface
