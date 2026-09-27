# Weekly sync notes

Append-only. One block per sync: date, done / planned / blocked per person, decisions.

## 2026-09-22 (setup)
- Ruleset protect-main active and verified (GH013 on direct push).
- Owner setup items 1-6, 9 done; lint-and-sim added to ruleset after first green CI.
- Toolchain lines (SETUP section 8), due 25 Sep:
  - Arnav:
    zackkracky | Ubuntu 26.04.1 LTS | Verilator 5.032 2025-01-01 rev (Debian 5.032-1) |  Icarus Verilog version 12.0 (stable) () | git 2.53.0 |  Hi zackkracky
  - Revu:
  - Sachin:
  - Sag:
- Decisions: bug log file is docs/BUG_LOG.md.

## 2026-09-27 (async, Arnav)
 
Landed or in review: README (roles, conventions, module list, parameter table, module table); .gitattributes, .gitignore, CODEOWNERS.
 
CODEOWNERS changed, take note before your next PR:
- rtl/pkg/ reviewer Arnav -> Revu (Arnav authors noc_pkg.sv)
- docs/ reviewer Arnav -> Sag (removes self-approval on STATE and SYNC)
- Makefile and .github/ reviewer lines added (Arnav)
New: rtl/pkg/noc_pkg.sv holds the flit struct, port encoding (N=0 E=1 S=2 W=3 L=4), flit types (HEAD=0 BODY=1 TAIL=2 HEAD_TAIL=3) and parameter defaults. Sachin: INTERFACE.md and tb/env import it, do not redefine flit fields.
 
CI review sent to Sachin: ci.yml runs a test that does not exist yet (use t_smoke), runner unpinned (use ubuntu-24.04 for Verilator 5.020), no PASS grep so a failing sim goes green. Makefile still empty; corrected ci.yml and a Makefile draft attached to his PR thread. Due 2026-09-29, reviewer Arnav.
 
Toolchain versions: report yours in your first commit's PR description rather than as a separate message. Format: OS, Verilator, Icarus, GTKWave, Python.
 
Open on 2026-10-01: INTERFACE.md spec-v1 sign-off (all four), tb/sva/PLAN.md v1 (Sag), simulator and formal-tool answer from the guide (Sag, Arnav).
 
Unknown and blocking: semester 5 mid-sem 2 and end-sem dates. Arnav pulls them from the timetable this week; Phase 1b may be re-cut

Deadline split: Sachin's Makefile + smoke CI moved to 2026-09-29 (independent of the spec), INTERFACE.md stays 2026-10-01. Reason: the required lint-and-sim check must be added to the ruleset before Phase 1a branches open on 1 Oct, so CI cannot share the freeze date.