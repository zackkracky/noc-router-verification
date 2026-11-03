//crossbar: NUM_PORTS x NUM_PORTS flit mux, grant_i[out][in] one-hot selects input onto output, combinational
module crossbar #(
  parameter int NUM_PORTS = noc_pkg::NUM_PORTS,
  parameter int DATA_W    = noc_pkg::DEF_FLIT_WIDTH//64 default, 32/128 also fine
) (
  input  wire logic [NUM_PORTS-1:0][DATA_W-1:0]    data_i,  //flit from each input port
  input  wire logic [NUM_PORTS-1:0][NUM_PORTS-1:0] grant_i, //grant_i[out][in], one-hot or zero
  output logic      [NUM_PORTS-1:0][DATA_W-1:0]    data_o,
  output logic      [NUM_PORTS-1:0]                valid_o
);

  //and-or mux, no priority encoder, no latch
  always_comb begin
    for (int o = 0; o < NUM_PORTS; o++) begin
      data_o[o]  = '0;
      valid_o[o] = |grant_i[o];//zero grant row gives valid 0, data 0
      for (int i = 0; i < NUM_PORTS; i++) begin
        data_o[o] |= data_i[i] & {DATA_W{grant_i[o][i]}};//masked or, one-hot assumed
      end
    end
  end

  //one-hot(grant_i[o]) and no-input-double-grant live in sva/crossbar_sva.sv via bind

endmodule
