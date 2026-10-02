# STATE

Updated: 2026-10-02 (Aashish). Single snapshot; history lives in SYNC.md.

## Phase
Phase 1a: Block RTL and Unit Verification (1 Oct to 3 Nov 2026).

## Next deadline
2026-10-15, Phase 1a Gate 1:
* `input_fifo` passing `t_fifo` seeds 1 to 5, lint clean (Revanth)
* FIFO protocol SVA `P01` to `P06` bound and passing on `t_fifo` (Aashish)
* Driver and monitor on `flit_if`, `t_fifo` harness (Sachin)

## Status
| Item | Status | Owner |
|---|---|---|
| Repo, branch protection, ruleset | done | Arnav |
| .gitattributes, .gitignore, CODEOWNERS | done | Arnav |
| README: roles, conventions, module list | done | Arnav |
| Makefile: lint, sim, regress, cov, formal | done (PR #6) | Sachin |
| CI lint-and-sim green once | done | Sachin |
| Required status check added to ruleset | done | Arnav |
| INTERFACE.md spec-v1 | draft in review, due 2026-10-01 | Sachin (all four sign off) |
| tb/sva/PLAN.md v1 (40 properties) | PR open (`aashish/PLAN.md`) | Aashish |
| Verilator T4 probe (`##[0:N]`) | done (passed) | Aashish |
| Simulator and formal-tool decision | Xcelium and Jasper Gold | Aashish, Arnav |
| Toolchain versions in SYNC.md | 3/4 (Arnav, Sachin, Aashish) | all |

Counters: RTL modules 0/10. SVA 0/40 (40 planned in PLAN.md). Coverage n/a. Bugs logged 0. Paper draft none.

## Blockers
1. Semester 5 exam dates (mid-sem 2 and end-sem) unknown; Arnav pulling from timetable to evaluate Phase 1b schedule.
2. None blocking active Phase 1a development.

## Team
| Name | Code | GitHub | Owns |
|---|---|---|---|
| Revanth | R1 | @revantharigela | rtl/front: input_fifo, route_unit, input_port, vc_allocator |
| Arnav | R2 | @zackkracky | rtl/back, rtl/pkg: rr_arbiter, switch_allocator, crossbar, output_unit, router_top; coordinator |
| Sachin | V1 | @sachin19-02 | tb/env, tb/tests, Makefile, CI |
| Aashish | V2 | @coolboy965 | tb/sva, tb/cov, formal, scoreboard, bug log; docs editor |