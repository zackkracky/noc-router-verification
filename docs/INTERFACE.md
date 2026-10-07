# NoC router interface specification — spec-v1 candidate

Owner: Sachin (V1). Revision: 7 October 2026. Status: **DRAFT — proposed decisions, not frozen or approved.**

This contract covers the five-port wormhole router, its links, internal front/back boundary, and testbench connections. It is a specification, not executable RTL. Use this filename, `docs/INTERFACE.md`; an additional `interface.spec` file would duplicate the source of truth.

## 0. Authority and decisions requiring sign-off

Reviewed sources: Project Bible rev 1 (18 September 2026), the supplied draft, repository `main` at `b0006f92756027e19c17952c72ef7a18b287f55a`, and `arnav/phase1-intial-interface` at `aff58166a3ee66fdd7c1177c9f3fbb0f29b62f90`. The branch draft is textually the same as the attachment apart from line endings. No implemented `noc_pkg.sv`, FIFO, router, or testbench exists at these snapshots. Package/code files supplied with this revision are proposals.

The bible says section 5 governs signals until `spec-v1` is tagged. This revision resolves its open decisions explicitly rather than treating the unmerged draft as an approved replacement. Once approved, this document governs behavior; `noc_pkg` implements the agreed constants and types. A disagreement is a defect to resolve in the same PR, not permission for either file to silently override the other.

| Decision | This candidate chooses | Reviewers |
|---|---|---|
| T1 credit encoding | Scalar `credit_valid` plus `credit_vc`; at most one dequeue per input port per cycle | Sachin, Revanth |
| T2 VC location | Sideband `flit_vc` only; no VC bits inside `flit` | All four |
| Flit metadata | Restore source coordinates, packet ID and flit index from bible section 5.1; fixed 30-bit metadata | All four |
| T9 VC ownership | Single busy/owner table in `vc_allocator`; `output_unit` owns credits only | Revanth, Arnav |
| Credit timing | Debit at final SA grant/output-register load; register FIFO credit return once in `input_port`; no same-edge zero-credit bypass | Revanth, Arnav, Sachin |
| FIFO boundaries | Strict no-write-at-full/no-read-at-empty contract, including simultaneous requests; no empty bypass | Revanth, Aashish |
| T11 future routing | Reserve full per-output/per-VC credit counts as route-unit input; XY ignores it, future WF may use it | Revanth, Arnav, Sachin |
| Scoreboard identity | Globally unique outstanding `pkt_id` within this single-router testbench (maximum 256); release ID at observed completion | Sachin, Aashish |

Sign-off (name / date / reviewed commit):
- Revanth — front RTL:
- Arnav — back RTL and shared package:
- Sachin — testbench/interface:
- Aashish — assertions/scoreboard:

Merge this PR only after all four reviewers sign the decision table above. Keep the merge untagged. Tag `spec-v1` only after `noc_pkg.sv`, the front RTL, and the back RTL agree with this contract and the interface acceptance checks pass. Later incompatible changes require all-four review and a new version. This PR does not create a Git tag or assert approval.

## 1. Parameters and shared types

| Parameter | Default | Supported values |
|---|---:|---|
| `FLIT_WIDTH` | 64 | Integer 32 through 128 |
| `NUM_VCS` | 2 | 2, 3, 4 |
| `BUFFER_DEPTH` | 4 | 2, 4, 8 flits per VC |
| `X_COORD`, `Y_COORD` | 0, 0 | Integer 0 through 7 |
| `ROUTE_ALGO` | `"XY"` | XY in Phase 1/2; WF reserved for Phase 3 |

`NUM_PORTS=5`, `PORT_W=$clog2(NUM_PORTS)=3`, `COORD_W=3`, `FTYPE_W=2`, `PKT_ID_W=8`, `FLIT_IDX_W=8`, `HDR_W=30`.

Derive `VC_W=$clog2(NUM_VCS)` and `CNT_W=$clog2(BUFFER_DEPTH+1)` **in each parameterized scope**. `VC_W` is 1 for two VCs, 2 for three/four; encoding 3 is illegal when `NUM_VCS=3`. `CNT_W` is 2, 3, 4 for depths 2, 4, 8. Payload width is `FLIT_WIDTH-HDR_W` (2, 34, 98 at widths 32, 64, 128).

`noc_pkg` supplies enums `port_e` (`N=0,E=1,S=2,W=3,L=4`), `ftype_e` (`HEAD=0,BODY=1,TAIL=2,HEAD_TAIL=3`), and `vc_state_e` (`IDLE,ROUTING,WAIT_VC,ACTIVE`), defaults and the fixed-width `hdr_t`. A package-level width-specific `flit_t` must not silently force overridden modules back to 64 bits: declare `logic [FLIT_WIDTH-1:0]` locally. The included package deliberately defines only the fixed-width header type.

## 2. Flit layout and packet grammar

Fields are MSB first. For `F=FLIT_WIDTH`:

| Field | Width | General bit range | Default F=64 | Meaning |
|---|---:|---|---|---|
| `ftype` | 2 | `[F-1:F-2]` | `[63:62]` | Flit type, all flits |
| `dst_x` | 3 | `[F-3:F-5]` | `[61:59]` | Destination X, HEAD/HEAD_TAIL |
| `dst_y` | 3 | `[F-6:F-8]` | `[58:56]` | Destination Y, HEAD/HEAD_TAIL |
| `src_x` | 3 | `[F-9:F-11]` | `[55:53]` | Source X, HEAD/HEAD_TAIL; TB metadata |
| `src_y` | 3 | `[F-12:F-14]` | `[52:50]` | Source Y, HEAD/HEAD_TAIL; TB metadata |
| `pkt_id` | 8 | `[F-15:F-22]` | `[49:42]` | Testbench packet identity, all flits |
| `flit_idx` | 8 | `[F-23:F-30]` | `[41:34]` | Zero-based index within packet, all flits |
| `payload` | F−30 | `[F-31:0]` | `[33:0]` | Data |

```systemverilog
import noc_pkg::*;
hdr_t hdr;
logic [FLIT_WIDTH-1:0] flit;
// Extraction (fixed header width, parameterized whole flit):
// hdr = hdr_t'(flit[FLIT_WIDTH-1 -: HDR_W]);
// Construction: flit = {hdr, payload};
```

`$bits(hdr_t)==30`. There is **no in-band VC field**. The sender sets sideband `flit_vc` to the downstream VC reserved for this packet. The router may change that sideband between input and output; all `FLIT_WIDTH` flit bits are preserved.

For BODY/TAIL, the twelve coordinate-position bits are opaque extension data. RTL must not route on them or clear them. `hdr_t` is a positional view, not a claim those bits remain meaningful coordinates. Tests may fill them with arbitrary patterns to catch accidental interpretation. `pkt_id` and `flit_idx` remain metadata in every flit.

Per link and VC, a packet is `HEAD, zero or more BODY, TAIL`, or one `HEAD_TAIL`. Index starts at 0 and increments; lengths supported by the 8-bit index are 1..256 (initial random tests use 1..8). The next packet may start only after the previous TAIL on that VC. Different VCs may interleave on the physical link. For each open packet on one link, every BODY and TAIL must use the same `flit_vc` as that packet's HEAD on that link. The router may assign a different VC on its output link, but must maintain packet VC continuity separately on each link. A monitor or property must report a mismatch. HEAD_TAIL follows normal RC/VA/SA and releases ownership when dequeued, not on arrival.

A generator creates well-formed streams. Malformed traffic is outside functional correctness guarantees and must be reported by TB/SVA; do not silently claim that protocol checkers already exist. No packet authentication, CRC, retry, or error recovery is specified.

## 3. Coordinates and route-unit contract

East increases X; North increases Y. Direct comparisons avoid unsigned-subtraction underflow.

| First matching condition | Output |
|---|---|
| `dst_x > X_COORD` | E |
| `dst_x < X_COORD` | W |
| X equal, `dst_y > Y_COORD` | N |
| X equal, `dst_y < Y_COORD` | S |
| Both equal | L |

`route_unit` is combinational. Parameters: `ROUTE_ALGO`, `X_COORD`, `Y_COORD`, `NUM_VCS`, `BUFFER_DEPTH`. Ports:

| Port | Direction | Shape | Owner/meaning |
|---|---|---|---|
| `dst_x`, `dst_y` | in | `[COORD_W-1:0]` each | HEAD destination from front half |
| `in_port` | in | `[PORT_W-1:0]` | Physical ingress; XY does not use it |
| `route_credit` | in | `[NUM_PORTS-1:0][NUM_VCS-1:0][CNT_W-1:0]` | Registered current downstream credit counts from back half |
| `out_port_onehot` | out | `[NUM_PORTS-1:0]` | Exactly one bit for valid XY coordinates |

**Lint decision pending Arnav:** XY routing does not consume `route_credit`, but this port reserves credit counts for WF routing. Arnav will choose either a generate-gated implementation or a narrowly scoped `UNUSED` waiver with an explicit sink. Record the chosen implementation here before merge. Do not disable `UNUSED` for the whole design.

The `route_credit` input is a **proposed T11 resolution**; it is not in the old draft. It carries counts, not only availability bits, so future WF can genuinely prefer an output with more capacity. XY ignores it. A future WF implementation must document its selection metric/tie-break and mesh proof; reserving the input does not implement WF or prove deadlock freedom. Unsupported algorithms must fail configuration validation rather than silently run XY. Sample/freeze a packet's chosen route before VA; never reroute its BODY/TAIL as credits change.

If one route unit is shared by all VCs in an input port, `input_port` arbitrates routing work and commits at most one route result per cycle; unselected VCs remain waiting. The nominal timing below assumes that resource is available.

Do not assert “L never routes to L”: local destination returns L even on local input. The planned 20-pair test deliberately excludes same-port traffic; that is a traffic-profile restriction, not behavior implemented by the XY function. Likewise, no-U-turn checks require mesh-legal injection/history assumptions. N/S→E/W can be driven in single-router tests although they are unreachable in legal XY mesh transit. XY mesh deadlock freedom comes from dimension ordering and absence of cyclic channel dependencies, not merely from forbidding U-turns.

## 4. External link and router-top naming

One `flit_if` instance represents **one unidirectional data channel plus its reverse credits**. Two opposite data directions need two instances. A five-port router's isolated testbench normally has five input-link instances and five output-link instances, including Local.

| Signal | Width | Driver | Meaning |
|---|---:|---|---|
| `flit` | FLIT_WIDTH | Sender | Current flit bits |
| `flit_valid` | 1 | Sender | One flit offered for acceptance at the next rising edge |
| `flit_vc` | VC_W | Sender | Receiver VC receiving that flit |
| `credit_valid` | 1 | Receiver | One previously freed FIFO slot returned |
| `credit_vc` | VC_W | Receiver | Which receiver VC freed that slot |

There is no `ready`. Every rising edge with `rst_n && flit_valid` accepts one flit; a sender with no credit must keep valid low. Consecutive valid cycles can carry different flits. Consecutive credit-valid cycles can each return a credit; no low cycle is required between them. When a valid is zero, its associated data/VC are ignored (drivers should drive zero for readable traces).

Both endpoint owners sample `rst_n` as synchronous active-low reset. Reset is an input to the interface, driven only by the top-level TB/reset source; the interface does not generate or drive reset.

For flat `router_top` ports, use these proposed names, all with leading packed dimension `[NUM_PORTS-1:0]`:

| Router input side | Direction at router | Router output side | Direction at router |
|---|---|---|---|
| `in_flit[p]` | in | `out_flit[p]` | out |
| `in_flit_valid[p]` | in | `out_flit_valid[p]` | out |
| `in_flit_vc[p]` | in | `out_flit_vc[p]` | out |
| `in_credit_valid[p]` | out, to upstream | `out_credit_valid[p]` | in, from downstream |
| `in_credit_vc[p]` | out, to upstream | `out_credit_vc[p]` | in, from downstream |

“In/out” identifies the **data direction**, so credits point the opposite way. `clk`, `rst_n` are scalar inputs. Flat ports let the design use the TB interface without requiring interface ports in synthesizable RTL.

## 5. Exact cycle and credit timing

### 5.1 Convention

`Ck` is the interval immediately **before** rising edge `Ek`. Signals shown in column Ck are sampled at Ek. Sequential updates at Ek become visible in C(k+1). Clocking-block `input #1step` observes values just before Ek; `output #0` drives after that edge, for the following sample. Reset overrides other events.

### 5.2 Forward path: reserve credit before registering the flit

`issue[o]` is the final switch grant to output o in Ck. At Ek, simultaneously:
1. The selected input VC FIFO dequeues.
2. Output o's register captures the chosen flit and allocated output VC.
3. That output VC's credit counter decrements (a slot is now reserved).

Registered `out_flit_valid` is visible in C(k+1), and the downstream FIFO accepts it at E(k+1). No extra link register is assumed. With no new issue, the output valid register clears at the next edge; it must not repeat the preceding flit.

**Do not debit again on downstream acceptance.** Otherwise one flit consumes two credits. Do not gate already-registered `out_flit_valid` with the new counter value: sending the last reserved flit legitimately leaves `out_flit_valid=1` while the counter is 0.

### 5.3 Credit return: one registered stage

Inside a FIFO, `deq = rst_n && rd_valid && rd_ready` and combinational `credit_out = deq`. The input port combines its one-hot-or-zero per-VC dequeues. At Ek it registers that event into link `credit_valid` and the **input** VC number into `credit_vc`. Link return is visible in C(k+1), sampled by upstream at E(k+1); the incremented upstream count is usable in C(k+2). Thus dequeue edge to sender increment is one clock period. Do not add another return register in the FIFO or link wiring.

Only real dequeue creates credit; arrival does not. A TB downstream model may delay consumption or queue returns longer to create backpressure. It must return exactly one credit per freed slot, including when a burst of dequeues occurs; delaying must not lose events.

### 5.4 Counter equations and invariants

For each `(o,v)`, in Ck:

```text
send_v = issue[o] && (issue_vc[o] == v)
ret_v  = out_credit_valid[o] && (out_credit_vc[o] == v)
credit_next[o][v] = credit[o][v] + ret_v - send_v
ocredit_avail[o][v] = (credit[o][v] > 0)
```

Evaluate arithmetic with enough width before assignment. Reset writes `BUFFER_DEPTH`. Send requires **pre-edge** credit > 0. Returning a credit at zero does not permit a same-edge issue; it enables a request in the next cycle. Send plus return on the same VC is net zero; on different VCs, update both counters independently. Reject out-of-range IDs and a next count outside 0..BUFFER_DEPTH in verification. A return at full is legal only if a simultaneous same-VC reservation keeps the next count within bounds; a real closed credit loop must also conserve slots.

Conservation at a consistent cycle boundary:

`credit + reserved_flits_in_flight + downstream_occupancy + freed_credits_not_yet_applied = BUFFER_DEPTH`

The registered output counts as an in-flight flit. A registered return or delayed TB return counts as an in-flight credit. An output-only checker cannot observe every term.

### 5.5 Four-flit stall example, depth 2, VC 0

The editable WaveDrom and image are `wavedrom/credit_stall.json` and `.png`. Every column uses the convention above. The downstream deliberately waits before consuming.

| Ck / Ek | Pre-edge credit | Issue into output register | Flit accepted downstream | Downstream dequeue | Returned credit sampled | Next credit |
|---:|---:|---|---|---|---|---:|
| 0 | 2 | HEAD | — | — | — | 1 |
| 1 | 1 | BODY0 | HEAD | — | — | 0 |
| 2 | 0 | — | BODY0 | — | — | 0 |
| 3 | 0 | — | — | — | — | 0 |
| 4 | 0 | — | — | HEAD | — | 0 |
| 5 | 0 | — | — | BODY0 | VC0 | 1 |
| 6 | 1 | BODY1 | — | — | VC0 | 1 |
| 7 | 1 | TAIL | BODY1 | — | — | 0 |
| 8 | 0 | — | TAIL | BODY1 | — | 0 |
| 9 | 0 | — | — | TAIL | VC0 | 1 |
| 10 | 1 | — | — | — | VC0 | 2 |
| 11 | 2 | — | — | — | — | 2 |

C6 demonstrates simultaneous return and reservation. C2/C8 demonstrate why “valid at credit zero” is not inherently illegal for the registered output. The trace is an executable reference example, not a waveform captured from the future router RTL.

## 6. FIFO contract

One synchronous FWFT FIFO per input VC: `DEPTH=BUFFER_DEPTH`, `WIDTH=FLIT_WIDTH`. Ports: scalar inputs `clk,rst_n,wr_valid,rd_ready`; input `wr_data[WIDTH-1:0]`; outputs `rd_valid,full,empty,credit_out`, `rd_data[WIDTH-1:0]`, `count[$clog2(DEPTH+1)-1:0]`.

`rd_valid = !empty`, `full = count==DEPTH`, `empty = count==0`. When not empty, `rd_data` exposes the oldest stored flit combinationally. No combinational bypass from a new write into an empty FIFO. A stalled valid head stays unchanged until dequeued; data while empty is unspecified.

`enq = wr_valid && !full`, `deq = rd_ready && rd_valid` (both suppressed during reset). Counter next is count + enq − deq. Writes presented at full and reads requested at empty violate this candidate's protocol even if a simultaneous opposite request exists. The guards below still prevent pointer/count corruption.

| Pre-edge occupancy | wr_valid | rd_ready | Result at edge | Protocol status |
|---|---:|---:|---|---|
| Empty | 0 | 0 | No change | Legal |
| Empty | 1 | 0 | Enqueue only, count=1 | Legal |
| Empty | 0 | 1 | No dequeue, no credit | Illegal read request |
| Empty | 1 | 1 | Enqueue only; no bypass | Illegal read request |
| Between empty/full | 0 | 0 | No change | Legal |
| Between empty/full | 1 | 0 | Enqueue, count+1 | Legal |
| Between empty/full | 0 | 1 | Dequeue, count−1, one credit event | Legal |
| Between empty/full | 1 | 1 | Dequeue old head and enqueue new tail, count unchanged | Legal |
| Full | 0 | 0 | No change | Legal |
| Full | 0 | 1 | Dequeue, count=DEPTH−1 | Legal |
| Full | 1 | 0 | Write rejected | Illegal write request |
| Full | 1 | 1 | Write rejected, old head dequeued, count=DEPTH−1 | Illegal write request |

All FIFO storage need not reset; pointers/count must reset so no stale entry is valid. The FIFO has a same-cycle internal `credit_out`; `input_port` registers it once as specified above.

The original draft relabelled P04–P06 incorrectly. Pending a complete approved PLAN.md, preserve the bible's Gate-1 mapping: P01 no write while full, P02 no read while empty, P03 count range, P04 write-only increment, P05 read-only decrement, P06 credit iff dequeue. FWFT stability and reset checks are additional requirements; Aashish assigns their IDs. The inspected PLAN.md stops inside a template and does not contain the claimed 40-row register.

## 7. Front/back boundary and arbitration

Dimensions below are **per indexed element**, not the whole array width. Use leading packed dimensions `[NUM_PORTS-1:0][NUM_VCS-1:0]` for `[p][v]`, `[NUM_PORTS-1:0][NUM_VCS-1:0]` for `[o][v]`. Encoded ports use PORT_W bits. Only `route_unit` produces a one-hot route; `input_port` converts it to an encoded port for the boundary.

| Signal | Element width | Producer → consumer | Meaning |
|---|---:|---|---|
| `va_req[p][v]` | 1 | input_port → vc_allocator | WAIT_VC, valid HEAD/HEAD_TAIL, not already allocated |
| `va_out_port[p][v]` | PORT_W | input_port → vc_allocator | Stored encoded route |
| `va_grant[p][v]` | 1 | vc_allocator → input_port | Accept allocation at this edge |
| `va_out_vc[p][v]` | VC_W | vc_allocator → input_port | Granted downstream VC |
| `va_release[p][v]` | 1 | input_port → vc_allocator | Final grant dequeues TAIL/HEAD_TAIL |
| `sa_req[p][v]` | 1 | input_port → switch_allocator | ACTIVE, nonempty, allocated output has credit |
| `sa_out_port[p][v]` | PORT_W | input_port → switch_allocator | Held route |
| `sa_out_vc[p][v]` | VC_W | input_port → back half | Held output VC |
| `sa_flit[p][v]` | FLIT_WIDTH | input_port → back half | FIFO head |
| `sa_grant[p][v]` | 1 | switch_allocator → input_port | Final grant; dequeue at this edge |
| `ocredit_avail[o][v]` | 1 | output_unit → input_port | Current credit > 0 |
| `ocredit_count[o][v]` | CNT_W | output_unit → route_unit | Route-credit input; ignored by XY |
| `ovc_free[o][v]` | 1 | vc_allocator → debug/optional front view | Inverse of busy; not a duplicate ownership table |
| `xbar_sel[o][p]` | 1 | switch_allocator → crossbar | One-hot-or-zero input selection per output |
| `xb_flit[p]` | FLIT_WIDTH | granted-VC mux → crossbar | Selected `sa_flit[p][v]` |
| `xb_vc[p]` | VC_W | granted-VC mux → crossbar | Selected `sa_out_vc[p][v]` |
| `issue[o]` | 1 | switch_allocator → output_unit | OR of xbar_sel[o]; load/debit event |
| `issue_flit[o]` | FLIT_WIDTH | crossbar → output_unit | Selected unchanged flit |
| `issue_vc[o]` | VC_W | crossbar → output_unit | Selected downstream VC |

The granted-VC mux may sit in the front or top-level wiring, but it implements the same pure combinational selection. Unselected data are ignored. Tie inactive data to zero for readable waves.

`sa_req = ACTIVE && !empty && ocredit_avail[held_port][held_vc]`. It must not depend on a grant. SA does not re-check credits; final grant must be a subset of requests. For each output `o`, `$onehot0(xbar_sel[o])` holds. For each input `p`, `$onehot0(sa_grant[p])` holds across its VCs. Every asserted `sa_grant[p][v]` has exactly one corresponding `xbar_sel[o][p]`, where `o == sa_out_port[p][v]`, and every asserted `xbar_sel[o][p]` has exactly one corresponding final `sa_grant[p][v]`. `issue[o]` equals `|xbar_sel[o]`. An input FIFO dequeues and an output credit is debited only for that matched final grant. An input-stage winner that loses output arbitration does not dequeue. Advance its stage-1 round-robin pointer only on final grant; stage-2 pointer advances on its actual grant.

VA guarantees at most one owner for each output VC **and at most one output-VC grant per input VC**. Independent output-VC arbiters require tie-breaking to enforce the second rule. Requests may stay high while waiting; a grant moves the requester to ACTIVE so it cannot repeatedly acquire VCs. Store the owner mapping until release. `ovc_free` and grants use pre-edge busy state: release at Ek makes the VC eligible in C(k+1), not for a simultaneous reassignment at Ek. The old tail is already in the output register and retains its own VC sideband.

### 7.1 Per-VC state and nominal HEAD timing

IDLE → ROUTING → WAIT_VC → ACTIVE → IDLE on TAIL/HEAD_TAIL dequeue. While ACTIVE, FIFO gaps do not release the VC. Reset clears the state and allocation. Release identifies the input owner `(p,v)`; the allocator's mapping identifies which output VC to free.

| Interval | State before edge | Event at ending edge |
|---|---|---|
| C0 | IDLE, FIFO initially empty | Accept HEAD into FIFO at E0 |
| C1 | IDLE, HEAD visible | Start ROUTING at E1 |
| C2 | ROUTING | Capture route, enter WAIT_VC at E2 |
| C3 | WAIT_VC | VA grant captures output VC, enter ACTIVE at E3 |
| C4 | ACTIVE | Final SA grant dequeues HEAD and loads output at E4 |
| C5 | ACTIVE | Downstream accepts registered HEAD at E5; may issue next flit |

This is the proposed uncontended, available-route-resource schedule. Arbitration/credit waits extend it; it is not a fixed latency promise under contention. Buffered BODY/TAIL skip RC and VA, permitting one issued and accepted flit each cycle. See `wavedrom/head_pipeline.json` and `.png`.

## 8. Reset and testbench interface

All state updates use `always_ff @(posedge clk)` and `if (!rst_n)` first. After a reset edge: FIFOs empty; VC FSMs IDLE; allocator busy bits clear; output valid registers zero; return valid registers zero; all credit counters BUFFER_DEPTH. Testbench drivers and downstream models must obey reset too. Reset all endpoints of a link together: independently restarting one side with full credits while the other retains buffered data is outside this contract.

Reset mid-packet flushes FIFO contents, pending flits, delayed credits, packet-open state and scoreboard expectations. Such flushed packets are abandoned, not counted as loss. Drive reset away from the active edge; hold it low over at least two rising edges in TB. Ignore transfers while reset is sampled low.

`tb/env/flit_if.sv` bundles the five link signals with `clk,rst_n`, parameterized by FLIT_WIDTH and NUM_VCS. It deliberately owns no FIFO, credit counter, packet generator, or protocol assertions.

| View | Reads | Drives |
|---|---|---|
| `tx` modport | clock, reset, returned credits | flit, flit_valid, flit_vc |
| `rx` modport | clock, reset, forward flits | credit_valid, credit_vc |
| `mon` modport | All | Nothing |
| `cb` clocking block | reset, credits | Forward flits |
| `rx_cb` clocking block | reset, forward flits | Credits |
| `mon_cb` clocking block | All sampled signals | Nothing |

All clocking blocks sample inputs `#1step` before the rising edge; driving blocks use `output #0` after it. A value written through `cb` at Ek is intended for acceptance at E(k+1), not Ek. Use either a raw RTL driver or clocking-block TB driver per signal, never both. Phase-1 module/task drivers may access a statically instantiated interface; do not claim a class constructor avoids virtual-interface requirements. Probe the exact simulator/version before adopting a virtual-interface class driver. The supplied test includes a clocking-block probe.

## 9. Scoreboard and coverage contract

Use an independently written routing reference following section 3, not the DUT's route function. Record accepted injection `{input_port,input_vc,pkt_id,flit_idx,flit}` and accepted outputs `{output_port,output_vc,flit}`. Output VC may differ from input VC.

For this single-router profile, generator allocates `pkt_id` globally across all input ports/VCs until observed packet completion. Never reuse an outstanding ID; stop/wait when 256 IDs are occupied. The bible's queue key `(source port,input VC,pkt_id)` remains useful internally, but input port/VC cannot be recovered from output sideband after remapping. Global outstanding-ID uniqueness makes output matching unambiguous without adding flit fields. For later mesh traffic, revisit identity with source coordinates/NI identity; BODY source fields are opaque.

On output HEAD/HEAD_TAIL, use pkt_id to select its expectation and open tracking at `(output_port,output_vc)`. Check route, full flit bits, flit_idx order and length. BODY/TAIL match that open packet. TAIL closes it; HEAD_TAIL opens/closes atomically. Packet order is preserved per input VC and within a packet, not globally across all inputs/VCs. At successful drain, every expected queue is empty. Reset clears expectations and IDs.

Credit coverage must distinguish **issue** from registered **flit_valid**: issue with pre-edge zero credit is illegal; a registered flit with zero remaining credit is legal. The depth-2 trace exercises it. Same-port/5-requester bins are excluded only under a stated non-U-turn traffic profile, not because the combinational route function rejects them. The 20 non-self port pairs include four router-only XY cases: N→E, N→W, S→E, S→W.

Liveness bounds require persistent eligibility and environmental progress (eventual tail, downstream credit return). A fixed bound such as 48 is a plan value, not a proof for every parameter/traffic choice. Aashish owns PLAN.md and the eventual properties; this document defines the events they should check.

## 10. Acceptance before spec-v1

- All four resolve section 0 and review this document, package, interface and timing images together.
- Package bit widths/layout match at FLIT_WIDTH 32/64/128 and NUM_VCS 2/3/4.
- Both RTL owners can identify every boundary producer/consumer; Arnav reviews proposed package and flat top names.
- Interface-only tests exercise both modport directions, all VC IDs, reset, stall/resume, simultaneous credit/send, and unchanged flit data; clocking-block probe passes on the chosen tool.
- FIFO tests cover section 6's boundary table when Revanth's FIFO exists. Router tests confirm section 7 timing when router RTL exists.
- Aashish reconciles actual PLAN.md contents and assertion sampling; do not copy old P23's zero-credit/output-valid check unchanged.
- README and compile order include the new contract/interface/package. Current main has only commented entries in filelist.f, so green CI can currently mean “skipped”, not simulated.
- Actual router/FIFO integration and Xcelium qualification remain separate from the included model/interface tests. Do not tag spec-v1 solely because this kit's example passes.
