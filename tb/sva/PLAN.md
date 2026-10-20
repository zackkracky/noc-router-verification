# SystemVerilog Assertion (SVA) Master Verification Plan (v1)

**Owner**: Aashish (V2 — DV Formal & Paper Editor)  
**Date**: 19 Oct 2026  
**Applicability**: 5-port parameterized Virtual-Channel NoC Router (`noc-router-verification`)  
**Status**: **52 planned, 40 passing is the Phase 2 exit floor. Current: 6/52 passing.**  
**Simulation Bound**: Starvation bound $N = 48$ cycles (`##[0:N]`). Formal unbounded form uses `s_eventually`.

---

## 1. Conventions & Requirements

### 1.1 Rule 1 (Independence) & Property Register by Owner

The RTL author never writes assertions for their own block. Every property is assigned to an independent verification owner:

#### A. Aashish (V2) — FIFO Protocol, System Invariants & Liveness (`V01`–`V15`)
* **`V01` (`no_write_when_full`)**: Ensures `full |-> !wr_valid`. Upstream transmitters must obey backpressure; any write presented when full indicates buffer overflow corruption.
* **`V02` (`no_read_when_empty`)**: Ensures `empty |-> !rd_ready`. Downstream logic must not attempt to dequeue an empty buffer, preventing underflow and invalid flit consumption.
* **`V03` (`count_in_range`)**: Verifies that the internal buffer count never exceeds physical capacity: `count <= DEPTH`. Protects pointer wrapping and arithmetic invariants.
* **`V04` (`count_inc`)**: Proves that a write without a concurrent read (`wr_valid && !full && !rd_ready`) increases `count` by exactly 1 on the subsequent clock edge.
* **`V05` (`count_dec`)**: Proves that a read without a concurrent write (`rd_ready && rd_valid && (!wr_valid || full)`) decreases `count` by exactly 1 on the subsequent clock edge.
* **`V06` (`credit_iff_dequeue`)**: Checks `credit_out == (rd_ready && rd_valid)`. Credit return must pulse combinational in the exact cycle of dequeue so the upstream router receives immediate credit return.
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
* **`S02` (`no_send_without_credit`)**: Protocol rule: the transmitter must never assert `flit_valid` on a virtual channel if the local credit tracking counter for that VC is zero.
* **`S03` (`flit_vc_in_range`)**: Verifies that whenever `flit_valid` is high, the sideband `flit_vc` field specifies a valid index in the range `[0, NUM_VCS-1]`.
* **`S04` (`credit_vc_in_range`)**: Verifies that whenever `credit_valid` is high, the returning credit channel specifier `credit_vc` is in the range `[0, NUM_VCS-1]`.
* **`S05` (`no_credit_for_empty`)**: Proves that a receiver never generates a credit pulse on a VC whose internal occupancy is already zero.
* **`S06` (`credit_bound`)**: Guarantees that the transmitter's credit counter for any downstream VC never exceeds the maximum physical buffer depth `BUFFER_DEPTH`.
* **`S07` (`packet_head_opens_vc`)**: Packet grammar check: ensures that `BODY` or `TAIL` flits are only transmitted across a link on a virtual channel that was legitimately opened by a `HEAD` flit.
* **`S08` (`packet_tail_closes_vc`)**: Packet grammar check: ensures that once a `TAIL` flit departs, the virtual channel is closed; subsequent flits must begin with a new `HEAD`.

---

#### C. Revanth (R1) — Cross-Checks on Arnav's Back Half (`R01`–`R14`)
* **`R01` (`arb_grant_onehot0`)**: Checks `$onehot0(grant)`. The round-robin arbiter must grant at most one requester in any clock cycle.
* **`R02` (`arb_grant_implies_req`)**: Asserts `(grant & ~req) == '0`. Grants can only be issued to inputs currently asserting an active request line.
* **`R03` (`arb_pointer_advance`)**: Proves that the arbiter's internal round-robin priority pointer updates if and only if an enabled grant (`en && |grant`) occurs.
* **`R04` (`arb_fair_bound`)**: Liveness bound proving that any persistent request line receives a grant within at most $N \le 5$ enabled arbitration cycles, proving absence of starvation.
* **`R05` (`grant_implies_req`)**: Checks `sa_grant[p][v] |-> sa_req[p][v]`. Switch allocator cannot grant traversal to an input VC that is not actively requesting.
* **`R06` (`out_grant_onehot0`)**: Asserts that for every egress port, at most one ingress port is granted access per cycle: `$onehot0(sa_out_grant[out_port])`.
* **`R07` (`one_grant_per_input`)**: Asserts that an input port receives at most one switch allocation grant across all output ports in the same cycle: `$onehot0(sa_in_grant[in_port])`.
* **`R08` (`stage1_stage2_match`)**: Verifies consistency in separable allocation: Stage 2 arbiter only arbitrates among valid Stage 1 candidates targeting that specific output.
* **`R09` (`sa_fairness_bound`)**: Liveness bound proving that an input holding flits and credit is granted switch traversal within $N \le 48$ cycles under fair traffic.
* **`R10` (`xbar_mux_onehot`)**: Safety check on crossbar multiplexer control lines: select bus for every physical output is strictly one-hot or zero, preventing bus contention.
* **`R11` (`credit_in_range`)**: Verifies that the output unit credit tracking counter satisfies $0 \le \text{credit\_count} \le \text{BUFFER\_DEPTH}$.
* **`R12` (`no_valid_at_zero`)**: Asserts that `output_unit` never drives `flit_valid` high on a VC whose downstream credit counter is zero.
* **`R13` (`inc_only_on_credit`)**: Proves that the credit counter increments if and only if a valid credit return pulse `credit_valid` arrives for that specific VC.
* **`R14` (`simultaneous_send_ret`)**: Confirms that when an egress flit is dispatched and a credit returns in the exact same cycle, the credit counter correctly nets zero change.

---

#### D. Arnav (R2) — Cross-Checks on Revanth's Front Half (`A01`–`A15`)
* **`A01` (`route_xy_dimension_order`)**: Proves strict dimension-order XY routing: flits traverse the X-dimension until $\Delta X = 0$, then Y-dimension. Forbids illegal Y-to-X turns (deadlock-free invariant).
* **`A02` (`route_no_self_loop`)**: Asserts that `route_unit` never calculates an output port that matches the ingress port (e.g., East packet never routes back out East).
* **`A03` (`route_onehot_valid`)**: Proves that the combinational output vector `out_port_onehot` is strictly one-hot for any destination coordinate set.
* **`A04` (`route_local_on_match`)**: Verifies that the `LOCAL` port is selected if and only if both destination coordinates match the local router coordinates: `dst_x == X_COORD && dst_y == Y_COORD`.
* **`A05` (`route_valid_stable`)**: Asserts that the computed route port remains stable and glitch-free across cycles while the `HEAD` flit is buffered waiting for allocation.
* **`A06` (`idle_exit_on_head`)**: Verifies that a virtual channel state machine in `input_port` only transitions out of `IDLE` when a valid `HEAD` or `HEAD_TAIL` flit arrives.
* **`A07` (`head_follows_route`)**: Proves that when a `HEAD` flit is granted switch allocation, the output port target matches the exact port calculated by `route_unit`.
* **`A08` (`no_body_in_idle`)**: Asserts that no `BODY` or `TAIL` flit can be dequeued or presented for allocation while the VC state is `IDLE`.
* **`A09` (`fsm_legal_transitions`)**: Asserts that the per-VC control state machine strictly follows legitimate state progressions (`IDLE` $\to$ `ROUTING` $\to$ `WAIT_VC` $\to$ `ACTIVE`).
* **`A10` (`credit_out_onehot`)**: Verifies that the scalar credit return interface returns at most one credit per input port per cycle (`$onehot0(credit_valid)`).
* **`A11` (`ovc_single_owner`)**: Invariant: an output virtual channel is assigned to at most one input virtual channel at any point in time.
* **`A12` (`release_on_tail`)**: Checks that the `vc_allocator` frees an output VC if and only if the `release` signal pulses upon `TAIL` or `HEAD_TAIL` dequeue.
* **`A13` (`one_grant_per_input_vc`)**: Proves that a single input virtual channel never receives multiple output VC grants in the same clock cycle.
* **`A14` (`vc_locked_until_tail`)**: Asserts that once an output VC is assigned to an input packet, its entry in the busy table remains locked until packet completion.
* **`A15` (`release_bound`)**: Liveness bound proving that an output VC transitions back to `free` within $N \le 1$ cycle following `release` assertion.

---

### 1.2 Structure & Syntax Conventions

Every assertion property follows this strict syntactic pattern:

```systemverilog
property p_<name>;
  @(posedge clk) disable iff (!rst_n) <antecedent> |-> <consequent>;
endproperty

a_<id>_<name>: assert property (p_<name>)
  else $error("<id> <failure message>");