# noc-router-verification

![CI](https://github.com/zackkracky/noc-router-verification/actions/workflows/ci.yml/badge.svg)

Parameterized 5-port wormhole NoC router (virtual channels, XY routing, round-robin switch allocation, credit-based flow control) and a SystemVerilog verification environment being built around it. Planned: constrained-random traffic with a reference-model scoreboard, a 52-property SVA library, functional coverage, and JasperGold proofs of the safety properties. The verification methodology is the contribution; the router is the vehicle. The planned paper will compare which bug classes constrained-random simulation, SVA in simulation and formal each catch, using 37 mutants in 7 classes.

On `main` today (Phase 1): `noc_pkg`, `input_fifo` and `rr_arbiter` unit-tested with CI green; FIFO properties P01-P06 bound and passing in CI; the 52-property plan in `tb/sva/PLAN.md`; one property-caught pre-merge defect (PM-001) in `docs/BUG_LOG.md`. The scoreboard, coverage model and formal runs are Phase 2 (Jan-Feb 2027); `tb/cov/` and `formal/` do not exist yet.

Guide: Prof. P. Anuradha, CBIT. Target: DVCon India 2027.

Current phase, gate status, open bugs and counters: `docs/STATE.md`. Weekly history: `docs/SYNC.md`.

## Team

| Name | Code | GitHub | Owns | Verifies (cross SVA) | Paper section |
|---|---|---|---|---|---|
| Revanth | R1 | @revantharigela | `rtl/front/`: `input_fifo`, `route_unit`, `input_port`, `vc_allocator` | Arnav's blocks | Router Architecture |
| Arnav | R2 | @zackkracky | `rtl/back/`, `rtl/pkg/`: `rr_arbiter`, `switch_allocator`, `crossbar`, `output_unit`, `router_top`; coordinator | Revanth's blocks | Results: area and timing |
| Sachin | V1 | @sachin19-02 | `tb/env/`, `tb/tests/`, Makefile, CI | — | Verification Methodology |
| Aashish | V2 | @coolboy965 | `tb/sva/`, `tb/cov/`, `formal/`, scoreboard, bug log | — | Intro, Related Work, Conclusion; editor |

Rule: the RTL owner never writes the assertions for their own block. Reviewer per path is in `.github/CODEOWNERS`.

## Quick start

Setup per machine: `docs/SETUP.md` (WSL2 Ubuntu 24.04, Verilator 5.020+, Icarus 12, GTKWave). Everything runs inside the Ubuntu terminal, repo under `~/`. Xcelium and JasperGold are available only on the college lab machines.

```bash
git clone git@github.com:zackkracky/noc-router-verification.git
cd noc-router-verification
make lint TEST=tb_noc_pkg
make sim  TEST=tb_noc_pkg SEED=1
make sim  TEST=tb_noc_pkg SEED=1 WAVES=1   # dumps logs/tb_noc_pkg_s1.fst
make waves TEST=tb_noc_pkg SEED=1          # opens it in GTKWave
make check SEEDS="1 2 3 4 5"               # seven tests: 42 checks; logs/summary.txt
make neg                                   # two expected failures; logs/negative-summary.txt
make clean
```

Every test prints `TEST PASSED`; `make sim` fails if the marker is missing. CI (`lint-and-sim`) runs `make check SEEDS="1 2 3 4 5"` followed by `make neg` on every PR and on push to `main`: every `tb/tests/*.f` is linted and simulated, both summaries are on the run page, and `logs/` (plus waves for failing seeds) is downloadable as the run artifact for 14 days.

### Make targets

| Target | Variables | Does |
|---|---|---|
| `lint` | `TEST=` | Verilator `-Wall --lint-only` on the test's filelist; warnings fatal; log in `logs/<test>_lint_<sim>.log` |
| `lint-rtl` | `FILE=rtl/back/rr_arbiter.sv` | one RTL file with `noc_pkg`, no testbench |
| `build` | `TEST=` | compile only |
| `sim` (alias `run`) | `TEST= SEED= WAVES=0/1 SIM=verilator/xcelium` | build and run, require `TEST PASSED`; logs in `logs/<test>_build_<sim>.log` and `logs/<test>_s<seed>_<sim>.log` |
| `waves` | `TEST= SEED=` | open the newest `.fst`/`.vcd` for that test and seed, with `tb/tests/waves/<TEST>.gtkw` if present |
| `check` | `SEEDS="1 2 3 4 5" TESTS= SIM=` | lint once and sim per seed for every `tb/tests/*.f` (or `TESTS=`); one line per result in `logs/summary.txt`; non-zero exit on any FAIL. CI runs exactly this |
| `neg` | `WAVES=0/1` | Verilator expected-failure tests for malformed framing and invalid VC; requires nonzero exit and the expected fatal message; CI runs this after `check` |
| `regress`, `cov`, `formal` | — | Phase 2 stubs |
| `clean` | — | removes `obj_*`, `xcelium_*`, `logs/` |

Filelist resolution: `tb/tests/<TEST>.f` if it exists, else `filelist.f`; `FILELIST=` overrides. Each new test ships its own `.f` (package, interfaces, RTL, then the test). Do not edit `filelist.f` for a single test. `SIM=xcelium` uses `xrun -svseed $(SEED)` and VCD dumps.

## Layout

| Path | Contents | Reviewer |
|---|---|---|
| `rtl/pkg/` | `noc_pkg.sv`: constants, enums, 30-bit `hdr_t`, `vc_w()` / `cnt_w()` helpers | Revanth |
| `rtl/front/` | input side: FIFOs, routing, input port, VC allocator | Arnav |
| `rtl/back/` | output side: arbiter, switch allocator, crossbar, output units, `router_top` | Revanth |
| `tb/env/` | PR #18 adds `flit_if`, `flit_pkt`, driver and monitor; scoreboard, generator and env are planned | Aashish |
| `tb/tests/` | one `tb_<name>.sv` plus `tb_<name>.f` per test; `waves/` holds a `.gtkw` per test | Aashish |
| `tb/sva/` | `PLAN.md` (52 properties), one `<block>_sva.sv` per block, `bind_all.sv` (only place SVA attaches) | Sachin |
| `scripts/` | planned: `regress.sh`, `cov_merge.py`, `mutate.py` (Phase 2) | Arnav |
| `docs/` | `INTERFACE.md`, `STATE.md`, `SYNC.md`, `BUG_LOG.md`, `wavedrom/` timing diagrams, `figures/` | Aashish |
| `docs/wavedrom/` | `head_pipeline.json`, `credit_stall.json` and rendered PNGs; the timing reference for INTERFACE.md s5 | Aashish |

`tb/cov/`, `formal/`, `fpga/`, `docs/paper/` are added by PR when their first file exists (Phase 2, Phase 2, Phase 3, Mar 2027).

## Parameters

Governed by `docs/INTERFACE.md`. Any change is a PR reviewed by all four.

| Parameter | Default | Range | Notes |
|---|---|---|---|
| `FLIT_WIDTH` | 64 | 32 to 128 | bits per flit; payload is `FLIT_WIDTH - 30` |
| `NUM_VCS` | 2 | 2 to 4 | virtual channels per port; `VC_W = vc_w(NUM_VCS)` (floor 1) |
| `BUFFER_DEPTH` | 4 | 2, 4, 8 | flits per VC FIFO; `CNT_W = cnt_w(BUFFER_DEPTH) = $clog2(DEPTH+1)`; credit counters reset to this |
| `X_COORD`, `Y_COORD` | 0, 0 | 0 to 7 | router position; E is +x, N is +y |
| `ROUTE_ALGO` | `"XY"` | `"XY"`, `"WF"` (Phase 3) | string parameter on `route_unit`; fixed port list so Phase 3 drops in |

Fixed constants in `noc_pkg`: `NUM_PORTS=5`, `PORT_W=3`, `COORD_W=3`, `FTYPE_W=2`, `PKT_ID_W=8`, `FLIT_IDX_W=8`, `HDR_W=30`.

Port encoding: `N=0, E=1, S=2, W=3, L=4`. Flit types: `HEAD=0, BODY=1, TAIL=2, HEAD_TAIL=3`. VC states: `IDLE, ROUTING, WAIT_VC, ACTIVE`.

Flit layout, MSB first: `ftype[2] dst_x[3] dst_y[3] src_x[3] src_y[3] pkt_id[8] flit_idx[8] payload[FLIT_WIDTH-30]`. The VC travels on sideband `flit_vc`, not inside the flit. `hdr_t` is the fixed 30-bit header; `flit_t` is declared locally as `logic [FLIT_WIDTH-1:0]` so overrides are not silently forced back to 64.

Link handshake: valid-only, no `ready`. Sender holds `flit_valid` low without credit. Credit return is `credit_valid` plus `credit_vc`, one per cycle, registered once in `input_port` (FIFO `credit_out` is combinational).

## Modules

One line per module. Updated in the same PR that lands or changes the module (interface changes update this table and `docs/INTERFACE.md` together).

| Module | File | Owner | Purpose | Status |
|---|---|---|---|---|
| `noc_pkg` | `rtl/pkg/noc_pkg.sv` | Arnav | constants, enums, `hdr_t`, width helpers | unit-tested (`tb_noc_pkg`, PR #14) |
| `input_fifo` | `rtl/front/input_fifo.sv` | Revanth | synchronous FWFT FIFO per VC, `count`, combinational `credit_out` on dequeue | unit-tested (`tb_fifo`, PR #13); PM-001 fixed before merge |
| `route_unit` | `rtl/front/route_unit.sv` | Revanth | combinational XY route compute, `out_port_onehot[4:0]`; `route_credit` input reserved for WF | planned |
| `input_port` | `rtl/front/input_port.sv` | Revanth | `NUM_VCS` FIFOs, per-VC state machine, registered credit return, SA request | planned |
| `vc_allocator` | `rtl/front/vc_allocator.sv` | Revanth | output VC allocation, round-robin per output VC, single busy/owner table | planned |
| `rr_arbiter` | `rtl/back/rr_arbiter.sv` | Arnav | masked-priority round-robin arbiter, one-hot grant; one module for SA stage 1, SA stage 2 and VA (INTERFACE.md s7.2) | unit-tested (`tb_rr_arbiter`, #16) |
| `switch_allocator` | `rtl/back/switch_allocator.sv` | Arnav | separable input-first SA, re-arbitrated every cycle | planned |
| `crossbar` | `rtl/back/crossbar.sv` | Arnav | 5x5 flit mux selected by stage-2 grant | planned |
| `output_unit` | `rtl/back/output_unit.sv` | Arnav | output register, per-VC credit counter (credits only, no ownership) | planned |
| `router_top` | `rtl/back/router_top.sv` | Arnav | 5 input ports, VA, SA, crossbar, 5 output units | planned |

Status values: planned, skeleton, unit-tested, integrated. "unit-tested" means lint clean and passing on `main`.

SVA on `main`: `tb/sva/fifo_sva.sv` P01-P06 bound to `input_fifo` by `bind_all.sv`, run in `tb_fifo` by `make check` and CI (#17). Link environment proposed in PR #18: `flit_if`, `flit_pkt`, `flit_driver`, `flit_monitor`; tests `tb_flit_if`, `tb_fifo_link`.

## Phase 1a link environment

Files: `tb/env/{flit_if,flit_pkt,flit_driver,flit_monitor}.sv`; real-FIFO harness `tb/tests/tb_fifo_link.sv`.
Run `make sim TEST=tb_fifo_link SEED=1 WAVES=1`; run expected failures with `make neg` (also in CI).
Four configurations `(F,V,D) = (32,2,2), (64,3,4), (128,4,8), (32,1,4)`; this is not a Cartesian parameter sweep.
`tb_flit_if` checks transaction pack/unpack only; `tb_fifo_link` binds P01-P06. `tb_fifo_empty_read` separately probes illegal empty reads without binding the environment constraints (INTERFACE s6).
See [INTERFACE section 8](docs/INTERFACE.md#8-reset-and-testbench-interface) for the contract and [STATE](docs/STATE.md) for tool qualification/status.

## Coding conventions

Checked by `make lint` (`-Wall`, zero warnings on RTL, warnings fatal; never `-Wno-fatal` on `lint`) and in review. A PR that breaks one is sent back.

1. SystemVerilog-2017. One module per file; file name equals module name (`DECLFILENAME` clean).
2. `snake_case` for modules, signals, instances, files. Parameters `UPPER_CASE`. Instance names `u_<module>`.
3. `` `default_nettype none `` at the top of every RTL file, `` `default_nettype wire `` at the bottom. No `` `timescale `` in RTL; the Makefile sets `1ns/1ps`.
4. Header comment, one line: purpose and interface. Comments are short and trail the line: `// something`. No block comments above every line.
5. Reset: synchronous, active-low `rst_n`, inside `always_ff @(posedge clk)` with `if (!rst_n)` first. One reset style for the whole design; this is it.
6. `always_comb` for all combinational logic, `always_ff` for all registers. No `always @*`, no `always @(posedge clk)` in RTL, no `initial` in RTL, no latches, no `#` delays in RTL.
7. `logic` everywhere. No `reg`, `wire`, `integer`. Loop indices `int unsigned` in `for` inside `always_comb`.
8. State machines: `typedef enum logic [N-1:0] {...} state_e;` with named states; next-state logic in `always_comb`, state register in `always_ff`; every `case` has a `default:`.
9. Widths from `noc_pkg::vc_w()` / `cnt_w()` or `$clog2()`, never hardcoded. No implicit truncation: Verilator `WIDTH` must be clean. Also clean: `UNUSED`, `LATCH`, `BLKSEQ`, `CASEINCOMPLETE`. The only permitted `UNUSEDSIGNAL` waiver is the two reserved WF ports in `route_unit` (INTERFACE.md s3).
10. Port order: `clk`, `rst_n`, inputs, outputs. One port per line. Parameters before ports, defaults stated.
11. Non-blocking `<=` in `always_ff`, blocking `=` in `always_comb`. Never mixed.
12. Shared types and encodings come from `noc_pkg`; no local redefinition of flit fields, port numbers or width helpers. Declare `flit_t` locally per module.
13. Testbench files (`tb/`) may use classes, queues, `$display`, `initial`. RTL files (`rtl/`) may not.
14. Tests are `tb_<name>.sv` with a matching `tb_<name>.f`, module name equals file name, and end with `$display("TEST PASSED")`.

Template:

```systemverilog
// input_fifo: synchronous FWFT FIFO, DEPTH x WIDTH, credit_out high on dequeue (combinational)
`default_nettype none
module input_fifo
  import noc_pkg::*;
#(
  parameter int unsigned DEPTH = DEF_BUFFER_DEPTH,   // 2, 4, 8
  parameter int unsigned WIDTH = DEF_FLIT_WIDTH
) (
  input  logic             clk,
  input  logic             rst_n,                    // sync, active-low
  input  logic             wr_valid,
  input  logic [WIDTH-1:0] wr_data,
  input  logic             rd_ready,
  output logic             rd_valid,
  output logic [WIDTH-1:0] rd_data,
  output logic [cnt_w(DEPTH)-1:0] count,
  output logic             full,
  output logic             empty,
  output logic             credit_out
);
  // ...
endmodule
`default_nettype wire
```

## Process

This section is the process reference for the repo. Rules marked (enforced) are checked by the `protect-main` ruleset or CI; the rest are checked in review. A PR that breaks a rule is sent back, not merged with a note. Paper authorship order is decided by counted merged contribution, so history is part of the deliverable.

### Short version

1. Never push to `main`. Branch, PR, one review, squash merge. (enforced)
2. Commit title `<scope>: what changed`, under 72 characters, imperative.
3. No RTL without a test. No bug fix without the check that catches it and a `docs/BUG_LOG.md` row.
4. `make lint && make sim` green locally before the PR is marked ready.
5. Rebase, `--force-with-lease`, never `--force`. Only on your own branch.
6. Review within 24 h. Pull and run before approving RTL.
7. Commit email matches your GitHub account; contribution is counted from history.
8. Push your branch before closing the laptop. A laptop is not a backup.

### Branches

- `main` accepts only a CI-green (`lint-and-sim`), approved, up-to-date, squash-merged PR. No bypass, owner included. (enforced)
- One branch per task: `<name>/<short-task>`, lowercase, hyphens (`revu/input-fifo`, `aashish/sva-fifo`). Not `fix`, `work`, `test123`.
- Branch from fresh `main` (`git switch main && git pull`), never from another feature branch.
- Target merge within 5 days; a branch older than 2 weeks is rebased or split.
- Never commit to someone else's branch; comment on their PR instead.
- Delete the local branch after merge (`git branch -d`); GitHub deletes the remote one.

### Commits

- Format `<scope>: <what changed>`. Scopes: `rtl pkg fifo route vc_alloc sw_alloc arb xbar credit tb sva cov formal ci docs scripts make`. Body only when the why is not obvious from the diff.
- Good: `fifo: make credit_out combinational on dequeue`. Bad: `update`, `fixed bug`, `final version`.
- One logical change per commit. RTL plus its test is one commit; RTL plus an unrelated typo fix is two.
- `make lint` passes at every commit, not only the last (`git bisect` depends on it).
- No generated files (`obj_*`, `xcelium_*`, `logs/`, `*.fst`, `*.vcd`, `*.log`, coverage data). `git status` before `git add`; `git add -p` for mixed files.
- No secrets, absolute paths (`/home/<user>/...`) or editor settings. Secret scanning push protection blocks tokens. (enforced)
- Squash WIP commits (`git rebase -i origin/main`) before opening the PR.

### Every change carries proof

| Change | Must include |
|---|---|
| New RTL module or interface | directed `tb/tests/tb_<name>.sv` + `.f` exercising every port; Modules table here and `docs/INTERFACE.md` updated in the same PR |
| RTL behavior change | updated or new test that fails on the old RTL |
| Bug fix | catching property or test, plus a `docs/BUG_LOG.md` row (id, date, found by + seed, symptom, root cause, fix, catching check). Counted only if the bug was in merged RTL; branch findings go under "Pre-merge findings" as `PM-nnn` |
| New SVA property | name, one-line intent, clock/reset, group (protocol / safety / liveness), row in `tb/sva/PLAN.md`; liveness gets a bounded `##[0:N]` form |
| New covergroup | named bins, explicit crosses, comment listing bins expected unreachable and why |
| Parameter change | default stated, at least one test at a non-default value |

### Before you push

```bash
git switch main && git pull                  # fresh main
git switch -c revu/input-fifo                # one task
make lint TEST=tb_fifo                       # zero warnings, -Wall fatal
make sim  TEST=tb_fifo SEED=1                # your test passes
make sim  TEST=tb_noc_pkg SEED=1             # existing tests still pass
git status                                   # only the files you meant
git add -A && git commit                     # message per Commits
git fetch && git rebase origin/main          # if main moved
git push -u origin revu/input-fifo
```

Red code on your own branch is fine; the PR is not marked ready until lint and both sims are green locally.

### Pull requests

- Fill `.github/PULL_REQUEST_TEMPLATE.md`: what, why, exact command and seed, which test or property covers it. Empty template is sent back.
- PR title is the squash commit title; the body says `Closes #<issue>`.
- Under 400 changed lines; larger work is a stack of PRs, each mergeable alone.
- Reviewer comes from `.github/CODEOWNERS`. Front half reviews back half and vice versa. Never self-approve. (enforced)
- Open as Draft for early CI; mark Ready only when the pre-push checks are green.
- Answer every comment: fix, or reply why not. The reviewer resolves the thread.
- Rebase onto `origin/main` and `--force-with-lease`; no merge commits from `main`. (enforced: linear history)
- Author merges after approval and owns `main` being green afterwards. Edit the squash message to drop the WIP bullet list.

### Reviewing

1. Order: functional bugs, protocol (credit accounting, VC state, handshake), synthesizability (latches, `initial`, missing reset), style.
2. Each comment: line, what breaks, suggested fix. "Looks wrong" is not a comment.
3. Pull and run before approving RTL or scoreboard changes: `gh pr checkout <n> && make sim TEST=<test>`. A diff does not show an off-by-one in a credit counter.
4. Turnaround 24 h on weekdays; if you cannot, say so on the PR and the author picks another reviewer.
5. Approve only code you would debug at 2 am with the author unavailable.

### Staying in sync

- `git pull` only on `main` (with `pull.ff only`). On a feature branch: `git fetch && git rebase origin/main`.
- Pull at the start of every session: before branching, rebasing or reviewing.
- `git stash` is for minutes. Anything kept overnight is a commit on a pushed branch.

### Tracking

- Every task is a GitHub issue (title, one paragraph, assignee, milestone) before it is a branch.
- Milestones: Phase 1 exit (Dec 2026), Phase 2 exit (Feb 2027), Paper (Apr 2027). No others.
- RTL bugs get an issue labelled `bug` and a `docs/BUG_LOG.md` row: the issue tracks, the log feeds the paper.
- `docs/SYNC.md` append-only, one block per person per sync: done / planned / blocked / decisions. `docs/STATE.md` is the single current snapshot.

### When something goes wrong

| Situation | Do | Do not |
|---|---|---|
| Committed to `main` locally | `git switch -c <name>/<task>`, then `git switch main && git reset --hard origin/main` | push (GH013 refuses anyway) |
| Push rejected with GH013 | you pushed to `main`; branch and open a PR | look for a way around it |
| Merged PR broke `main` | Revert button on the PR, merge the revert, fix on a new branch | leave `main` red overnight |
| Committed a secret or personal path | tell the team, rotate the secret, `git rebase -i` to drop the commit, `--force-with-lease` | add a commit that deletes it (history keeps it) |
| Rebase conflict you do not understand | `git rebase --abort`, post the output in the group | pick one side everywhere |
| Lost work or bad reset | `git reflog`, `git reset --hard HEAD@{n}`; commits survive 90 days | re-type it |
| Detached HEAD | `git switch -c rescue` | close the terminal |

If a rule here disagrees with `docs/STATE.md` or the timeline, this section wins for process and the timeline wins for dates. Change either by PR.

## Documents

| File | What | Updated by |
|---|---|---|
| `docs/INTERFACE.md` | parameters, flit layout, route contract, link handshake, credits, front/back boundary, reset. On `main` as spec-v1 candidate; all four sign-off lines must name the same commit before `spec-v1` is tagged | Sachin |
| `docs/STATE.md` | single snapshot: phase, next gate, open bugs, per-item status, counters | Arnav |
| `docs/SYNC.md` | append-only weekly sync: done / planned / blocked / decisions per person | each member |
| `docs/BUG_LOG.md` | counted bugs (merged RTL) and pre-merge findings: id, found by, symptom, root cause, fix, catching check | fix PR author |
| `tb/sva/PLAN.md` | 52 named properties (`P01`-`P06` FIFO, then owner-prefixed `V`, `S`, `R`, `A`); group, owner, status; starvation bound N=48 | Aashish |
| `docs/wavedrom/` | head-flit pipeline and credit-stall timing, JSON and PNG | Sachin |

## Tools

| Tool | Where | Use |
|---|---|---|
| Verilator 5.020+ | everyone, WSL2 | lint, simulation, CI; `--assert` supports `##[0:N]` (T4 probe passed) |
| Icarus 12 | everyone | fallback simulation |
| GTKWave | everyone | `make waves` |
| Xcelium | college lab | `SIM=xcelium` cross-check of every unit test |
| JasperGold | college lab | Phase 2 formal on safety properties (lab logins requested Oct 2026; no proofs run yet) |

Liveness properties use `##[0:N]` in simulation and `s_eventually` under `` `ifdef FORMAL ``.

## References

Dally and Towles, Principles and Practices of Interconnection Networks, ch. 13, 16, 18, 19. Becker and Dally, Allocator Implementations for NoC Routers, SC 2009. Peh and Dally, A Delay Model and Speculative Architecture for Pipelined Routers, HPCA 2001.
