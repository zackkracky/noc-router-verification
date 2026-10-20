# SystemVerilog Assertion (SVA) Master Verification Plan (v2)

**Owner**: Aashish (V2 — DV Formal & Paper Editor)  
**Date**: 21 Oct 2026  
**Applicability**: 5-port parameterized Virtual-Channel NoC Router (`noc-router-verification`)  
**Status**: **52 planned, 40 passing is the Phase 2 exit floor. Current: 6/52 written, bound and passing in CI (P01–P06 on `tb_fifo`, seeds 1–3).**  
**Simulation Bound**: Starvation bound $N = 48$ cycles (`##[0:N]`). Formal unbounded form uses `s_eventually`.

---

## 1. Conventions & Requirements

### 1.1 Rule 1 (Independence) & Property Register by Owner

The RTL author never writes assertions for their own block. Every property is assigned to an independent verification owner:

IDs: `P01`–`P06` are the Gate-1 FIFO IDs fixed by `docs/INTERFACE.md` s6 and used in `tb/sva/fifo_sva.sv` and `docs/BUG_LOG.md`; they keep those IDs. Every other property uses an owner prefix (`V`, `S`, `R`, `A`). Signal names follow `docs/INTERFACE.md` (s4 link, s7 front/back boundary, s7.2 `rr_arbiter`) and `rtl/pkg/noc_pkg.sv` enums.

#### A. Aashish (V2) — FIFO Protocol, System Invariants & Liveness (`P01`–`P06`, `V07`–`V15`)
* **`P01` (`a_p01_no_write_when_full`)**: Ensures `full |-> !wr_valid`. Environment constraint on the producer: `assert` in simulation, `assume` under `` `ifdef FORMAL ``.
* **`P02` (`a_p02_no_read_when_empty`)**: Ensures `empty |-> !rd_ready`. Environment constraint on the consumer (`rd_ready` is a pop strobe, INTERFACE.md s6): `assert` in simulation, `assume` under `` `ifdef FORMAL ``.
* **`P03` (`a_p03_count_in_range`)**: `count <= DEPTH`; `count` is `[$clog2(DEPTH+1)-1:0]` as in `input_fifo`.
* **`P04` (`a_p04_count_inc`)**: Proves that a write without a concurrent read (`wr_valid && !full && !rd_ready`) increases `count` by exactly 1 on the subsequent clock edge.
* **`P05` (`a_p05_count_dec`)**: Proves that a read without a concurrent write (`rd_ready && rd_valid && (!wr_valid || full)`) decreases `count` by exactly 1 on the subsequent clock edge.
* **`P06` (`a_p06_credit_iff_dequeue`)**: Checks `credit_out == (rd_ready && rd_valid)`: combinational in the dequeue cycle (INTERFACE.md s6); `input_port` registers it once. Caught PM-001 (registered `credit_out`) before merge.
* **`V07` (`reset_quiescence`)**: Evaluates that on the cycle following reset release, all control valids, requests, and grants are deasserted, and credit counters match `BUFFER_DEPTH`.
* **`V08` (`no_flit_lost`)**: End-to-end scoreboard invariant verifying that every packet/flit admitted into the router is eventually egressed with identical payload fields (0 packet dropping).
* **`V09` (`no_reorder_per_vc`)**: End-to-end scoreboard invariant ensuring flits belonging to the same packet and stream within any given virtual channel maintain strict FIFO order.
* **`V10` (`sa_starve_bound`)**: Bounded liveness asserting that an active switch request with available downstream credits receives a grant within $N \le 48$ cycles under fair arbitration.
* **`V11` (`va_bound_when_free`)**: Bounded liveness asserting that a packet waiting in `WAIT_VC` targeting an idle output VC receives that VC allocation within $N \le 48$ cycles.
* **`V12` (`tail_eventual`)**: Asserts that an `ACTIVE` virtual channel eventually observes its terminating `TAIL` or `HEAD_TAIL` flit dequeued, preventing zombie state-machine holds.
* **`V13` (`credit_return_bound`)**: Verifies that following flit dequeue at an input buffer, the associated credit return pulse appears on the upstream link within $N \le 1$ cycle.
* **`V14` (`no_deadlock_bound`)**: System-level liveness checking that whenever one or more buffers contain flits, forward progress occurs (at least one switch allocation grant occurs within $N \le 48$).
* **`V15` (`pkt_completion_bound`)**: Proves that from the cycle a `HEAD` flit is granted switch traversal, the entire packet through `TAIL` completes egress within bounded latency $N_{PKT}$.

---

#### B. Sachin (V1) — Link Handshakes, Framing & Credit Ranges (`S01`–`S08`)
* **`S01` (`valid_known`)**: Asserts that `flit_valid` and `credit_valid` signals on the physical link never take unknown (`X` or `Z`) values once reset is deasserted.
* **`S02` (`no_send_without_credit`)**: Protocol rule: `flit_valid |-> ocredit_avail[o][flit_vc]`; the sender holds `flit_valid` low without credit (INTERFACE.md s4).
* **`S03` (`flit_vc_in_range`)**: Verifies that whenever `flit_valid` is high, the sideband `flit_vc` field specifies a valid index in the range `[0, NUM_VCS-1]`.
* **`S04` (`credit_vc_in_range`)**: Verifies that whenever `credit_valid` is high, the returning credit channel specifier `credit_vc` is in the range `[0, NUM_VCS-1]`.
* **`S05` (`no_credit_for_empty`)**: Proves that a receiver never generates a credit pulse on a VC whose internal occupancy is already zero.
* **`S06` (`credit_bound`)**: Guarantees that the transmitter's credit counter for any downstream VC never exceeds the maximum physical buffer depth `BUFFER_DEPTH`.
* **`S07` (`packet_head_opens_vc`)**: Packet grammar check: ensures that `BODY` or `TAIL` flits are only transmitted across a link on a virtual channel that was legitimately opened by a `HEAD` flit.
* **`S08` (`packet_tail_closes_vc`)**: Packet grammar check: ensures that once a `TAIL` flit departs, the virtual channel is closed; subsequent flits must begin with a new `HEAD`.

---

#### C. Revanth (R1) — Cross-Checks on Arnav's Back Half (`R01`–`R14`)
* **`R01` (`arb_grant_onehot0`)**: `rr_arbiter`: `$onehot0(grant)`; also `grant_vld == |req` and `grant_vld |-> grant[grant_idx]` (INTERFACE.md s7.2).
* **`R02` (`arb_grant_implies_req`)**: `rr_arbiter`: `(grant & ~req) == '0`.
* **`R03` (`arb_pointer_advance`)**: `rr_arbiter`: `en && grant_vld |=> ptr_q == (($past(grant_idx) == N-1) ? 0 : $past(grant_idx) + 1)` and `!(en && grant_vld) |=> $stable(ptr_q)`; plus `ptr_q < N`. The exact next value is the only check that kills the no-wrap mutant, which is equivalent at the ports (STATE.md, `tb_rr_arbiter`).
* **`R04` (`arb_fair_bound`)**: `rr_arbiter`, per instance width `N`: a request held high with `en` high is granted within `N-1` other grants. Simulation `req[i] && en |-> ##[0:N-1] grant[i]`; formal `s_eventually grant[i]`; both assume `req[i]` stays high until granted. Measured max wait `N-1` in `tb_rr_arbiter` at N = 1, 2, 3, 4, 5, 8.
* **`R05` (`grant_implies_req`)**: Checks `sa_grant[p][v] |-> sa_req[p][v]`. Switch allocator cannot grant traversal to an input VC that is not actively requesting.
* **`R06` (`out_grant_onehot0`)**: For every output `o`, `$onehot0(xbar_sel[o])`.
* **`R07` (`one_grant_per_input`)**: For every input `p`, `$onehot0(sa_grant[p])` across its VCs.
* **`R08` (`stage1_stage2_match`)**: Every `sa_grant[p][v]` has exactly one `xbar_sel[o][p]` with `o == sa_out_port[p][v]`, and every `xbar_sel[o][p]` has exactly one `sa_grant[p][v]` (INTERFACE.md s7).
* **`R09` (`sa_fairness_bound`)**: Liveness bound proving that an input holding flits and credit is granted switch traversal within $N \le 48$ cycles under fair traffic.
* **`R10` (`xbar_mux_onehot`)**: `crossbar` data path: `xbar_sel[o][p] |-> issue_flit[o] == xb_flit[p] && issue_vc[o] == xb_vc[p]`, and `issue[o] == |xbar_sel[o]` (one-hot select is R06).
* **`R11` (`credit_in_range`)**: `ocredit_count[o][v] <= BUFFER_DEPTH`.
* **`R12` (`no_valid_at_zero`)**: `issue[o] |-> ocredit_avail[o][issue_vc[o]]`; the debit happens at the output-register load.
* **`R13` (`inc_only_on_credit`)**: `ocredit_count[o][v]` increments iff `credit_valid && credit_vc == v` on output `o` without a same-cycle debit.
* **`R14` (`simultaneous_send_ret`)**: Confirms that when an egress flit is dispatched and a credit returns in the exact same cycle, the credit counter correctly nets zero change.

---

#### D. Arnav (R2) — Cross-Checks on Revanth's Front Half (`A01`–`A15`)
* **`A01` (`route_xy_dimension_order`)**: Proves strict dimension-order XY routing: flits traverse the X-dimension until $\Delta X = 0$, then Y-dimension. Forbids illegal Y-to-X turns (deadlock-free invariant).
* **`A02` (`route_no_self_loop`)**: `route_unit`: `!out_port_onehot[in_port]` unless `in_port == L` (no U-turn on a mesh port).
* **`A03` (`route_onehot_valid`)**: Proves that the combinational output vector `out_port_onehot` is strictly one-hot for any destination coordinate set.
* **`A04` (`route_local_on_match`)**: `out_port_onehot[L]` iff `dst_x == X_COORD && dst_y == Y_COORD`.
* **`A05` (`route_valid_stable`)**: Asserts that the computed route port remains stable and glitch-free across cycles while the `HEAD` flit is buffered waiting for allocation.
* **`A06` (`idle_exit_on_head`)**: Verifies that a virtual channel state machine in `input_port` only transitions out of `IDLE` when a valid `HEAD` or `HEAD_TAIL` flit arrives.
* **`A07` (`head_follows_route`)**: Proves that when a `HEAD` flit is granted switch allocation, the output port target matches the exact port calculated by `route_unit`.
* **`A08` (`no_body_in_idle`)**: Asserts that no `BODY` or `TAIL` flit can be dequeued or presented for allocation while the VC state is `IDLE`.
* **`A09` (`fsm_legal_transitions`)**: Per-VC `vc_state_e` follows `IDLE` $\to$ `ROUTING` $\to$ `WAIT_VC` $\to$ `ACTIVE` $\to$ `IDLE` (on TAIL/HEAD_TAIL dequeue), INTERFACE.md s7.1.
* **`A10` (`credit_out_onehot`)**: `input_port` returns exactly one registered credit per final grant, on the granted VC: `sa_grant[p][v] |=> credit_valid && credit_vc == v`, and no `credit_valid` without a final grant in the previous cycle (`credit_valid` is scalar, T1).
* **`A11` (`ovc_single_owner`)**: Invariant: an output virtual channel is assigned to at most one input virtual channel at any point in time.
* **`A12` (`release_on_tail`)**: `vc_allocator` frees an output VC iff `va_release[p][v]` pulses on the final grant that dequeues `TAIL` or `HEAD_TAIL`.
* **`A13` (`one_grant_per_input_vc`)**: An input VC receives at most one output-VC grant: `va_grant[p][v]` moves it to `ACTIVE`, and no further `va_grant[p][v]` until release.
* **`A14` (`vc_locked_until_tail`)**: Asserts that once an output VC is assigned to an input packet, its entry in the busy table remains locked until packet completion.
* **`A15` (`release_bound`)**: `va_release` at edge Ek makes the output VC eligible (`ovc_free`) in cycle C(k+1), not for reassignment at Ek (INTERFACE.md s7).

---

### 1.2 Structure & Syntax Conventions

Every assertion property follows this strict syntactic pattern:

```systemverilog
property p_<name>;
  @(posedge clk) disable iff (!rst_n) <antecedent> |-> <consequent>;
endproperty

a_<id>_<name>: assert property (p_<name>)  // intent; clk/rst_n; group
  else $error("<id> <failure message>");
```

- Label: `a_<id>_<name>`, id lowercase (`a_p06_credit_iff_dequeue`). Labels are referenced by BUG_LOG and the detection matrix; do not rename after merge.
- One checker module per block, `tb/sva/<block>_sva.sv`, attached only in `tb/sva/bind_all.sv`, instance `u_<block>_sva`. Ports in the RTL's order, only the signals the properties read.
- Liveness: bounded `##[0:N]` in simulation, `s_eventually` under `` `ifdef FORMAL ``. Environment constraints become `assume` under `` `ifdef FORMAL ``.
- Every property registers at least one mutant it kills in the detection matrix before it counts toward the 40.
