// crossbar.sv -- NUM_PORTS x NUM_PORTS combinational payload crossbar; per-output one-hot grant from switch_allocator selects the driving input. No state.
`default_nettype none

    module crossbar #(
    parameter int unsigned NUM_PORTS = 5,
    parameter int unsigned DATA_W    = 34                        // router_top packs {out_vc, flit}
    ) (
    input  logic [NUM_PORTS-1:0][DATA_W-1:0]    data_i,          // payload from each input port
    input  logic [NUM_PORTS-1:0][NUM_PORTS-1:0] grant_i,         // grant_i[o][i]=1: input i drives output o
    output logic [NUM_PORTS-1:0][DATA_W-1:0]    data_o,          // payload to each output_unit
    output logic [NUM_PORTS-1:0]                valid_o          // output o carries a flit this cycle
    );

    // AND-OR mux; grant_i[o] must be at most one-hot (P_XB_ONEHOT). A violation ORs flits together.
    always_comb begin
        data_o  = '0;
        valid_o = '0;
        for (int unsigned o = 0; o < NUM_PORTS; o++) begin
        for (int unsigned i = 0; i < NUM_PORTS; i++) begin
            if (grant_i[o][i]) data_o[o] = data_o[o] | data_i[i];  // select
        end
        valid_o[o] = |grant_i[o];                                // any grant => valid
        end
    end

    endmodule

`default_nettype wire