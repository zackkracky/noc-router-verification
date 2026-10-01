# Weekly sync notes

Append-only. One block per sync: date, done / planned / blocked per person, decisions.

## 2026-09-22 (setup)
- Ruleset protect-main active and verified (GH013 on direct push).
- Owner setup items 1-6, 9 done; lint-and-sim added to ruleset after first green CI.
- Toolchain lines (SETUP section 8), due 25 Sep:
  - Arnav:
    zackkracky | Ubuntu 26.04.1 LTS | Verilator 5.032 2025-01-01 rev (Debian 5.032-1) |  Icarus Verilog version 12.0 (stable) () | git 2.53.0 |  Hi zackkracky
  - Revanth:
  - Sachin:
  - Aashish:
- Decisions: bug log file is docs/BUG_LOG.md.

## 2026-09-27 (async, Arnav)
 
Landed or in review: README (roles, conventions, module list, parameter table, module table); .gitattributes, .gitignore, CODEOWNERS.
 
CODEOWNERS changed, take note before your next PR:
- rtl/pkg/ reviewer Arnav -> Revanth (Arnav authors noc_pkg.sv)
- docs/ reviewer Arnav -> Aashish (removes self-approval on STATE and SYNC)
- Makefile and .github/ reviewer lines added (Arnav)
New: rtl/pkg/noc_pkg.sv holds the flit struct, port encoding (N=0 E=1 S=2 W=3 L=4), flit types (HEAD=0 BODY=1 TAIL=2 HEAD_TAIL=3) and parameter defaults. Sachin: INTERFACE.md and tb/env import it, do not redefine flit fields.
 
CI review sent to Sachin: ci.yml runs a test that does not exist yet (use t_smoke), runner unpinned (use ubuntu-24.04 for Verilator 5.020), no PASS grep so a failing sim goes green. Makefile still empty; corrected ci.yml and a Makefile draft attached to his PR thread. Due 2026-09-29, reviewer Arnav.
 
Toolchain versions: report yours in your first commit's PR description rather than as a separate message. Format: OS, Verilator, Icarus, GTKWave, Python.
 
Open on 2026-10-01: INTERFACE.md spec-v1 sign-off (all four), tb/sva/PLAN.md v1 (Aashish), simulator and formal-tool answer from the guide (Aashish, Arnav).
 
Unknown and blocking: semester 5 mid-sem 2 and end-sem dates. Arnav pulls them from the timetable this week; Phase 1b may be re-cut

Deadline split: Sachin's Makefile + smoke CI moved to 2026-09-29 (independent of the spec), INTERFACE.md stays 2026-10-01. Reason: the required lint-and-sim check must be added to the ruleset before Phase 1a branches open on 1 Oct, so CI cannot share the freeze date.
## 2026-09-30 (async, Sachin)

Done: Makefile (lint, build, run, sim, regress, clean) and filelist.f, submitted as PR #6 (replaces #5). CI lint-and-sim was green on #5. Build output goes to obj_dir/.

Planned: docs/INTERFACE.md spec-v1 draft for review by 2026-10-01. Imports rtl/pkg/noc_pkg.sv, does not redefine flit fields.

Blocked: PR #6 needs Arnav's review. cov and formal targets not in the Makefile yet.

Decisions: make sim is an alias for make run. Tests print TEST PASSED and make run checks for it.

## 2026-10-01 (async, Sachin)

Done:
- STATE.md cleaned up: removed the extra deadline line for simulator/formal-tool decision and kept the status entry as Xcelium and Jasper Gold in the requested order.
- README updated to use full names for Revanth and Aashish.
- CODEOWNERS updated: Makefile owner changed from @zackkracky to @sachin19-02.
- Repo documentation sync reflected the final decision with the updated wording and ownership.

Planned:
- Keep the docs aligned with the current repo hygiene and phase gates as the project moves into Phase 1a.
- Continue the Makefile/CI and spec work on the active branch.

Blocked:
- None noted today.

Decisions:
- Simulator/formal tool choice is now recorded as Xcelium and Jasper Gold in the project status docs.
- Documentation wording for deadline tracking should stay concise and avoid guide-specific phrasing.
