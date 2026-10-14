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
    sachin19-02 | Ubuntu 24.04.5 LTS | Verilator 5.020 2024-01-01 rev (Debian 5.020-1) | Icarus Verilog version 12.0 (stable) () | git 2.43.0 | Hi sachin19-02
  - Aashish:
    sag | Ubuntu 24.04.2 LTS | Verilator 5.024 2024-04-05 | Icarus Verilog version 12.0 (stable) () | git 2.43.0 | Hi coolboy965
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

## 2026-10-02 (async, Aashish)

Done:
- Authored `tb/sva/PLAN.md` (v1) with 40 named properties (12 Protocol, 18 Safety, 10 Liveness), opened PR `aashish/PLAN.md`.
- Property ownership partitioned strictly per Rule 1: Aashish (24), Revanth (6 cross-checks on Arnav's blocks), Arnav (5 cross-checks on Revanth's blocks).
- Resolved Technical Decision T4: executed Verilator probe (`probe_t4.sv`), confirming native support for bounded delay assertions (`##[0:N]`) under `--assert`.
- Fixed starvation bound parameter $N = 48$ in specification conventions.
- Updated `docs/SYNC.md` and `docs/STATE.md` to reflect Phase 0 exit and Phase 1a entry.

Planned:
- Merge `tb/sva/PLAN.md` upon review by Revanth and Arnav.
- Review Sachin's `docs/INTERFACE.md` spec-v1 draft.
- Scaffold `tb/sva/fifo_sva.sv` (properties P01–P06) ready for Revanth's `input_fifo` landing on Oct 15.

Blocked:
- None.

Decisions:
- Bounded liveness properties use `##[0:N]` in simulation and `s_eventually` under `ifdef FORMAL`.

## 2026-10-14 (async, Revanth)

Done:
- Verified `input_fifo` lint is clean and `t_fifo` passes seeds 1–5 with 55 checks per seed.
- Added the input FIFO lint and simulation checks to `.github/workflows/ci.yml`.
- Fixed the Makefile waveform plusarg to match the testbench's `vcd` argument.
- Added FIFO waveform screenshot evidence at `tb/tests/waves/output1_fifo.png`.

Planned:
- Open a PR for the input FIFO verification updates and check the GitHub Actions result.

Blocked:
- Gate 1 remains in progress pending the separate FIFO SVA and testbench-harness requirements.

Decisions:
- Commit waveform screenshot evidence as PNG; do not include generated simulation build artifacts or the VCD dump
## 2026-10-14 (async, Sachin)

Done:
- Updated the Makefile on the PR #11 branch with Battu's revised targets, strict Verilator lint, standalone RTL lint, and optional GTKWave layout loading.
- Confirmed `make help` works and `git diff --check` reports no whitespace errors.
- After bringing in main's smoke test, make lint TEST=t_smoke and make sim TEST=t_smoke SEED=1 passed.
- Coordinated FIFO credit timing and assertion integration with Revanth and Aashish.

Planned:
- Continue the FIFO testbench timing update and driver/monitor work on the Phase 1a branch.

Blocked:
- Assertion-enabled P01–P06 integration awaits the legal-traffic run against Revanth's pushed combinational credit fix (ca65a74).

Decisions:
- Keep intentional full/empty rejection requests separate from the assertion-enabled legal-traffic run.
## 2026-10-14 (async, Arnav)

Done:
- `rtl/pkg/noc_pkg.sv`:INTERFACE.md s1-s2 constants, enums (`port_e`, `ftype_e`, `vc_state_e`),fixed 30-bit `hdr_t`, width helpers `vc_w()` and `cnt_w()`.
- `tb/tests/tb_noc_pkg.sv` + `tb_noc_pkg.f`:checks `vc_w`/`cnt_w` at NUM_VCS 1-4 and BUFFER_DEPTH 2/4/8, header and payload round-trip at FLIT_WIDTH 32/64/128,enum encodings.Fails as expected when `hdr_t` width or field order is broken. Lint clean,sim passes,waveform image is in docs/figures/noc_pkg_op/.
- CI: `tb_noc_pkg` lint and sim added.
- Integration check for Gate 1: bound `fifo_sva` (aashish/sva-fifo) to `input_fifo` (revu/input-fifo). Found BUG-001, see Blocked.

Planned:
- Makefile: per-test filelist `tb/tests/<test>.f` picked automatically (FILELIST= still overrides); `WAVES=1` dumps to logs/; `make waves`; `SIM=xcelium`; `make lint-rtl FILE=...`; timescale set by the tools so RTL needs no `timescale.
- `rr_arbiter`and `tb_rr_arbiter`,followed by `crossbar.sv`,`switch_allocator.sv` on a fresh branch.
- Xcelium check of `tb_noc_pkg` on available LAB date.

Decisions and notes for everyone:
- New tests: add `tb/tests/<test>.f` (package first, then RTL, then test) and run `make sim TEST=<test>`.Do not edit `filelist.f` for a single test!!!
- Use `noc_pkg::vc_w(NUM_VCS)` and `noc_pkg::cnt_w(BUFFER_DEPTH)`, not local `$clog2`.
- Sachin: applies to `flit_if.sv`.Revanth: after this Makefile merges, move `filelist_fifo.f` to `tb/tests/, drop the branch's Makefile edits and dump waves to logs/ via `+dumpfile`.
- Lint stays `-Wall` fatal. `-Wno-fatal` on `lint` let the FIFO's DECLFILENAME warning through!!!
- Test prefix:ALWAYS USE tb_ NOT t_
- `.gitignore` changed on `arnav/rtl-back-initial`
- PR #11: all four sign-off lines must name the same final commit.
