# STATE

Updated: 2026-10-20 (Arnav). Single snapshot; history lives in SYNC.md.

## Phase
Phase 1a: Block RTL and Unit Verification (1 Oct to 2 Nov 2026). Exam blackout 3 Nov to 9 Dec 2026 (sem-5 end-sem 17 Nov to 9 Dec), graded load decided 19 Oct: Arnav <= 8 h/week, Sachin <= 5, Revanth and Aashish <= 1 reactive only; no session within 48 h before a paper; kill-switch on a bad paper. No new work, no new deadlines inside the window. Phase 1b starts 10 Dec; Phase 1 exit 31 Dec.

## Next deadlines
| Date | Item | Owner |
|---|---|---|
| 2026-10-24 | Driver, monitor and `tb_fifo` harness (overdue from 15 Oct) | Sachin |
| 2026-10-26 | First `xrun` check of every merged test on the lab machine | Arnav |
| 2026-10-31 | Phase 1a close-out: `switch_allocator` and `router_top` skeleton; `input_port`, `vc_allocator` | Arnav, Revanth |
| 2026-11-01 / 02 | `crossbar` / `output_unit`; scoreboard v1 | Arnav, Aashish |
| 2026-12-10 | Phase 1b starts | all |
| 2026-12-31 | Phase 1 exit | all |

Gate 1 (due 2026-10-15) was not met. Status as last reported 2026-10-14:

| Gate 1 item | Status | Owner |
|---|---|---|
| `input_fifo` passing `t_fifo` seeds 1 to 5, lint clean | Seeds 1-5 pass on `revu/input-fifo`. Not lint clean: DECLFILENAME (module `t_fifo` in `tb_fifo.sv`), hidden by `-Wno-fatal` on `lint`. PM-001 open (below) | Revanth |
| FIFO SVA `P01` to `P06` bound and passing on `t_fifo` | Written on `aashish/sva-fifo`. Bound to `input_fifo`: P01-P05 pass, P06 fails on every seed (PM-001) | Aashish |
| Driver and monitor on `flit_if`, `t_fifo` harness | `flit_if.sv` and link probe on `sachin/phase1a-fifo-testbench`. Driver, monitor and `t_fifo` harness not pushed | Sachin |

Gate 1 is still not met: PM-001 is fixed on `main` (below), but the harness is not pushed and P01-P06 are not yet in CI (PR #17).

## Fixed pre-merge finding
PM-001 (found 2026-10-14 by P06 with `bind_all`): `input_fifo.credit_out` is registered (`credit_out <= do_read`). INTERFACE.md s5.3 and s6 require it combinational (`credit_out = deq`); `input_port` adds the single register. As written, credit return takes 2 cycles instead of 1. `t_fifo` encodes the same registered timing, so it passes; with the RTL corrected, `t_fifo` fails at line 97. Fix needs RTL and testbench (Revanth). Recorded in docs/BUG_LOG.md under pre-merge findings (not counted: RTL not on main). Fixed before merge: `main` (#11, 1fd956e) has `assign credit_out = rst_n && do_read;`. BUG_LOG row needs its fix column filled (Revanth).

## Status
| Item | Status | Owner |
|---|---|---|
| Repo, branch protection, ruleset | done | Arnav |
| .gitattributes, .gitignore, CODEOWNERS | done | Arnav |
| README: roles, conventions, module list | done | Arnav |
| Makefile: lint, sim, check | done (PR #6). Per-test filelists, `WAVES=1` (passes `+dumpfile=`), `make waves` (loads `tb/tests/waves/<TEST>.gtkw`), `SIM=xcelium`, `lint-rtl`, `make check SEEDS="..."` (lint + sim of every `tb/tests/*.f`, `logs/summary.txt`). `regress`, `cov`, `formal` print "not yet: Phase 2". `check` and `+dumpfile=` in PR #16 | Sachin (review), Arnav |
| CI lint-and-sim | `main` has the old `ci.yml` (duplicate `run:` key, invalid workflow; README badge red). PR #16 fixes it: `make check SEEDS="1 2 3"`, job summary from `logs/summary.txt`, failing seeds re-run with waves, `logs/` uploaded 14 days. Badge turns green after #16 merges | Sachin, Arnav |
| INTERFACE.md spec-v1 (PR #11) | Not merged. Sign-offs recorded on four different commits (Arnav 432ab16, Aashish N/A, Sachin e578d2a, Revanth cc84961); all four must re-sign the final commit before merge | Sachin (all four sign off) |
| `rtl/pkg/noc_pkg.sv` + `tb_noc_pkg` | Lint clean, sim passes, mutation-checked. PR from `arnav/rtl-back-initial` | Arnav |
| `rtl/back/rr_arbiter.sv` + `tb_rr_arbiter` | PR #16, `make check` 16/16 PASS. N = 1, 2, 3, 4, 5, 8; exhaustive pointer x request sweep against an independent reference model, en-hold, fairness, starvation bound N-1, reset, 5000 random cycles. 5 of 5 non-equivalent injected mutants killed (no +1, ignore en, stuck pointer, mask off by one, no reset); the no-wrap mutant (`ptr_q <= grant_idx + 1` without the N-1 check) is equivalent at the ports, because `ptr = N` gives `mask = 0` and takes the same wrap path as `ptr = 0`. Only an internal property `ptr_q < N` distinguishes it. Contract in INTERFACE.md s7.2 | Arnav |
| `rtl/front/input_fifo.sv` | On `main` (#11); PM-001 fixed; `tb_fifo` rename in PR #16 | Revanth |
| `tb/sva/fifo_sva.sv` P01-P06 + `bind_all.sv` | PR #17 (`aashish/sva-fifo`): based on pre-#14 main, conflicts in Makefile/STATE/SYNC; rebase after #16 merges, add a `.f` and `--assert` so CI runs them. Also carries PLAN.md v2 (52 properties, G1) | Aashish |
| `tb/env/flit_if.sv` + `t_flit_if` | On `sachin/phase1a-fifo-testbench` | Sachin |
| tb/sva/PLAN.md v1 (40 properties) | merged (#7) | Aashish |
| Verilator T4 probe (`##[0:N]`) | done (passed) | Aashish |
| Simulator and formal-tool decision | Xcelium and Jasper Gold | Aashish, Arnav |
| Toolchain versions in SYNC.md | 3/4 (Arnav, Sachin, Aashish) | all |
| input_fifo RTL + t_fifo unit verification | done (lint clean; seeds 1–5 passed, 55 checks each) | Revanth |

Counters: RTL modules 1/10 on main (`rr_arbiter` unit-tested on branch). Tests on main 2 (`t_smoke`, `tb_noc_pkg`); on branch 4 (`tb_smoke`, `tb_noc_pkg`, `tb_fifo`, `tb_rr_arbiter`). SVA 0/40 (40 planned in PLAN.md). Coverage n/a. Bugs logged 0. Paper draft none.

## Blockers
1. Gate 1: harness (Sachin, 24 Oct) and P01-P06 in CI (Aashish, PR #17).
2. Semester 5 mid-sem 2 date and all semester 6 dates unknown; mid-sem 2 on or before 2 Nov would pull the blackout start forward.
3. JasperGold seat confirmation on the lab machine; Xcelium and JasperGold logins requested 26 to 28 Oct, confirm by 5 Jan.

## Team
| Name | Code | GitHub | Owns |
|---|---|---|---|
| Revanth | R1 | @revantharigela | rtl/front: input_fifo, route_unit, input_port, vc_allocator |
| Arnav | R2 | @zackkracky | rtl/back, rtl/pkg: rr_arbiter, switch_allocator, crossbar, output_unit, router_top; coordinator |
| Sachin | V1 | @sachin19-02 | tb/env, tb/tests, Makefile, CI |
| Aashish | V2 | @coolboy965 | tb/sva, tb/cov, formal, scoreboard, bug log; docs editor |
