# SystemVerilog Assertion (SVA) Master Verification Plan (v1)

**Owner**: Sag (V2 — DV Formal & Paper Editor)  
**Date**: 25 Sep 2026 (Phase 0 Freeze Target: 1 Oct 2026)  
**Applicability**: 5-port parameterized Virtual-Channel NoC Router (`noc-router-verification`)  
**Status**: 40 properties planned; T4 probe confirmed Verilator supports `##[0:N]` ranged delays.

---

## 1. Conventions & Requirements

1. **Rule 1 (Independence)**: The RTL author never writes assertions for their own block.
   - **Sag**: Owns FIFO, link protocol, reset, scoreboard, and all liveness properties.
   - **Revu**: Owns cross-assertions on Arnav's blocks (`switch_allocator`, `output_unit`).
   - **Arnav**: Owns cross-assertions on Revu's blocks (`input_port`, `vc_allocator`).
2. **Clock and Reset**: Every property must have an explicit sampling clock and asynchronous/synchronous reset disable:
   ```systemverilog
   property p_<name>;
     @(posedge clk) disable iff (!rst_n) <antecedent> |-> <consequent>;
   endproperty
   a_<id>_<name>: assert property (p_<name>)
     else $error("<id> <failure message>");