# noc-router-verification

![CI](https://github.com/zackkracky/noc-router-verification/actions/workflows/ci.yml/badge.svg)

Parameterized 5-port wormhole NoC router (virtual channels, XY routing, round-robin switch allocation, credit-based flow control) with a SystemVerilog verification environment: constrained-random traffic, reference-model scoreboard, SVA library, functional coverage, formal proofs of safety properties. The verification methodology is the contribution; the router is the vehicle.

Guide: Prof. P. Anuradha, CBIT. Target: DVCon India 2027.

## Team

| Name | Code | GitHub | Owns | Verifies (cross SVA) | Paper section |
|---|---|---|---|---|---|
| Revanth | R1 | @revantharigela | `rtl/front/`: `input_fifo`, `route_unit`, `input_port`, `vc_allocator` | Arnav's blocks | Router Architecture |
| Arnav | R2 | @zackkracky | `rtl/back/`, `rtl/pkg/`: `rr_arbiter`, `switch_allocator`, `crossbar`, `output_unit`, `router_top`; coordinator | Revanth's blocks | Results: area and timing |
| Sachin | V1 | @sachin19-02 | `tb/env/`, `tb/tests/`, Makefile, CI | — | Verification Methodology |
| Aashish | V2 | @coolboy965 | `tb/sva/`, `tb/cov/`, `formal/`, scoreboard, bug log | — | Intro, Related Work, Conclusion; editor |

Rule: the RTL owner never writes the assertions for their own block. Reviewer per path is in `.github/CODEOWNERS`.

## Quick start

Setup per machine: `docs/SETUP.md` (WSL2 Ubuntu 24.04, Verilator 5.020, Icarus 12). Everything runs inside the Ubuntu terminal, repo under `~/`.

```
git clone git@github.com:zackkracky/noc-router-verification.git
cd noc-router-verification
make lint                          # Verilator -Wall on rtl/, must be clean
make sim TEST=t_smoke SEED=1       # one test, one seed, prints PASS
make sim TEST=t_fifo SEED=3 TRACE=1  # with FST waveform for GTKWave
make regress SEEDS=100             # Phase 2: all random tests, all seeds
make cov                           # Phase 2: merged functional coverage
make formal                        # Phase 2: SymbiYosys proofs
make clean
```

Every test prints exactly one `PASS` or `FAIL` line per check; CI greps for `PASS`.

## Layout

| Path | Contents | Reviewer |
|---|---|---|
| `rtl/pkg/` | `noc_pkg.sv`: flit struct, port and type encodings, shared parameters | Revanth |
| `rtl/front/` | input side: FIFOs, routing, input port, VC allocator | Arnav |
| `rtl/back/` | output side: switch allocator, crossbar, output units, `router_top` | Revanth |
| `tb/env/` | `flit_if`, driver, monitor, scoreboard, generator, env | Sachin |
| `tb/tests/` | one `t_<name>.sv` per test; `waves/` holds a `.gtkw` per test | Sachin |
| `tb/sva/` | `PLAN.md`, one `<block>_sva.sv` per block, `bind_all.sv` | Aashish |
| `scripts/` | `regress.sh`, `cov_merge.py` (Phase 2) | Sachin |
| `docs/` | interface spec, bug log, contributing, setup; internal planning notes | Aashish |

`tb/cov/`, `formal/`, `fpga/`, `docs/paper/` are added by PR when their first file exists (Phase 2, Phase 2, Phase 3, Mar 2027).

## Parameters

Fixed in `docs/INTERFACE.md` (tag `spec-v1`). Any change is a PR reviewed by all four.

| Parameter | Default | Range | Notes |
|---|---|---|---|
| `FLIT_WIDTH` | 64 | 32 to 128 | bits per flit |
| `NUM_VCS` | 2 | 2 to 4 | virtual channels per port; `VC_W = $clog2(NUM_VCS)` |
| `BUFFER_DEPTH` | 4 | 2 to 8, power of 2 | flits per VC FIFO; credit counters reset to this |
| `X_COORD`, `Y_COORD` | 0, 0 | 0 to 7 | router position; N is +y |
| `ROUTE_ALGO` | `"XY"` | `"XY"`, `"WF"` (Phase 3) | string parameter on `route_unit`; fixed interface so Phase 3 drops in |

Port encoding: `N=0, E=1, S=2, W=3, L=4`. Flit types: `HEAD=0, BODY=1, TAIL=2, HEAD_TAIL=3`.

## Modules

One line per module. Updated in the same PR that lands or changes the module (interface changes update this table and `docs/INTERFACE.md` together).

| Module | File | Owner | Purpose | Status |
|---|---|---|---|---|
| `noc_pkg` | `rtl/pkg/noc_pkg.sv` | Arnav | flit struct, enums, parameter defaults | planned |
| `input_fifo` | `rtl/front/input_fifo.sv` | Revanth | synchronous FWFT FIFO per VC, `count`, `credit_out` on dequeue | planned |
| `route_unit` | `rtl/front/route_unit.sv` | Revanth | combinational XY route compute, `out_port_onehot[4:0]` | planned |
| `input_port` | `rtl/front/input_port.sv` | Revanth | `NUM_VCS` FIFOs, per-VC state machine, credit return, SA request | planned |
| `vc_allocator` | `rtl/front/vc_allocator.sv` | Revanth | output VC allocation, round-robin per output VC, busy table | planned |
| `rr_arbiter` | `rtl/back/rr_arbiter.sv` | Arnav | masked-priority round-robin arbiter, one-hot grant | planned |
| `switch_allocator` | `rtl/back/switch_allocator.sv` | Arnav | separable input-first SA, re-arbitrated every cycle | planned |
| `crossbar` | `rtl/back/crossbar.sv` | Arnav | 5x5 flit mux selected by stage-2 grant | planned |
| `output_unit` | `rtl/back/output_unit.sv` | Arnav | output register, per-VC credit counter, `ocredit_avail` | planned |
| `router_top` | `rtl/back/router_top.sv` | Arnav | 5 input ports, VA, SA, crossbar, 5 output units | planned |

Status values: planned, skeleton, unit-tested, integrated.

## Coding conventions

Checked by `make lint` (`-Wall`, zero warnings on RTL) and in review. A PR that breaks one is sent back.

1. SystemVerilog-2017. One module per file; file name equals module name.
2. `snake_case` for modules, signals, instances, files. Parameters `UPPER_CASE`. Instance names `u_<module>`.
3. `` `default_nettype none `` at the top of every RTL file, `` `default_nettype wire `` at the bottom.
4. Header comment, one line: purpose and interface. Comments are short and trail the line: `// something`. No block comments above every line.
5. Reset: synchronous, active-low `rst_n`, inside `always_ff @(posedge clk)` with `if (!rst_n)` first. One reset style for the whole design; this is it.
6. `always_comb` for all combinational logic, `always_ff` for all registers. No `always @*`, no `always @(posedge clk)` in RTL, no `initial` in RTL, no latches, no `#` delays in RTL.
7. `logic` everywhere. No `reg`, `wire`, `integer`. Loop indices `int unsigned` in `for` inside `always_comb`.
8. State machines: `typedef enum logic [N-1:0] {...} state_e;` with named states; next-state logic in `always_comb`, state register in `always_ff`; every `case` has a `default:`.
9. Widths derived with `$clog2()`, never hardcoded. No implicit truncation: Verilator `WIDTH` must be clean. Also clean: `UNUSED`, `LATCH`, `BLKSEQ`, `CASEINCOMPLETE`.
10. Port order: `clk`, `rst_n`, inputs, outputs. One port per line. Parameters before ports, defaults stated.
11. Non-blocking `<=` in `always_ff`, blocking `=` in `always_comb`. Never mixed.
12. Shared types and encodings come from `noc_pkg`; no local redefinition of flit fields or port numbers.
13. Testbench files (`tb/`) may use classes, queues, `$display`, `initial`. RTL files (`rtl/`) may not.

Template:

```systemverilog
// input_fifo: synchronous FWFT FIFO, DEPTH x WIDTH, credit_out pulses on dequeue
`default_nettype none
module input_fifo #(
  parameter int unsigned DEPTH = 4,          // power of 2
  parameter int unsigned WIDTH = 64
) (
  input  logic             clk,
  input  logic             rst_n,            // sync, active-low
  input  logic             wr_valid,
  input  logic [WIDTH-1:0] wr_data,
  input  logic             rd_ready,
  output logic             rd_valid,
  output logic [WIDTH-1:0] rd_data,
  output logic [$clog2(DEPTH):0] count,
  output logic             full,
  output logic             empty,
  output logic             credit_out
);
  // ...
endmodule
`default_nettype wire
```

## Process

Full rules: `docs/CONTRIBUTING.md`. The short version:

1. Never push to `main`. Branch `<name>/<task>`, PR, one review, squash merge. GitHub refuses anything else.
2. Commit title `<scope>: what changed`, under 72 characters, imperative.
3. No RTL without a test. No bug fix without the check that catches it and a `docs/BUG_LOG.md` row.
4. `make lint && make sim` green locally before the PR is marked ready.
5. Rebase, `--force-with-lease`, never `--force`. Only on your own branch.
6. Review within 24 h. Pull and run before approving RTL.
7. Commit email matches your GitHub account; contribution is counted from history.
8. Push your branch before closing the laptop.

## Documents

| File | What | Updated by |
|---|---|---|
| `docs/INTERFACE.md` | flit format, link handshake, credits, front/back boundary, reset; tagged `spec-v1` | Sachin |
| `docs/BUG_LOG.md` | every bug caught by a test or property: id, found by, symptom, root cause, fix | fix PR author |
| `tb/sva/PLAN.md` | property list with group, owner, status | Aashish |

## References

Dally and Towles, Principles and Practices of Interconnection Networks, ch. 13, 16, 18, 19. Becker and Dally, Allocator Implementations for NoC Routers, SC 2009. Peh and Dally, A Delay Model and Speculative Architecture for Pipelined Routers, HPCA 2001.