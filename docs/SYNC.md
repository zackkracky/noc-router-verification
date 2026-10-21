# Weekly sync notes

Append-only. One block per sync: date, done / planned / blocked per person, decisions.

## 2026-09-22 (setup)
- Ruleset protect-main active and verified (GH013 on direct push).
- Owner setup items 1-6, 9 done; lint-and-sim added to ruleset after first green CI.
- Toolchain lines (SETUP section 8), due 25 Sep:
  - Arnav:
    zackkracky | Ubuntu 26.04.1 LTS | Verilator 5.032 2025-01-01 rev (Debian 5.032-1) |  Icarus Verilog version 12.0 (stable) () | git 2.53.0 |  Hi zackkracky
  - Revanth:
    revantharigela | Ubuntu 24.04.2 LTS | Verilator 5.024 2024-04-05 | Icarus Verilog version 12.0 (stable) () | git 2.43.0 | Hi revantharigela
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

## 2026-10-19 (async, Aashish)

Done:
- Phase 1a Gate 1 verified: `fifo_sva.sv` (P01–P06) bound via `bind_all.sv` and passing 100% on `input_fifo` (`t_fifo`) under `--assert` (55/55 checks passed, 0 failures).
- Pre-merge RTL bug caught via assertion P06 (`a_p06_credit_iff_dequeue` credit timing mismatch); fixed by Revanth in commit `ca65a74`.
- Reviewed and approved Revanth's PR #13 (`revu/input-fifo`) and Arnav's PR #15 (`README`).
- Expanded `tb/sva/PLAN.md` to 52 properties (15 Aashish, 8 Sachin, 14 Revanth, 15 Arnav) per team instructions (G1), establishing 40 passing as the Phase 2 exit floor.
- Documented bounded liveness environment assumptions (upstream `TAIL` progress, downstream $D_{MAX}$ credit return).
- Updated `docs/STATE.md` and `docs/SYNC.md`.

Planned:
- Merge `tb/sva/PLAN.md` 52-property PR (G1).
- Rebase and merge `aashish/sva-fifo` into `main` immediately once Arnav merges PR #13.
- Begin Scoreboard v1 (`tb/env/scoreboard.sv`) with XY reference model `expected_port(dst_x, dst_y)` ahead of the 3 Nov exam blackout.
- Confirm JasperGold lab access during the 26–28 Oct window.

Blocked:
- PR #13 squash-merge by Arnav needed to land `bind_all.sv` on `main`.

Decisions:
- Starvation bound fixed at $N = 48$ cycles (`##[0:N]`).
- Master property taxonomy expanded to 52 properties with owner-prefixed A/R/S/V tags.

## 2026-10-20 (async, Arnav)
 
Done:
- `rtl/back/rr_arbiter.sv`: N-way round-robin arbiter, thermometer mask from a pointer, sync active-low reset, combinational `grant`/`grant_idx`/`grant_vld`, pointer rotates only when `en && grant_vld`. Verilator `-Wall` clean at N = 1, 2, 3, 4, 5, 8, 20.
- `tb/tests/tb_rr_arbiter.sv` + `.f`: exhaustive pointer x request sweep against an independent reference model, en-hold, fairness, starvation bound (measured max wait = N-1), reset, random with random resets; N = 1, 2, 3, 4, 5, 8 in one run; per-N result table. 5 of 5 non-equivalent injected mutants killed (no +1, ignore en, stuck pointer, mask off by one, no reset); the no-wrap mutant (`ptr_q <= grant_idx + 1` without the N-1 check) is equivalent at the ports, because `ptr = N` gives `mask = 0` and takes the same wrap path as `ptr = 0`. Only an internal property `ptr_q < N` distinguishes it.
- Makefile and CI: `make check SEEDS="..."`, `WAVES=1` passes `+dumpfile=`; `ci.yml` duplicate `run:` key fixed, CI runs `make check SEEDS="1 2 3"` and uploads `logs/`.
- README and INTERFACE.md s7.2 (arbiter contract) updated.
- PR #16 merged 2026-10-21 (edce4cc). Follow-up: mutant count corrected to 5/5 non-equivalent + 1 equivalent; STATE stale rows corrected; CI actions moved to Node 24 majors (`checkout@v6`, `upload-artifact@v6`).
Planned:
- Aashish rebases PR #17 onto `main` (only his three commits) and adds the SVA to `tb_fifo.f` with `--assert` so CI runs P01-P06.
- 2026-10-26 first `xrun` check of `tb_noc_pkg` and `tb_rr_arbiter` on the lab machine.
- `switch_allocator` and `router_top` skeleton by 2026-10-31; `crossbar` 2026-11-01; `output_unit` 2026-11-02.
Blocked:
- Semester 5 mid-sem 2 date and semester 6 dates.
- JasperGold seat confirmation.
Decisions and notes for everyone:
- One arbiter everywhere: `switch_allocator` stages 1 and 2 and `vc_allocator` instantiate `rr_arbiter`; eligibility (credit, VC busy) is an AND on `req` in the caller. Stage 1 drives `en = |sa_grant[p]`, stage 2 drives `en = grant_vld` (INTERFACE.md s7.2). Revanth: confirm `vc_allocator` can use it.
- `make check SEEDS="1 2 3"` is what CI runs; run it before marking a PR ready.
- Waves: tests read `+dumpfile=` and dump only when given. Revanth: `t_fifo` becomes `tb_fifo` (module, `$dumpvars`, `tb/tests/tb_fifo.f` replacing `filelist_fifo.f`); `tb/tests/waves/output1_fifo.png` moves to `docs/figures/`.
- Test names always `tb_`; the smoke test is `tb_smoke`.
- Exam blackout 3 Nov to 9 Dec: nothing planned inside it; Phase 1b starts 10 Dec.

## 2026-10-21 (async, Sachin)

Done:
- Prepared `flit_if` using package width helpers, `flit_pkt`, a credit-aware
  registered driver and passive framing monitor on top of merged PRs #16/#17
  (`3ea9243`), preserving the assertion-enabled Makefile and FIFO unit test.
- Added `tb_fifo_link` with real per-VC FIFOs, one registered return stage,
  independent queues and parameter/seeded traffic checks; kept `tb_fifo` intact.
- Added `tb_flit_if` and per-test filelists for automatic `make check` discovery.

Planned:
- Review the link environment, then connect it to `input_port` when available.
- Keep the merged P01-P06 checkers bound in both FIFO test filelists.

Blocked / limits:
- Verilator 5.020 does not accept hierarchical clocking events; raw-interface
  sampling is used. Clocking blocks remain opt-in for later tool qualification.
- Xcelium is not available in this environment; lab qualification is pending.
- P01-P06 are merged in PR #17; the new harness still needs review/merge.

Earlier validation on PR #16 baseline (Verilator 5.020; before PR #17):
- `make check SEEDS="1 2 3"`: 24/24 PASS, including six warning-free lint runs.
- `tb_fifo_link` seed 7 with `WAVES=1`: PASS; FST created.
- `+bad_framing` and `+bad_vc`: both failed with the intended diagnostic.
- A temporary one-bit corruption of FIFO output was caught by the independent
  queue comparison. This was a test mutation, not a bug in merged RTL.

Validation on updated main `3ea9243` (Verilator 5.020):
- `make check SEEDS="1 2 3"`: 24/24 PASS with `--assert`.
- P01-P06 bound to the FIFO instances in both `tb_fifo` and `tb_fifo_link`.
- `+bad_framing` and `+bad_vc` rejected with the intended framing/VC diagnostics.


## 2026-10-21 (PR #18 review follow-up, Sachin)

Changes:
- Added explicit admission evidence for the coincident VC1 command, per-fill consecutive-valid-edge checks and exact D-1 occupancy at the final command's return.
- Retained the buffered-head reset case; added reset with a registered flit pending and with a delayed credit pending. Each directed case checks its precondition before asserting reset.
- Added the fourth (F,V,D) point (32,1,4); only multi-VC cases require a different-VC event. This is four configurations, not a 27-point Cartesian sweep.
- Added registered credit observations to the passive monitor and checked their event/VC sampling in the harness.
- Removed the raw-wire probe; `tb_flit_if` now tests transaction pack/unpack only, retaining its existing top/filelist name.
- Added `make neg` and a CI step requiring nonzero exit plus the exact expected fatal diagnostic for both framing and invalid-VC injections. The invalid-VC injection is exercised by the V=3 case. CI now requests seeds 1-5 and publishes both summaries.
- Shortened README; kept INTERFACE s8 normative. Restored pre-merge Gate 1/test-counter status and recorded the inline-property undercount and separate RTL-cleanup follow-up.

Review correction (item 4):
- INTERFACE s6 explicitly makes rd_ready an empty-forbidden pop strobe. Removing the harness guard caused the bound P02 assertion to fail on correct RTL.
- Normal `tb_fifo_link` therefore retains the guard and all bound P01-P06 checks. The separate `tb_fifo_empty_read` intentionally drives the illegal boundary row without binding P01/P02, as s6 permits; the existing inline RTL safety assertions remain active. It checks empty reads before and after a real enqueue/dequeue, with no phantom credit or occupancy change.
- The return adapter compares credit with `rd_ready && rd_valid` and records pops only on actual dequeue.

Qualification/follow-ups:
- Xcelium and the optional FLIT_IF_CLOCKING probe remain pending on 26 Oct. The Makefile already has `xrun -timescale 1ns/1ps`; no timescale fix was necessary.
- Verilator/Xcelium random streams are simulator-specific; equal seed numbers are not equivalent stimulus.
- Qualify the optional clocking blocks on 26 Oct or remove them if qualification fails. No clocking-block acceptance or spec-v1 freeze is claimed.
- Moving six inline FIFO properties plus three inline tb_fifo assertions, assigning a hold-property P-number, and replacing the RTL initial depth check belong in a separate PR. Mixed-VC random-traffic expansion and the helper-file rename remain separate follow-ups.
- Gate 1 stays pending until these changes are verified, approved and merged; all four spec sign-offs must refer to one agreed commit.

Validation of this review revision (Verilator 5.020, --assert):
- `make check SEEDS="1 2 3 4 5" WAVES=1`: 42/42 PASS (seven warning-fatal lint checks plus 35 simulations); actual per-check results in logs/summary.txt.
- `make neg WAVES=1`: 2/2 PASS, each requiring nonzero exit and the intended `%Fatal` message; logs/negative-summary.txt and per-injection logs retain the evidence.
- FST files generated for tb_fifo_link, transaction-only tb_flit_if and tb_fifo_empty_read. GTKWave GUI was not visually checked in this environment.
- In isolated copies, `credit_out = rst_n && rd_ready` was caught by tb_fifo_empty_read, and a one-bit error in flit_pkt.pack() was caught by tb_flit_if. Mutants were never applied to the PR sources.
- This environment used local C++ precompiled-header include overrides to work around its compiler; no repository compiler/simulator settings were changed for that workaround.
- Attach logs/summary.txt (or the new CI run link after pushing) to PR #18 before merge. Local results are not a claim that the new CI revision has already run.
