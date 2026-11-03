# STATE

Updated: 2026-11-03 (Arnav). Single snapshot; history lives in SYNC.md. Repo facts refreshed to `main` at `4f8a9b2` (#21 TP-001 fix and #22 bug-log format merged) plus the open PRs #28-#31.

## Phase
Phase 1a (1 Oct to 2 Nov 2026) **did not close on 2 Nov**: `route_unit`, `input_port`, `vc_allocator`, scoreboard v1 and the spec-v1 sign-offs slipped. Its remaining items are absorbed into Phase 1b. Exam blackout 3 Nov to 9 Dec 2026 (sem-5 end-sem 17 Nov to 9 Dec): Arnav <= 8 h/week, Sachin <= 5, Revanth and Aashish <= 1 reactive only; no session within 48 h before a paper; kill-switch on a bad paper. Nothing is scheduled inside the window. Phase 1b starts 10 Dec; Phase 1 exit stays 31 Dec.

## Next deadlines
| Date | Item | Owner |
|---|---|---|
| 2026-12-10 | Phase 1b starts. First lab session: `xrun` on every test including `tb_crossbar` and `tb_output_unit`, and `jg -batch formal/fifo.tcl` on the merged TP-001 fix | all; Arnav, Aashish |
| 2026-12-11 | Link-level TB on `input_port` once it exists | Sachin |
| 2026-12-12 | `route_unit` (was 24 Oct) | Revanth |
| 2026-12-13 | INTERFACE.md spec-v1: all four sign-offs on one current-`main` commit (was 30 Oct) | all |
| 2026-12-17 | `input_port`, `vc_allocator` (were 31 Oct) | Revanth |
| 2026-12-19 | Scoreboard v1 (was 2 Nov) | Aashish |
| 2026-12-31 | Phase 1 exit: single packet on all 20 port pairs passes directed tests; contention tests pass with VCs and credits | all |

If Phase 1b cannot reach the 31 Dec exit from a 10 Dec start, scope is cut from the bottom: TCAM, then west-first, then FPGA parameter points, then mesh size. Verification results are never cut.

## Open pull requests
| PR | Branch | Content | Base | State |
|---|---|---|---|---|
| #29 | `arnav/crossbar` | `crossbar` + `tb_crossbar` | `main` | ready for review |
| #30 | `arnav/output-unit` | `output_unit` + `tb_output_unit` | `main` | ready for review |
| #31 | `arnav/router-top-skel` | `router_top` skeleton, lint-only | #29 + #30 | Draft until both merge, then rebase onto `main` |
| #23 | `arnav/router-top` | superseded by #29-#31; does not elaborate | — | close and delete the branch |

#29 and #30 each touch one adjacent row of the README Modules table, so whichever merges second rebases with a one-line conflict.

## Gate 1
Met late on 2026-10-21 by PR #18 (`7df0cca`): `input_fifo` passing `tb_fifo`, P01-P06 bound and passing, driver/monitor and `tb_fifo_link` on `main`.

## Status
| Item | Status | Owner |
|---|---|---|
| Repo, branch protection, ruleset | done | Arnav |
| .gitattributes, .gitignore, CODEOWNERS | done | Arnav |
| README: roles, conventions, module list, results | done | Arnav |
| Makefile: lint, sim, check, neg, waves, lint-rtl | done. `lint-rtl` resolves submodules with `-y` from the docs PR of 3 Nov; before that it failed on any file that instantiates another | Sachin (review), Arnav |
| CI lint-and-sim | `make check SEEDS="1 2 3 4 5"` then `make neg` on every PR and push to `main`; Verilator 5.020 on `ubuntu-24.04`. Test list is discovered from `tb/tests/*.f`, so new tests need no CI edit | Sachin, Arnav |
| INTERFACE.md (spec-v1) | DRAFT, untagged. No set of four sign-offs on one commit. s0 implementation table predates #20 and lists `switch_allocator` as unwritten | Sachin (all four sign off) |
| `rtl/pkg/noc_pkg.sv` + `tb_noc_pkg` | on `main` (#14) | Arnav |
| `rtl/front/input_fifo.sv` + `tb_fifo` | on `main` (#13); PM-001 fixed before merge | Revanth |
| `rtl/back/rr_arbiter.sv` + `tb_rr_arbiter` | on `main` (#16); M-001 5/5 non-equivalent mutants; D-003 max wait N-1 at N = 1,2,3,4,5,8 | Arnav |
| `rtl/back/switch_allocator.sv` + `tb_switch_allocator` | on `main` (#20), Xcelium-qualified 28 Oct; M-002 7/7; D-001 and D-002 re-verified 3 Nov on `08c0fdf` | Arnav |
| `rtl/back/crossbar.sv` + `tb_crossbar` | PR #29. s7 names (`xbar_sel`, `xb_flit`, `xb_vc`, `issue_flit`, `issue_vc`); 4 parameter points, 2130 checks each; 5/5 mutants; not yet run under `xrun` | Arnav |
| `rtl/back/output_unit.sv` + `tb_output_unit` | PR #30. Credits only (T9); exports `ocredit_avail` and `ocredit_count` (T11); exact count vs model every cycle at 4 parameter points; 7/7 mutants; not yet run under `xrun` | Arnav |
| `rtl/back/router_top.sv` | PR #31. s4 flat ports, back half wired, `input_port` x5 stubbed; lint-only at 4 parameter points | Arnav |
| `rtl/front/route_unit.sv`, `input_port.sv`, `vc_allocator.sv` | not started on any branch | Revanth |
| `tb/sva/fifo_sva.sv` P01-P06 + `bind_all.sv` | on `main` (#17), run in CI on `tb_fifo` and `tb_fifo_link`. Six inline FIFO properties and three inline `tb_fifo` assertions still to move into bind-only checkers | Aashish |
| Link environment | on `main` (#18). Clocking blocks qualified on Xcelium 28 Oct (Q-002) and stay | Sachin |
| `tb/sva/PLAN.md` v2 | 52 properties, 40 passing is the Phase 2 floor. Open review items: S02 contradicts INTERFACE.md s5.2/s9/s10; R09 cites N = 48 where D-001 measured `N_SA` | Aashish |
| Scoreboard v1 | not started | Aashish |
| Formal | `formal/fifo.tcl` on `main`; TP-001 fix merged (#21); no `analyze` re-run yet, so no proof | Aashish, Arnav |
| Toolchain versions in SYNC.md | 4/4 (22 Sep): Arnav 5.032, Revanth 5.024, Sachin 5.020, Aashish 5.024. Only Sachin matches CI | all |

Counters: RTL modules on `main` 3 of 10 plus `noc_pkg` (`input_fifo`, `rr_arbiter`, `switch_allocator`); 6 of 10 with #29-#31 (`router_top` as a skeleton). Tests on `main` 8; 10 with #29-#30. SVA 6/52 on `main`, run in CI. Coverage n/a. Counted bugs (`B-nnn`) 0, floor 2 by 28 Feb. Records in `docs/bugs/`: PM-001 CLOSED, PM-002 FIXED pending verifier sign-off, TP-001 FIXED pending a clean `analyze`; none counts. Paper draft none; PAPER_PLAN v1.0 and VENUES v2 frozen.

## Lab qualification, 28 Oct 2026 (xrun 22.09-s003, Jasper 2022.09p001, `main` @ `08c0fdf`)
- Xcelium: all 8 tests, lint + seeds 1-5, 48/48 PASS (Q-001). `tb_switch_allocator` needed no change.
- `FLIT_IF_CLOCKING` probe: PASS on `tb_fifo_link`, all four (F,V,D) configs (Q-002). The optional clocking blocks stay.
- Seeds are simulator-specific: regressions quote `SIM=` with the seed.
- JasperGold: `analyze` of `formal/fifo.tcl` FAILED with VERI-1906 (Q-003, TP-001). Fix merged in #21 (`907433f`); `make check` 32/32 and `make neg` 2/2 re-verified on `907433f` on 3 Nov (Q-004). No proof has run.

Nothing written since 28 Oct has been through `xrun`. Per the 30 Oct entry condition, `crossbar`, `output_unit` and `router_top` are Verilator-verified only until the next lab session.

## Blockers
1. `rtl/front/route_unit.sv`, ten days past its 24 Oct date and on no branch. `input_port` and `vc_allocator` depend on it, and so does every router-level test: `router_top` cannot become functional before it lands (Revanth).
2. Semester 5 mid-sem 2 date and all semester 6 dates unknown. Semester 6 end-sem must finish before 17 May 2027 or the internship start shifts.
3. INTERFACE.md spec-v1 has no set of four sign-offs on one commit.
4. No formal proof exists until `analyze` is re-run on the merged TP-001 fix.

## Team
| Name | Code | GitHub | Owns |
|---|---|---|---|
| Revanth | R1 | @revantharigela | rtl/front: input_fifo, route_unit, input_port, vc_allocator |
| Arnav | R2 | @zackkracky | rtl/back, rtl/pkg: rr_arbiter, switch_allocator, crossbar, output_unit, router_top; coordinator |
| Sachin | V1 | @sachin19-02 | tb/env, tb/tests, Makefile, CI |
| Aashish | V2 | @coolboy965 | tb/sva, tb/cov, formal, scoreboard, bug log; docs editor |
