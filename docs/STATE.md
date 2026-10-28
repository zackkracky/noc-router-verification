# STATE

Updated: 2026-10-28 (Arnav). Single snapshot; history lives in SYNC.md. Repo facts refreshed to `main` at `08c0fdf` (#20 merged); 28 Oct lab qualification results folded in.

## Phase
Phase 1a: Block RTL and Unit Verification (1 Oct to 2 Nov 2026). Exam blackout 3 Nov to 9 Dec 2026 (sem-5 end-sem 17 Nov to 9 Dec), graded load decided 19 Oct: Arnav <= 8 h/week, Sachin <= 5, Revanth and Aashish <= 1 reactive only; no session within 48 h before a paper; kill-switch on a bad paper. No new work, no new deadlines inside the window. Phase 1b starts 10 Dec; Phase 1 exit 31 Dec.

## Next deadlines
| Date | Item | Owner |
|---|---|---|
| 2026-10-24 | `route_unit` — **OVERDUE, not started on any branch** | Revanth |
| 2026-10-26 | First `xrun` check of every merged test on the lab machine; `FLIT_IF_CLOCKING` probe — **DONE 28 Oct** (see Lab qualification below); collect sem-5 mid-sem 2 and all sem-6 dates — **still open** | Arnav |
| 2026-10-29 | TP-001 fix PR (`input wire logic`, 5 files) + `formal/fifo.tcl` + doc refresh; re-run `formal/fifo.tcl` on the lab machine after merge | Arnav |
| 2026-10-30 | INTERFACE.md spec-v1: all four sign-offs on one current-`main` commit | all |
| 2026-10-31 | Phase 1a close-out: `router_top` skeleton; `input_port`, `vc_allocator` | Arnav, Revanth |
| 2026-11-01 / 02 | `crossbar` / `output_unit`; scoreboard v1 | Arnav, Aashish |
| 2026-11-02 | Five applications submitted (Max Planck, ETH SSRF, Summer@EPFL, SRFP, Arm India) | Arnav |
| 2026-12-10 | Phase 1b starts | all |
| 2026-12-31 | Phase 1 exit | all |

Gate 1 (due 2026-10-15) was met late on 2026-10-21 by PR #18 (`7df0cca`).

| Gate 1 item | Status | Owner |
|---|---|---|
| `input_fifo` passing `tb_fifo` seeds, lint clean | Done. Seeds 1-5 pass under `make check`; lint warnings-fatal. PM-001 fixed on `main` (below) | Revanth |
| FIFO SVA `P01` to `P06` bound and passing on `tb_fifo` | Done (#17): bound via `bind_all.sv`, run in CI. P06 kills the registered-credit mutant (PM-001) | Aashish |
| Driver and monitor on `flit_if`, `tb_fifo_link` harness | Done (#18, `7df0cca`): `flit_if`, `flit_pkt`, credit-aware driver, framing/credit monitor, `tb_fifo_link` with bound P01-P06, plus `tb_flit_if` and `tb_fifo_empty_read`. CI moved to seeds 1-5 and `make neg` | Sachin |

Gate 1 is closed. Xcelium qualification of all seven tests remains pending the 26 Oct lab session; no spec-v1 freeze is claimed.

## Fixed pre-merge finding
PM-001 (found 2026-10-14 by P06 with `bind_all`): `input_fifo.credit_out` was registered (`credit_out <= do_read`). INTERFACE.md s5.3 and s6 require it combinational (`credit_out = deq`); `input_port` adds the single register, so the registered version made credit return take 2 cycles instead of 1. `t_fifo` encoded the same registered timing and passed. Fixed before merge: `main` (PR #13, 1fd956e) has `assign credit_out = rst_n && do_read;` with same-cycle credit checks in the unit test. Recorded in docs/BUG_LOG.md under pre-merge findings, status DONE (not counted: the defect never reached `main`).

## Status
| Item | Status | Owner |
|---|---|---|
| Repo, branch protection, ruleset | done | Arnav |
| .gitattributes, .gitignore, CODEOWNERS | done | Arnav |
| README: roles, conventions, module list | done | Arnav |
| Makefile: lint, sim, check | done (PR #6). Per-test filelists, `WAVES=1` (passes `+dumpfile=`), `make waves` (loads `tb/tests/waves/<TEST>.gtkw`), `SIM=xcelium`, `lint-rtl`, `make check SEEDS="..."` (lint + sim of every `tb/tests/*.f`, `logs/summary.txt`). `regress`, `cov`, `formal` print "not yet: Phase 2". `check` and `+dumpfile=` merged in #16 | Sachin (review), Arnav |
| CI lint-and-sim | Valid on `main` since #16; seeds widened in #18 (`7df0cca`): `make check SEEDS="1 2 3 4 5"` plus `make neg` on every PR and push to `main`, both summaries in the job summary, failing seeds re-run with waves, `logs/` uploaded 14 days. `actions/checkout@v6`, `actions/upload-artifact@v6` (Node 24) | Sachin, Arnav |
| INTERFACE.md (spec-v1) | Content on `main`, refreshed to `7df0cca` in #19 (`75d83f2`): external citations removed, s0 impl-status table added, s6 P04/P05 IDs corrected. Header status DRAFT, untagged. Earlier sign-offs on four different commits (Arnav 432ab16, Aashish N/A, Sachin e578d2a, Revanth cc84961); all four must sign one commit. s7.2 (arbiter) merged in #16; sign the current `main` commit. Per s0, tag `spec-v1` only after `noc_pkg`, front and back RTL agree and the acceptance checks pass | Sachin (all four sign off) |
| `rtl/pkg/noc_pkg.sv` + `tb_noc_pkg` | On `main` (#14). Lint clean, sim passes, mutation-checked | Arnav |
| `rtl/back/rr_arbiter.sv` + `tb_rr_arbiter` | On `main` (#16, edce4cc), `make check` 16/16 PASS. N = 1, 2, 3, 4, 5, 8; exhaustive pointer x request sweep against an independent reference model, en-hold, fairness, starvation bound N-1, reset, 5000 random cycles. 5 of 5 non-equivalent injected mutants killed (no +1, ignore en, stuck pointer, mask off by one, no reset); the no-wrap mutant (`ptr_q <= grant_idx + 1` without the N-1 check) is equivalent at the ports, because `ptr = N` gives `mask = 0` and takes the same wrap path as `ptr = 0`. Only an internal property `ptr_q < N` distinguishes it. Contract in INTERFACE.md s7.2 | Arnav |
| `rtl/front/input_fifo.sv` + `tb_fifo` | On `main` (PR #13); PM-001 fixed; seeds 1-5 passed, 55 checks each (14 Oct). `tb_fifo` rename in #16; lint clean and seeds 1-3 pass under `make check` (CI run #125) | Revanth |
| `tb/sva/fifo_sva.sv` P01-P06 + `bind_all.sv` | Bound in `tb/tests/tb_fifo.f`; Verilator builds with `--assert`, so `make check` and CI run them (#17). P01-P06 pass, seeds 1-3. SVA-only mutation run (TB checks non-fatal, 9 mutants): P06 kills registered `credit_out` (PM-001); P04 no-increment; P05 no-decrement; P01/P02 `full` at DEPTH-1. Survive: simultaneous read/write count change (no bound hold property; `input_fifo.count_holds_correctly` exists inline), `rd_ptr`/`wr_ptr` stuck (data path, scoreboard), and two mutants equivalent under P01/P02. Mutant runs: `make build TEST=tb_fifo` then `obj_tb_fifo/sim +sva_only` (TB checks log, SVA decides). `input_fifo.sv` also holds six inline properties, including `count_holds_correctly`; move them into bind-only `fifo_sva` in a separate PR. `tb_fifo.sv` still holds three inline assertions (`no_overflow`, `no_underflow`, `count_in_range` on `dut.do_write`/`dut.do_read`), live since `--assert`; move them into `fifo_sva` as named properties or drop them | Aashish |
| Link environment | On `main` (#18, `7df0cca`): `flit_if`, `flit_pkt`, credit-aware driver, framing/credit monitor, transaction-only `tb_flit_if`, real-FIFO `tb_fifo_link` with bound P01-P06, and `tb_fifo_empty_read` (deliberate illegal-request safety test without the P01/P02 bind, per INTERFACE s6). Clocking blocks remain opt-in (`FLIT_IF_CLOCKING`); Verilator 5.020 rejects `@(link.cb)`. Qualify on Xcelium 26 Oct; delete the optional blocks if qualification fails | Sachin |
| `rtl/back/switch_allocator.sv` + `tb_switch_allocator` | **On `main` (#20, `08c0fdf`).** Xcelium-qualified 28 Oct (`$countones` and recursive `mm_aug` fine under xrun 22.09). Input-first separable allocation from two `rr_arbiter` instances: stage 1 one `#(.N(NUM_VCS))` per input with `en = input_won[p]` (final grant only, s7.2 T7), stage 2 one `#(.N(NUM_PORTS))` per output with `en = issue[o]`. 92 RTL lines, 467 TB lines. TB runs NUM_VCS = 1-4 in one simulation, each with an independent reference model plus model-free s7 contract checks; eight phases: reset, exhaustive (input,VC,output) sweep, stage-2-loss pointer hold, stage-1 commitment characterisation, fairness, starvation bound, out-of-range route, 20000-cycle random with random resets (phases 3 and 3b skipped at NUM_VCS = 1). `make check SEEDS="1 2 3 4 5"` 30/30 PASS on the branch alone and 48/48 PASS with `make neg` 2/2 on top of `75d83f2` (Verilator 5.020, the CI version; 5.032 and Xcelium not run). Measured per NUM_VCS 1/2/3/4 at seed 1: starvation max wait 4/9/13/14 against `N_SA = NUM_VCS*NUM_PORTS-1` = 4/9/14/19; efficiency (grants / maximum bipartite matching) 1.0000/0.9136/0.8345/0.7795 | Arnav |
| tb/sva/PLAN.md | v2, 52 properties (P01-P06 + V07-V15 Aashish, S01-S08 Sachin, R01-R14 Revanth, A01-A15 Arnav), G1 (#17). IDs `P01`-`P06` (FIFO, INTERFACE.md s6) then owner-prefixed `V07`-`V15`, `S01`-`S08`, `R01`-`R14`, `A01`-`A15`; signal names from INTERFACE.md and `rr_arbiter` | Aashish |
| Verilator T4 probe (`##[0:N]`) | done (passed) | Aashish |
| Simulator and formal-tool decision | Xcelium and Jasper Gold | Aashish, Arnav |
| Toolchain versions in SYNC.md | 3/4 (Arnav, Sachin, Aashish) | all |

Counters: RTL modules 3/10 on `main` (`input_fifo`, `rr_arbiter`, `switch_allocator`; + `noc_pkg`). Tests on `main` 8 (`tb_smoke`, `tb_noc_pkg`, `tb_fifo`, `tb_rr_arbiter`, `tb_flit_if`, `tb_fifo_link`, `tb_fifo_empty_read`, `tb_switch_allocator`). SVA 6/52 on `main`, run in CI (P01-P06); plan v2 finalised; 40 is the Phase 2 floor. Coverage n/a. Bugs logged 0 counted (TP-001 tool-portability 28 Oct JasperGold, kept in its own BUG_LOG section, not counted; PM-001 pre-merge, not counted). Paper draft none; PAPER_PLAN v1.0 and VENUES v2 frozen.

## Lab qualification, 28 Oct 2026 (xrun 22.09-s003, Jasper 2022.09p001, `main` @ `08c0fdf`)
- Xcelium: all 8 tests, lint + seeds 1-5, 48/48 PASS (`logs/summary.txt` from the lab run). `tb_switch_allocator` needed no change.
- `FLIT_IF_CLOCKING` probe with `@(link.cb)`: PASS on `tb_fifo_link` (all four (F,V,D) configs). The optional clocking blocks stay.
- Seed caveat confirmed: Verilator and Xcelium traffic differ at the same seed number; regressions quote `SIM=` with the seed.
- JasperGold: license and `jasper_fao` checkout work. First `analyze` of `formal/fifo.tcl` FAILED with VERI-1906 on `input_fifo` input ports — TP-001 in BUG_LOG.md (tool portability, not counted). Root cause: `input logic` under `` `default_nettype none `` leaves the port kind to the (absent) default net type; xrun had warned the same lines as NODNTW. Fix: `input wire logic` on all 25 input ports across `input_fifo` (5), `rr_arbiter` (4), `switch_allocator` (4), `fifo_sva` (9), `flit_driver` (3); `make check` 32/32 + `make neg` 2/2 green on Verilator 5.020 after the change. No proof has run yet; re-run `fifo.tcl` after the fix merges.

## Blockers
1. `rtl/front/route_unit.sv` was due 24 Oct and is still not on `main` as of 28 Oct — the fallback is now ACTIVE: `router_top` (31 Oct) lands with the front half stubbed; `input_port` and `vc_allocator` (31 Oct) are at risk (Revanth).
2. Semester 5 mid-sem 2 date and all semester 6 dates unknown; mid-sem 2 on or before 2 Nov pulls the blackout start forward and collapses the 26 Oct - 2 Nov week to document collection.
3. ~~JasperGold seat confirmation~~ RESOLVED 28 Oct: Xcelium and JasperGold both licensed and run under the student login. New: TP-001 fix must merge before any proof can run.
4. INTERFACE.md spec-v1 still has no set of four sign-offs on one commit; target 30 Oct.

## Team
| Name | Code | GitHub | Owns |
|---|---|---|---|
| Revanth | R1 | @revantharigela | rtl/front: input_fifo, route_unit, input_port, vc_allocator |
| Arnav | R2 | @zackkracky | rtl/back, rtl/pkg: rr_arbiter, switch_allocator, crossbar, output_unit, router_top; coordinator |
| Sachin | V1 | @sachin19-02 | tb/env, tb/tests, Makefile, CI |
| Aashish | V2 | @coolboy965 | tb/sva, tb/cov, formal, scoreboard, bug log; docs editor |

## Review follow-ups and 26 Oct qualification

- On the lab machine run `make sim TEST=<test> SEED=1 SIM=xcelium` for all seven merged tests plus `tb_switch_allocator`; the Makefile already supplies `-timescale 1ns/1ps` to xrun. `tb_switch_allocator` is the first test to use `$countones` and a recursive function (`mm_aug`), so it is the likeliest to need a change under `xrun`.
- Probe `+define+FLIT_IF_CLOCKING` with `@(link.cb)`; record the tool version and results in SYNC. Delete the optional blocks if qualification fails; spec-v1 acceptance remains pending.
- Seed N is simulator-specific: Verilator and Xcelium do not generate identical traffic from the same seed number.
- Separate PR: move six inline FIFO properties and three inline `tb_fifo` assertions to bind-only checkers, give the hold property a P-number, and replace the RTL initial DEPTH check with a generate-time error. That RTL cleanup was kept out of #18.
- `switch_allocator` open items for the property plan: the starvation bound `N_SA = NUM_VCS*NUM_PORTS-1` is measured, not proven, and tight only at NUM_VCS <= 2, so the A-series needs the bounded `##[0:N_SA]` form with `s_eventually` left to formal; out-of-range route codes need an assume in `formal/assume.sv` rather than an RTL guard; the stage-1 commitment loss is characterised in TB phase 3b and is a documented property, with a masked second iteration as a Phase 3 candidate.