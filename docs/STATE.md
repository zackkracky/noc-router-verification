# STATE

Updated: YYYY-MM-DD (who). Single snapshot; history lives in SYNC.md.

## Phase
Phase0-1bridge along with repo-hygyiene
Phase 1a RTL starts 2026-10-01.

## Next deadline
2026-10-01, three gates together:
- INTERFACE.md frozen and tagged `spec-v1` (Sachin author, all four sign off)
- `tb/sva/PLAN.md` v1, 40 named properties with group and owner (Aashish)

## Status
| Item | Status | Owner |
|---|---|---|
| Repo, branch protection, ruleset | done | Arnav |
| .gitattributes, .gitignore, CODEOWNERS | done | Arnav |
| README: roles, conventions, module list | done | Arnav |
| Makefile: lint, sim, regress, cov, formal | pending, due 2026-09-29 | Sachin |
| CI lint-and-sim green once | pending, due 2026-09-29 | Sachin |
| INTERFACE.md spec-v1 | draft, review due 2026-10-01 | Sachin |
| Required status check added to ruleset | done | Arnav |
| INTERFACE.md `spec-v1` | draft, review due 2026-10-01 | Sachin |
| tb/sva/PLAN.md v1 | not started | Aashish |
| Simulator and formal-tool decision | Xcelium and Jasper Gold | Aashish, Arnav |
| Toolchain versions in SYNC.md | 1/4; arrives with each first commit | all |

Counters: RTL modules 0/10. SVA 0/40. Coverage n/a. Bugs logged 0. Paper draft none.(Initial stage before implementations)

## Blockers
1. Makefile empty, so CI cannot run, so the required check cannot be added to the ruleset. Sachin, 2026-09-29.
2. No simulator decided,  so Phase 2 is either covergroups or hand-rolled monitor counters. Undecided past 1 Oct means plan for the Verilator-only path. Aashish and Arnav. Decision to be made after consulting Dr.Anuradha.
3. CI must run green once before the required check can be added to the ruleset. Sachin, 2026-09-29 — must land before Phase 1a branches open 2026-10-01.



## Team
| Name | Code | GitHub | Owns |
|---|---|---|---|
| Revanth | R1 | @revantharigela | rtl/front: input_fifo, route_unit, input_port, vc_allocator |
| Arnav | R2 | @zackkracky | rtl/back, rtl/pkg: rr_arbiter, switch_allocator, crossbar, output_unit, router_top; coordinator |
| Sachin | V1 | @sachin19-02 | tb/env, tb/tests, Makefile, CI |
| Aashish | V2 | @coolboy965 | tb/sva, tb/cov, formal, scoreboard, bug log; docs editor |