# STATE

Updated: 2026-10-21 (Sachin). Single snapshot; history lives in SYNC.md.

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

Gate 1 (due 2026-10-15) was not met. Status 2026-10-21:

| Gate 1 item | Status | Owner |
|---|---|---|
| `input_fifo` passing `tb_fifo` seeds, lint clean | Seeds 1-5 passed on `revu/input-fifo` (14 Oct). DECLFILENAME cleared by the `tb_fifo` rename; `lint` is warnings-fatal; `make check` lint + seeds 1-3 pass (#16, edce4cc). PM-001 fixed on `main` (below) | Revanth |
| FIFO SVA `P01` to `P06` bound and passing on `tb_fifo` | Done (#17): bound via `bind_all.sv`, pass seeds 1-3 in `make check` and CI. P06 kills the registered-credit mutant (PM-001) | Aashish |
| Driver and monitor on `flit_if`, `tb_fifo_link` harness | PR #18 under review: admission, consecutive-edge and pending-flit/credit reset checks, plus separate `tb_fifo_empty_read` safety probe; four (F,V,D) configurations (32,2,2), (64,3,4), (128,4,8), (32,1,4). Gate remains pending merge and review acceptance. xrun 26 Oct | Sachin |

Gate 1 remains pending until PR #18 review items 1-5 are verified and merged. PM-001 is fixed and P01-P06 run in CI on `main`. Xcelium qualification is pending 26 Oct.

## Fixed pre-merge finding
PM-001 (found 2026-10-14 by P06 with `bind_all`): `input_fifo.credit_out` was registered (`credit_out <= do_read`). INTERFACE.md s5.3 and s6 require it combinational (`credit_out = deq`); `input_port` adds the single register, so the registered version made credit return take 2 cycles instead of 1. `t_fifo` encoded the same registered timing and passed. Fixed before merge: `main` (PR #13, 1fd956e) has `assign credit_out = rst_n && do_read;` with same-cycle credit checks in the unit test. Recorded in docs/BUG_LOG.md under pre-merge findings, status DONE (not counted: the defect never reached `main`).

## Status
| Item | Status | Owner |
|---|---|---|
| Repo, branch protection, ruleset | done | Arnav |
| .gitattributes, .gitignore, CODEOWNERS | done | Arnav |
| README: roles, conventions, module list | done | Arnav |
| Makefile: lint, sim, check | done (PR #6). Per-test filelists, `WAVES=1` (passes `+dumpfile=`), `make waves` (loads `tb/tests/waves/<TEST>.gtkw`), `SIM=xcelium`, `lint-rtl`, `make check SEEDS="..."` (lint + sim of every `tb/tests/*.f`, `logs/summary.txt`). `regress`, `cov`, `formal` print "not yet: Phase 2". `check` and `+dumpfile=` merged in #16 | Sachin (review), Arnav |
| CI lint-and-sim | Valid on `main` since #16 (edce4cc): `make check SEEDS="1 2 3"` on every PR and push to `main`, job summary from `logs/summary.txt`, failing seeds re-run with waves, `logs/` uploaded 14 days. `actions/checkout@v6`, `actions/upload-artifact@v6` (Node 24) PR #18 proposes seeds 1-5 plus `make neg` (two expected failures). | Sachin, Arnav |
| INTERFACE.md (spec-v1) | Content on `main` (9874a12), header status DRAFT, untagged. Earlier sign-offs on four different commits (Arnav 432ab16, Aashish N/A, Sachin e578d2a, Revanth cc84961); all four must sign one commit. s7.2 (arbiter) merged in #16; sign the current `main` commit. Per s0, tag `spec-v1` only after `noc_pkg`, front and back RTL agree and the acceptance checks pass | Sachin (all four sign off) |
| `rtl/pkg/noc_pkg.sv` + `tb_noc_pkg` | On `main` (#14). Lint clean, sim passes, mutation-checked | Arnav |
| `rtl/back/rr_arbiter.sv` + `tb_rr_arbiter` | On `main` (#16, edce4cc), `make check` 16/16 PASS. N = 1, 2, 3, 4, 5, 8; exhaustive pointer x request sweep against an independent reference model, en-hold, fairness, starvation bound N-1, reset, 5000 random cycles. 5 of 5 non-equivalent injected mutants killed (no +1, ignore en, stuck pointer, mask off by one, no reset); the no-wrap mutant (`ptr_q <= grant_idx + 1` without the N-1 check) is equivalent at the ports, because `ptr = N` gives `mask = 0` and takes the same wrap path as `ptr = 0`. Only an internal property `ptr_q < N` distinguishes it. Contract in INTERFACE.md s7.2 | Arnav |
| `rtl/front/input_fifo.sv` + `tb_fifo` | On `main` (PR #13); PM-001 fixed; seeds 1-5 passed, 55 checks each (14 Oct). `tb_fifo` rename in #16; lint clean and seeds 1-3 pass under `make check` (CI run #125) | Revanth |
| `tb/sva/fifo_sva.sv` P01-P06 + `bind_all.sv` | Bound in `tb/tests/tb_fifo.f`; Verilator builds with `--assert`, so `make check` and CI run them (#17). P01-P06 pass, seeds 1-3. SVA-only mutation run (TB checks non-fatal, 9 mutants): P06 kills registered `credit_out` (PM-001); P04 no-increment; P05 no-decrement; P01/P02 `full` at DEPTH-1. Survive: simultaneous read/write count change (no bound hold property; `input_fifo.count_holds_correctly` exists inline), `rd_ptr`/`wr_ptr` stuck (data path, scoreboard), and two mutants equivalent under P01/P02. Mutant runs: `make build TEST=tb_fifo` then `obj_tb_fifo/sim +sva_only` (TB checks log, SVA decides). `input_fifo.sv` also holds six inline properties, including `count_holds_correctly`; move them into bind-only `fifo_sva` in a separate PR. `tb_fifo.sv` still holds three inline assertions (`no_overflow`, `no_underflow`, `count_in_range` on `dut.do_write`/`dut.do_read`), live since `--assert`; move them into `fifo_sva` as named properties or drop them | Aashish |
| Link environment | PR #18 under review: `flit_if`, `flit_pkt`, driver, framing/credit monitor, transaction-only `tb_flit_if`, real-FIFO `tb_fifo_link` with bound P01-P06, and `tb_fifo_empty_read` (deliberate illegal-request safety test without the P01/P02 bind). Clocking blocks remain opt-in (`FLIT_IF_CLOCKING`); Verilator 5.020 rejects `@(link.cb)`. Qualify on Xcelium 26 Oct; delete optional blocks if qualification fails | Sachin |
| tb/sva/PLAN.md | v2, 52 properties (P01-P06 + V07-V15 Aashish, S01-S08 Sachin, R01-R14 Revanth, A01-A15 Arnav), G1 (#17). IDs `P01`-`P06` (FIFO, INTERFACE.md s6) then owner-prefixed `V07`-`V15`, `S01`-`S08`, `R01`-`R14`, `A01`-`A15`; signal names from INTERFACE.md and `rr_arbiter` | Aashish |
| Verilator T4 probe (`##[0:N]`) | done (passed) | Aashish |
| Simulator and formal-tool decision | Xcelium and Jasper Gold | Aashish, Arnav |
| Toolchain versions in SYNC.md | 3/4 (Arnav, Sachin, Aashish) | all |

Counters: RTL modules 2/10 on `main` (`input_fifo`, `rr_arbiter`; + `noc_pkg`). Tests on `main` 4 (`tb_smoke`, `tb_noc_pkg`, `tb_fifo`, `tb_rr_arbiter`); PR #18 proposes three more: transaction-only `tb_flit_if`, `tb_fifo_link` and `tb_fifo_empty_read`. SVA 6/52 on `main`, run in CI (P01-P06); 40 is the Phase 2 floor. Coverage n/a. Bugs logged 0. Paper draft none.

## Blockers
1. Gate 1: PR #18 review fixes require verification, approval and merge before closure (Sachin, 24 Oct).
2. Semester 5 mid-sem 2 date and all semester 6 dates unknown; mid-sem 2 on or before 2 Nov would pull the blackout start forward.
3. JasperGold seat confirmation on the lab machine; Xcelium and JasperGold logins requested 26 to 28 Oct, confirm by 5 Jan.

## Team
| Name | Code | GitHub | Owns |
|---|---|---|---|
| Revanth | R1 | @revantharigela | rtl/front: input_fifo, route_unit, input_port, vc_allocator |
| Arnav | R2 | @zackkracky | rtl/back, rtl/pkg: rr_arbiter, switch_allocator, crossbar, output_unit, router_top; coordinator |
| Sachin | V1 | @sachin19-02 | tb/env, tb/tests, Makefile, CI |
| Aashish | V2 | @coolboy965 | tb/sva, tb/cov, formal, scoreboard, bug log; docs editor |

## Review follow-ups and 26 Oct qualification

- On the lab machine run `make sim TEST=tb_fifo_link SEED=1 SIM=xcelium`, `make sim TEST=tb_flit_if SEED=1 SIM=xcelium` and `make sim TEST=tb_fifo_empty_read SEED=1 SIM=xcelium`; the Makefile already supplies `-timescale 1ns/1ps` to xrun.
- Probe `+define+FLIT_IF_CLOCKING` with `@(link.cb)`; record the tool version and results in SYNC. Delete the optional blocks if qualification fails; spec-v1 acceptance remains pending.
- Seed N is simulator-specific: Verilator and Xcelium do not generate identical traffic from the same seed number.
- Separate PR: move six inline FIFO properties and three inline `tb_fifo` assertions to bind-only checkers, give the hold property a P-number, and replace the RTL initial DEPTH check with a generate-time error. Do not include that RTL cleanup in #18.
- After #18 merges, update the harness/Gate 1 status and test counters. `input_fifo` is PR #13 (merge `1fd956e`); #11 is the linked issue.
