// flit_pkt: parameterized TB transaction; shared hdr_t is always at the MSB.
class flit_pkt #(parameter int unsigned FLIT_WIDTH = 64);
  noc_pkg::hdr_t hdr;
  logic [FLIT_WIDTH-noc_pkg::HDR_W-1:0] payload;

  function new();
    hdr = '0;
    payload = '0;
  endfunction

  function logic [FLIT_WIDTH-1:0] pack();
    return {hdr, payload};
  endfunction

  function void unpack(input logic [FLIT_WIDTH-1:0] bits_in);
    hdr = noc_pkg::hdr_t'(bits_in[FLIT_WIDTH-1 -: noc_pkg::HDR_W]);
    payload = bits_in[FLIT_WIDTH-noc_pkg::HDR_W-1:0];
  endfunction
endclass
