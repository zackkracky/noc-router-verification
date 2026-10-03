# INTERFACE.md — NoC router interface spec (spec-v1 candidate)

Status: DRAFT for four-way sign-off. On sign-off, tag `spec-v1` on the merge commit.
Authoritative source of widths: `rtl/pkg/noc_pkg.sv`. Where this doc and the package disagree, the package wins and this doc is the bug.
Any change after tagging is a PR reviewed by all four and a new tag (`spec-v2`, ...).

Sign-off (name / date / commit):
- Revanth (front RTL):
- Arnav (back RTL, coordinator):
- Sachin (TB, author):
- Aashish (SVA/formal, editor):

## 1. Parameters

| Parameter | Default | Range | Notes |
|---|---|---|---|
| `FLIT_WIDTH` | 64 | 32–128 | bits per flit; must be >= HDR_W + 1 |
| `NUM_VCS` | 2 | 2–4 | VCs per port; `VC_W = $clog2(NUM_VCS)` |
| `BUFFER_DEPTH` | 4 | 2–8, power of 2 | flits per VC FIFO; credits reset to this |
| `X_COORD`, `Y_COORD` | 0, 0 | 0–7 | this router's position; N is +y |
| `ROUTE_ALGO` | `"XY"` | `"XY"`, `"WF"`(P3) | string param on route_unit; interface fixed so WF drops in |

Derived (do not hardcode): `VC_W = $clog2(NUM_VCS)` (=1 at NUM_VCS=2, =2 at 4); credit counter width `CNT_W = $clog2(BUFFER_DEPTH+1)` (=3 at DEPTH=4).

## 2. Package constants (`noc_pkg`)

| Name | Value | Meaning |
|---|---|---|
| `NUM_PORTS` | 5 | N E S W L |
| `PORT_W` | 3 | $clog2(NUM_PORTS) |
| `COORD_W` | 3 | coord field width, 0–7 |
| `VC_FIELD_W` | 2 | header VC field, holds NUM_VCS up to 4 |
| `FTYPE_W` | 2 | flit-type field |
| `HDR_W` | 10 | FTYPE_W + VC_FIELD_W + 2*COORD_W |

Port encoding: `N=0, E=1, S=2, W=3, L=4` (`port_e`). Flit types: `HEAD=0, BODY=1, TAIL=2, HEAD_TAIL=3` (`ftype_e`).

## 3. Flit format

Header occupies the top `HDR_W=10` bits of every flit; payload is the low `FLIT_WIDTH-HDR_W` bits (54 at FLIT_WIDTH=64).

```
flit[FLIT_WIDTH-1 : FLIT_WIDTH-HDR_W]  = header (hdr_t)
flit[FLIT_WIDTH-HDR_W-1 : 0]           = payload
```

`hdr_t` (packed, MSB first), `$bits(hdr_t) == HDR_W == 10`:

| Field | Bits (within header) | Width | Meaning |
|---|---|---|---|
| `ftype` | [9:8] | 2 | HEAD / BODY / TAIL / HEAD_TAIL |
| `vc` | [7:6] | 2 | VC id on the link this flit currently occupies |
| `dst_x` | [5:3] | 3 | destination router X |
| `dst_y` | [2:0] | 3 | destination router Y |

Rules:
1. `vc` is link-local. It names the VC on the link the flit is on now, not end-to-end. `output_unit` restamps `vc` to the allocated output VC before forwarding (zero-extended when NUM_VCS < 4).
2. `dst_x/dst_y` carried only in HEAD and HEAD_TAIL; BODY/TAIL payload bits in that field are don't-care and must not be read by RTL.
3. BODY/TAIL of a packet follow the VC and output reserved by its HEAD until the TAIL releases it (wormhole).
4. A single-flit packet is HEAD_TAIL: it both allocates and releases in one flit.
5. Inputs are assumed well-formed (a HEAD before any BODY, exactly one TAIL per packet, dst in range). RTL does not detect malformed streams; SVA does. Behavior on a malformed input is undefined.

## 3a. Direction and coordinate convention

Grid is +x East, +y North. From this router at `(X_COORD, Y_COORD)` toward `(dst_x, dst_y)`:

| Condition | Output port |
|---|---|
| `dst_x > X_COORD` | E |
| `dst_x < X_COORD` | W |
| `dst_x == X_COORD` and `dst_y > Y_COORD` | N |
| `dst_x == X_COORD` and `dst_y < Y_COORD` | S |
| `dst_x == X_COORD` and `dst_y == Y_COORD` | L (eject) |

This is the single routing authority. `route_unit` (RTL) and the scoreboard reference model (TB) both implement exactly this and must never diverge.

## 3b. XY routing function (route_unit contract)

XY = dimension-order, X first then Y. `route_unit` is purely combinational: `out_port_onehot[4:0]` is the one-hot of the table in 3a, encoding `N=0,E=1,S=2,W=3,L=4`. Properties implied, for the cross-SVA on Revanth's blocks (owner: Arnav):
1. `out_port_onehot` is always exactly one-hot for an in-range HEAD.
2. A packet whose dst equals this router's coords routes to L, never to a network port.
3. No U-turn: the chosen port is never the port the HEAD arrived on, for any reachable src/dst pair in an XY mesh. (This is what makes XY deadlock-free; it is a checkable property, not an assumption.)
4. `L` input never routes back to `L`.

## 4. Link protocol (per port, both directions)

One unidirectional flit channel plus one credit channel per direction. No ready/valid backpressure on flits; a sender transmits only when it holds a credit.

Forward (sender -> receiver):
| Signal | Width | Meaning |
|---|---|---|
| `valid` | 1 | `flit` is live this cycle |
| `flit` | FLIT_WIDTH | header + payload as in section 3 |

Backward (receiver -> sender), credit return:
| Signal | Width | Meaning |
|---|---|---|
| `credit_valid` | 1 | one credit returned this cycle |
| `credit_vc` | VC_W | which VC the freed buffer belongs to |

Timing: receiver's `input_fifo` pulses `credit_valid` the cycle a flit is dequeued. Credit latency (dequeue -> sender counter increment) is 1 cycle across the link register. Each output_unit credit counter resets to `BUFFER_DEPTH`.

## 5. Credit / flow-control invariants (for SVA, owner cross-assigned)

Let `credit[o][v]` be the output_unit counter for output port `o`, VC `v`.
1. `0 <= credit[o][v] <= BUFFER_DEPTH` at all times.
2. A flit is launched on `(o,v)` only when `credit[o][v] > 0`; launch decrements.
3. `credit_valid`/`credit_vc` from downstream increments `credit[o][v]`; never increments above BUFFER_DEPTH.
4. Simultaneous launch + credit-return on the same `(o,v)` is net-zero (handled in `output_unit`).
5. No credit underflow: never decrement from 0.

## 6. Front/back boundary (input_port <-> back half)

This is the contract between Revanth's front half and Arnav's back half. Widths are per input port `p`; arrays indexed `[v]` are per input VC.

| Signal | From | Width | Meaning |
|---|---|---|---|
| `va_req[v]` | input_port | NUM_VCS | HOL flit is a HEAD/HEAD_TAIL with no output VC yet |
| `va_oport[v]` | input_port | NUM_VCS × 5 | one-hot output port from route_unit |
| `va_grant[v]` | vc_allocator | NUM_VCS | output VC granted this cycle |
| `va_ovc[v]` | vc_allocator | NUM_VCS × VC_W | which output VC |
| `va_release[v]` | input_port | NUM_VCS | TAIL/HEAD_TAIL dequeued; free the output VC |
| `sa_req[v]` | input_port | NUM_VCS | HOL flit present AND ovc held AND `ocredit_avail[oport][ovc]` |
| `sa_oport[v]` | input_port | NUM_VCS × 5 | held one-hot output port for the packet |
| `sa_grant_vc[v]` | switch_allocator | NUM_VCS | one-hot; dequeue this VC this cycle |
| `ocredit_avail[o][v]` | output_unit ×5 | 5 × NUM_VCS | credit[o][v] > 0 |
| `xb_flit` | input_port | FLIT_WIDTH | HOL flit of the granted VC (comb mux on sa_grant_vc) |
| `xb_ovc` | input_port | VC_W | its allocated output VC |

Division of responsibility (pins the credit check):
- `input_port` gates `sa_req` on `ocredit_avail`. The switch allocator does NOT re-check credits; it assumes a request implies a credit.
- `vc_allocator` grants at most one output VC per `(output port, output VC)` and holds it until `va_release`.
- `switch_allocator` is separable input-first: stage 1 one VC per input port, stage 2 one input per output port; re-arbitrated every cycle; `grant_vc` and `xbar_sel` one-hot-or-zero.

## 6a. input_fifo contract (gates the Oct 15 Phase 1a Gate 1)

One `input_fifo` per VC. `DEPTH = BUFFER_DEPTH`, `WIDTH = FLIT_WIDTH`. First-word fall-through (FWFT): no read latency, `rd_data` is the head whenever `!empty`.

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | sync, active-low |
| `wr_valid` | in | 1 | enqueue `wr_data` this cycle |
| `wr_data` | in | FLIT_WIDTH | flit to enqueue |
| `rd_ready` | in | 1 | consumer takes the head this cycle |
| `rd_valid` | out | 1 | head is valid (`== !empty`) |
| `rd_data` | out | FLIT_WIDTH | head flit (FWFT, combinational from storage) |
| `count` | out | `$clog2(DEPTH)+1` | occupancy 0..DEPTH |
| `full` | out | 1 | `count == DEPTH` |
| `empty` | out | 1 | `count == 0` |
| `credit_out` | out | 1 | pulses 1 cycle on dequeue; drives the upstream router's credit return |

Semantics:
1. Dequeue occurs when `rd_valid && rd_ready`; `credit_out` pulses that same cycle.
2. `credit_out` is this router's `credit_valid` toward upstream; the VC it frees is the flit's input VC (carried alongside on the link's `credit_vc`).
3. Simultaneous enqueue+dequeue when `count` is between 1 and DEPTH-1 leaves `count` unchanged.
4. Writing while `full`, or reading while `empty`, is illegal (sender must hold a credit). RTL behavior on violation is undefined; FIFO SVA P01–P06 catch it. These are the properties Aashish binds for Gate 1.

FIFO SVA set for Gate 1 (Aashish), named to match PLAN.md P01–P06:
- P01 no overflow: `!(wr_valid && full && !(rd_valid && rd_ready))`
- P02 no underflow: `!(rd_ready && empty)` dequeue has no effect
- P03 count bounds: `0 <= count <= DEPTH`
- P04 FWFT: `rd_valid == !empty` and `rd_data` stable while head not dequeued
- P05 credit pulse: `credit_out |-> (rd_valid && rd_ready)` prev cycle, one pulse per dequeue
- P06 reset: after `!rst_n`, `count==0 && empty && !rd_valid`

## 7. Reset

Single reset style, whole design: synchronous, active-low `rst_n`, sampled in `always_ff @(posedge clk)` with `if (!rst_n)` first. No async reset, no second reset domain. On reset: all FIFOs empty, all VC state IDLE, all credit counters = BUFFER_DEPTH, all `*_valid` outputs 0.

## 8. Clocking

Single clock `clk`, one domain. Link outputs (`out_valid`, `out_flit`) are registered in output_unit. The datapath from input_fifo read through crossbar to output register is combinational within one cycle. No multicycle paths in spec-v1.

## 9. Module port list owners

`noc_pkg`, `rr_arbiter`, `switch_allocator`, `crossbar`, `output_unit`, `router_top`: Arnav.
`input_fifo`, `route_unit`, `input_port`, `vc_allocator`: Revanth.
Port lists for `input_port` and `vc_allocator` are fixed by section 6, `input_fifo` by 6a, `route_unit` by 3a/3b, all frozen at spec-v1; bodies are Revanth's.

## 10. Scoreboard / reference-model contract

For a packet injected at input port `p` with header `(dst_x, dst_y)`, the reference model computes the expected output port by the section 3a table and asserts:
1. Every flit of the packet emerges on that one output port, in injection order (wormhole, no interleave with another packet on the same output VC).
2. Payload bits `[FLIT_WIDTH-HDR_W-1:0]` are unchanged end to end.
3. The only header field the router may change is `vc` (restamp, section 3 rule 1). `ftype`, `dst_x`, `dst_y` are preserved.
4. Flit count in == flit count out per packet; exactly one HEAD(/HEAD_TAIL) and one TAIL(/HEAD_TAIL).

This is the matching rule for the Phase 2 scoreboard (Aashish). It is stated here so the reference model and `route_unit` share one source of truth.