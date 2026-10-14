# STATE

Updated: 2026-10-14 (Revanth). Single snapshot; history lives in SYNC.md.

## Phase
Phase 1a: Block RTL and Unit Verification (1 Oct to 3 Nov 2026).

## Next deadline
2026-10-15, Phase 1a Gate 1. Status as of 2026-10-14:

| Gate 1 item | Status | Owner |
|---|---|---|
| `input_fifo` passing `t_fifo` seeds 1 to 5, lint clean | Seeds 1-5 pass on `revu/input-fifo`. Not lint clean: DECLFILENAME (module `t_fifo` in `tb_fifo.sv`), hidden by `-Wno-fatal` on `lint`. PM-001 open (below) | Revanth |
| FIFO SVA `P01` to `P06` bound and passing on `t_fifo` | Written on `aashish/sva-fifo`. Bound to `input_fifo`: P01-P05 pass, P06 fails on every seed (PM-001) | Aashish |
| Driver and monitor on `flit_if`, `t_fifo` harness | `flit_if.sv` and link probe on `sachin/phase1a-fifo-testbench`. Driver, monitor and `t_fifo` harness not pushed | Sachin |

Gate 1 is not met until PM-001 is fixed and all three items are on one branch.

## Open bug
PM-001 (found 2026-10-14 by P06 with `bind_all`): `input_fifo.credit_out` is registered (`credit_out <= do_read`). INTERFACE.md s5.3 and s6 require it combinational (`credit_out = deq`); `input_port` adds the single register. As written, credit return takes 2 cycles instead of 1. `t_fifo` encodes the same registered timing, so it passes; with the RTL corrected, `t_fifo` fails at line 97. Fix needs RTL and testbench (Revanth). Recorded in docs/BUG_LOG.md under pre-merge findings (not counted: RTL not on main).

## Status
| Item | Status | Owner |
|---|---|---|
| Repo, branch protection, ruleset | done | Arnav |
| .gitattributes, .gitignore, CODEOWNERS | done | Arnav |
| README: roles, conventions, module list | done | Arnav |
| Makefile: lint, sim | done (PR #6). Rework on `arnav/rtl-back-initial`: per-test filelists, `WAVES=1`, `make waves`, `SIM=xcelium`, `lint-rtl`; `regress`, `cov`, `formal` stubs removed until Phase 2 | Sachin (review), Arnav |
| CI lint-and-sim | `t_smoke` on main; `tb_noc_pkg` lint and sim added on `arnav/rtl-back-initial` | Sachin, Arnav |
| INTERFACE.md spec-v1 (PR #11) | Not merged. Sign-offs recorded on four different commits (Arnav 432ab16, Aashish N/A, Sachin e578d2a, Revanth cc84961); all four must re-sign the final commit before merge | Sachin (all four sign off) |
| `rtl/pkg/noc_pkg.sv` + `tb_noc_pkg` | Lint clean, sim passes, mutation-checked. PR from `arnav/rtl-back-initial` | Arnav |
| `rtl/back/rr_arbiter.sv` | Written, no testbench yet | Arnav |
| `rtl/front/input_fifo.sv` | On `revu/input-fifo`, PM-001 open | Revanth |
| `tb/sva/fifo_sva.sv` P01-P06 + `bind_all.sv` | On `aashish/sva-fifo` | Aashish |
| `tb/env/flit_if.sv` + `t_flit_if` | On `sachin/phase1a-fifo-testbench` | Sachin |
| tb/sva/PLAN.md v1 (40 properties) | merged (#7) | Aashish |
| Verilator T4 probe (`##[0:N]`) | done (passed) | Aashish |
| Simulator and formal-tool decision | Xcelium and Jasper Gold | Aashish, Arnav |
| Toolchain versions in SYNC.md | 3/4 (Arnav, Sachin, Aashish) | all |
| input_fifo RTL + t_fifo unit verification | done (lint clean; seeds 1–5 passed, 55 checks each) | Revanth |

Counters: RTL modules 1/10. SVA 0/40 (40 planned in PLAN.md). Coverage n/a. Bugs logged 0. Paper draft none.

## Blockers
1. PM-001 blocks Gate 1 (Revanth).
2. Semester 5 exam dates (mid-sem 2 and end-sem) still unknown; needed to re-check Phase 1b.

## Team
| Name | Code | GitHub | Owns |
|---|---|---|---|
| Revanth | R1 | @revantharigela | rtl/front: input_fifo, route_unit, input_port, vc_allocator |
| Arnav | R2 | @zackkracky | rtl/back, rtl/pkg: rr_arbiter, switch_allocator, crossbar, output_unit, router_top; coordinator |
| Sachin | V1 | @sachin19-02 | tb/env, tb/tests, Makefile, CI |
| Aashish | V2 | @coolboy965 | tb/sva, tb/cov, formal, scoreboard, bug log; docs editor |