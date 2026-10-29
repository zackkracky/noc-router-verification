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

## 2026-10-25 (async, Arnav)

Done:
- Reviewed `main` after PR #18 (`7df0cca`) and PR #19 (`75d83f2`). **Gate 1 is met**: driver, framing/credit monitor and `tb_fifo_link` are on `main` with P01-P06 bound; `tb_flit_if` and `tb_fifo_empty_read` landed with them. Tests on `main` go 4 to 7; CI runs `make check SEEDS="1 2 3 4 5"` plus `make neg`.
- `rtl/back/switch_allocator.sv` (92 lines) and `tb/tests/tb_switch_allocator.sv` (467 lines) with `tb_switch_allocator.f`, on `arnav/rtl-back-switch-allocator`. Input-first separable allocation: stage 1 is one `rr_arbiter #(.N(NUM_VCS))` per input, stage 2 one `rr_arbiter #(.N(NUM_PORTS))` per output, both from the merged arbiter. Stage 1 drives `en = input_won[p]` (final grant only, s7.2 T7), stage 2 drives `en = issue[o]`.
- Testbench runs NUM_VCS = 1, 2, 3, 4 in one simulation, each with an independent reference model plus model-free s7 contract checks (onehot0 per input and per output, `issue == |xbar_sel[o]`, grant subset of `sa_req`, grant at `o == sa_out_port[p][v]`). Eight phases: reset, exhaustive (input,VC,output) sweep, stage-2-loss pointer hold, stage-1 commitment characterisation, fairness, starvation bound, out-of-range route, and a 20000-cycle random phase with random resets. Phases 3 and 3b need at least two VCs and are skipped at NUM_VCS = 1.

Validation (Verilator 5.020, `--assert`, the CI version):
- Branch alone (forks from `3ea9243`, before #18): `make check SEEDS="1 2 3 4 5"` 30/30 PASS, five tests with one warning-fatal lint run and five seeds each.
- Same RTL and TB on top of `75d83f2` (code only, scratch merge): `make check SEEDS="1 2 3 4 5"` 48/48 PASS and `make neg` 2/2 PASS.
- The branch's own `STATE.md` and `SYNC.md` conflict with the #18 and #19 doc changes; the code does not. This entry and the matching STATE replace them in a docs-only change off `75d83f2`.
- Not run: Verilator 5.032 (local) and Xcelium.
- Measured per NUM_VCS, seed 1: starvation max wait 4 / 9 / 13 / 14 against the bound `N_SA = NUM_VCS*NUM_PORTS-1` = 4 / 9 / 14 / 19; allocation efficiency (grants / maximum bipartite matching) 1.0000 / 0.9136 / 0.8345 / 0.7795.

Planned:
- Rebase `arnav/rtl-back-switch-allocator` onto `75d83f2`, drop its `docs/` edits, and open the `switch_allocator` PR (RTL and TB only).
- `router_top` skeleton by 31 Oct; `crossbar` 1 Nov; `output_unit` 2 Nov.
- 26 Oct lab session: first `xrun` of `tb_noc_pkg`, `tb_fifo`, `tb_rr_arbiter`, `tb_switch_allocator`, plus Sachin's three new tests and the `FLIT_IF_CLOCKING` probe. `tb_switch_allocator` is the first test to use `$countones` and a recursive function (`mm_aug`), so it is the one most likely to need a change under `xrun`.
- Collect semester 5 mid-sem 2 and all semester 6 dates at the same session.

Blocked:
- `rtl/front/route_unit.sv` was due 24 Oct and is not started on any branch. `input_port` and `vc_allocator` are due 31 Oct and depend on it. Revanth to confirm a date; if route_unit is not on `main` by 28 Oct, `router_top` lands as a skeleton with the front half stubbed.
- Semester 5 mid-sem 2 date and all semester 6 dates. A mid-sem 2 on or before 2 Nov pulls the blackout start forward and collapses the 26 Oct - 2 Nov week to document collection.
- JasperGold seat confirmation; logins requested 26-28 Oct.

Decisions and notes for everyone:
- **Stage-1 commitment loss is a measured property of this allocator, not a bug.** One VC per input is offered to stage 2 each cycle, so an input that loses stage 2 hides its other VCs for that cycle and the result is a valid matching but not always a maximal one. Phase 3b pins the directed case (in0 VC0 to out2; in1 VC0 to out2, VC1 to out3: one grant against a maximum matching of 2) and phase 7 measures the loss. A masked second iteration is the fix and is a Phase 3 candidate, not Phase 1 scope.
- The starvation bound `N_SA = NUM_VCS*NUM_PORTS-1` is **measured, not proven**, and it is tight only at NUM_VCS <= 2 (4/4 and 9/9); at 3 and 4 the measured waits sit below it. Aashish: the A-series property needs the bounded `##[0:N_SA]` form, and the unbounded `s_eventually` form belongs to formal.
- Out-of-range route codes (`PORT_W` carries 8 codes, only 5 are outputs) yield no grant and block that input. That is safe but it is not a contract guarantee; it needs an assume in `formal/assume.sv`, and `vc_allocator` and `route_unit` must never emit one.

2026-10-30 (async, Arnav)

Covers 26-30 Oct: the first lab session on Xcelium and JasperGold, PR #21 (arnav/formal-fifo-v3, 5 commits) and PR #22 (arnav/bug-log-format, 1 commit on top of #21). Neither is merged; main is still 08c0fdf.

Done - lab qualification, 28 Oct (main at 08c0fdf):

Xcelium xrun 22.09-s003: all 8 merged tests, lint plus seeds 1-5, 48/48 PASS. tb_switch_allocator needed no change under xrun; $countones and the recursive mm_aug are accepted as written.
FLIT_IF_CLOCKING probe with @(link.cb): PASS on all four (F,V,D) configurations. Elaboration reports 18 clocking items, so the define was active. The optional clocking blocks stay; the 26 Oct conditional deletion does not apply.
JasperGold (Jasper Apps 2022.09p001): licence and jasper_fao checkout work on the lab machine. The seat question from 25 Oct is closed.
First jg -batch formal/fifo.tcl failed at analyze: VERI-1906 x5 on input_fifo input ports, then VERI-1072 and the module ignored, 6 errors, session dead at line 4 of the Tcl. Zero properties elaborated. No proof of P01-P06 has run and none may be claimed.
Lab shell behaves as csh despite $SHELL; use |& tee, not 2>&1 | tee.

Done - PR #21, arnav/formal-fifo-v3 (open, 5 commits, ~398 changed lines):

TP-001 fix: input logic to input wire logic on 25 input ports in 5 files (input_fifo 5, rr_arbiter 4, switch_allocator 4, fifo_sva 9, flit_driver 3). Under `default_nettype none an ANSI input logic x has a data type but no net type, so the port kind falls back to the absent default net type (IEEE 1800-2017 s23.2.2.3). Verific enforces it; xmvlog only warns (NODNTW) and substitutes wire; Verilator 5.020 is silent at -Wall. Outputs are unaffected.
The xrun NODNTW warnings, not a reading of rtl/, established the real scope. They are what put tb/env/flit_driver.sv in the set.
formal/fifo.tcl committed: analyze, elaborate -top input_fifo, clock clk, reset -expression {!rst_n}, prove -all, report -summary. P01/P02 become assumes under +define+FORMAL.
docs/RESULTS.md added. Every paper number traces to a row naming commit, command, tool version and where the log lives. Seeded with Q-001 to Q-004, the three mutation runs and the measured switch_allocator and rr_arbiter characterisation data.
docs/qual/2026-10-28/ added: sanitized excerpts backing the Q rows, 94 lines over four files plus an index.
Makefile: XRFLAGS= and VLFLAGS= passthrough, both defaulting empty. The clocking-probe command documented in RESULTS named a variable the Makefile did not have, so it was not runnable; the probe had been run by hand.
.gitignore: xcelium_*/, xrun.history, xrun.key, *.shm/, jgproject/, plus !docs/qual/**/*.log so the curated excerpts are tracked.
README: convention 7 and the module template now require input wire logic; Modules table updated for switch_allocator; venue target removed.

Done - PR #22, arnav/bug-log-format (open, 1 commit on top of #21, 361 added / 42 removed):

docs/BUG_LOG.md becomes an index plus metrics: one narrow row per defect with severity, priority, class, status, found-by, dates; counts by status and technique; a discovery-by-week curve.
docs/bugs/TEMPLATE.md plus one record per defect. Seven sections: symptom, reproduce, root cause, fix, escape analysis, collateral sweep, closure.
docs/bugs/PM-001.md and docs/bugs/TP-001.md migrated and expanded to the template.
Status workflow NEW -> TRIAGED -> ASSIGNED -> FIXED -> VERIFIED -> CLOSED, with REOPENED, DEFERRED, DUPLICATE, NOT-A-BUG.
README Process rules and docs/STATE.md updated to match.

Validation (Verilator 5.020, the CI version):

PR #21: make check SEEDS="1 2 3" 32/32 PASS, make neg 2/2 PASS. The port change is behaviour-neutral.
PR #22 is docs-only; make check SEEDS="1" 16/16 PASS and every index link resolves.
Not run: Xcelium and JasperGold against the fixed sources. Both PRs are Verilator-verified only.

Planned:

Merge #21, then rebase #22 onto main (git rebase --onto origin/main arnav/formal-fifo-v3 arnav/bug-log-format), since squash-merge rewrites #21's commits.
Re-run jg -batch formal/fifo.tcl on the lab machine after #21 merges. That run closes TP-001 and produces the first proof row in RESULTS. Aashish signs section 7.
router_top skeleton 31 Oct with the front half stubbed, crossbar 1 Nov, output_unit 2 Nov, scoreboard v1 2 Nov.
Five applications submitted by 2 Nov. Blackout starts 3 Nov.

Blocked:

rtl/front/route_unit.sv was due 24 Oct and is on no branch as of 30 Oct. The 25 Oct fallback is now active: router_top lands as a skeleton with the front half stubbed. input_port and vc_allocator (31 Oct) are at risk (Revanth).
TP-001 cannot close before the post-merge analyze re-run, so the formal half of Phase 2 has no evidence yet.
Semester 5 mid-sem 2 and all semester 6 dates, still uncollected after the 28 Oct lab session.
main is 08c0fdf; #21 needs a review that is not self-approval.

Decisions and notes for everyone:

Raw tool logs are never committed. Cadence logs carry a confidentiality and trade-secret banner and embed absolute lab paths including an account identifier, and this repository is public. Only redacted excerpts that back a specific RESULTS row go in docs/qual/<date>/; full logs stay in the off-repo archives named as A-001 and A-002.
TP-001 is not a counted bug and never becomes one. It has no functional symptom in simulation. The counted floor stays at 0 of the 2 required by 28 Feb.
Injected mutants stay out of the bug log. They live in docs/RESULTS.md R2. A reviewer who finds injected faults and real defects in one table discounts both.
The verifier is never the owner. FIXED means merged; CLOSED means someone other than the fix author reproduced the original failure, confirmed the fix removes it, and signed the record. This is the cross-ownership rule applied to closure and it binds all four of us.
A check that passed on broken RTL is a second defect and gets its own record. PM-001 is the case: t_fifo line 97 asserted the registered credit_out timing as correct, so the unit test certified the defect for the four days PR #13 was open.
Bug IDs keep their B- / PM- / TP- prefixes and never change after a record is pushed; reclassification edits the counts toward exit field, not the ID.
Severity and priority are separate fields. TP-001 is S4 and P1: cosmetic in simulation, blocking for all formal work.
Class codes C1-C7 are provisional until Aashish checks them against PAPER_PLAN v1.0. They live in a field, not in the ID, so remapping is one PR.
PM-001's fix is PR #13 (1fd956e), issue #11.the #11 in the commit subject is the issue.
One front end is not verification. Lint and CI were green for weeks on source that was never legal SystemVerilog. Xcelium -elaborate on every merged test and analyze on each new block are now entry conditions, not optional lab extras.