# RESULTS

Every number in the paper traces to a row here: the commit it was produced on, the exact command, the tool and version, and where the raw log lives. No number enters a draft without a row. Raw tool logs are never committed: they carry vendor confidentiality banners and absolute lab paths. Sanitized excerpts that back a specific row live in `docs/qual/<date>/`; the full logs are archived off-repo and named in the Raw log archive table.

Conventions:
- `commit` is the full-tree commit the run was made on, never a branch name.
- `command` is copy-pasteable from the repo root.
- Seeds are simulator-specific: Verilator and Xcelium do not generate the same traffic from the same seed number. Always quote `SIM=` with the seed.
- A run that failed is still a row. Deleting failures is how a measurement study loses its credibility.

## R1. Tool qualification

| id | date | tool + version | commit | command | result | raw log |
|---|---|---|---|---|---|---|
| Q-001 | 2026-10-28 | Xcelium `xrun` 22.09-s003 | `08c0fdf` | `make check SEEDS="1 2 3 4 5" SIM=xcelium` | 48/48 PASS: 8 tests x (lint + seeds 1-5) | in repo: `docs/qual/2026-10-28/xcelium-summary.txt`; full set A-001 |
| Q-002 | 2026-10-28 | Xcelium `xrun` 22.09-s003 | `08c0fdf` | `make sim TEST=tb_fifo_link SEED=1 SIM=xcelium XRFLAGS=+define+FLIT_IF_CLOCKING` | PASS on all four `(F,V,D)` configs; `@(link.cb)` accepted, so the opt-in clocking blocks stay. Elaboration reports 18 clocking items, confirming the define was active. The original probe was run by hand: the Makefile had no define passthrough until `XRFLAGS` was added in the same PR, and the command above is the reproducible form | in repo: `docs/qual/2026-10-28/xcelium-clocking-probe.excerpt.log` |
| Q-003 | 2026-10-28 | JasperGold (Jasper Apps) 2022.09p001 | `08c0fdf` | `jg -batch formal/fifo.tcl` | **FAIL at `analyze`**: VERI-1906 x5 on `input_fifo` input ports, VERI-1072 module ignored; 0 properties elaborated, 0 proven. Cause TP-001 (`docs/BUG_LOG.md`) | in repo: `docs/qual/2026-10-28/jasper-fifo-analyze.excerpt.log` |
| Q-004 | 2026-10-28 | Verilator 5.020 | `08c0fdf` + TP-001 patch | `make check SEEDS="1 2 3"` then `make neg` | 32/32 PASS, `make neg` 2/2 PASS: the TP-001 fix is regression-neutral | not archived (reproducible locally) |

Open: P01-P06 have **no** JasperGold proof. The first proof row lands only after the TP-001 fix merges and `formal/fifo.tcl` reruns. Until then no draft, slide or application may say the FIFO properties are formally proven.

## R2. Unit-level mutation kills

Injected mutants only. Real defects live in `docs/BUG_LOG.md` and `docs/bugs/`; reviewers conflate the two if they share a table.

| id | date | block | mutants | killed | killed by | commit | command |
|---|---|---|---|---|---|---|---|
| M-001 | 2026-10-19 | `rr_arbiter` | 6 injected, 5 non-equivalent | 5/5 | `tb_rr_arbiter` reference model | `edce4cc` | `make sim TEST=tb_rr_arbiter SEED=1` per mutant |
| M-002 | 2026-10-21 | `switch_allocator` | 7 | 7/7 | `tb_switch_allocator` reference model + s7 contract checks | `08c0fdf` | `make sim TEST=tb_switch_allocator SEED=1` per mutant |
| M-003 | 2026-10-14 | `input_fifo` (SVA-only, TB checks non-fatal) | 9 | 5 | P06 (registered `credit_out`), P04, P05, P01/P02 | `3ea9243` | `make build TEST=tb_fifo` then `obj_tb_fifo/sim +sva_only` |

`M-001` note: the no-wrap mutant (`ptr_q <= grant_idx + 1` without the `N-1` check) is **equivalent at the ports** and is excluded from the denominator; only an internal `ptr_q < N` property distinguishes it (R03). `M-003` survivors: simultaneous read/write count change, `rd_ptr`/`wr_ptr` stuck. Both are assigned slots in `tb/sva/PLAN.md`.

These are pilot measurements, not the paper's matrix. The paper's 37 mutants in 7 classes are injected only after the property plan is frozen.

## R3. Measured design characteristics

| id | date | metric | value | commit | command |
|---|---|---|---|---|---|
| D-001 | 2026-10-21 | `switch_allocator` starvation max wait, `NUM_VCS` 1/2/3/4 at seed 1 | 4 / 9 / 13 / 14 cycles against bound `N_SA = NUM_VCS*NUM_PORTS-1` = 4 / 9 / 14 / 19 | `08c0fdf` | `make sim TEST=tb_switch_allocator SEED=1` |
| D-002 | 2026-10-21 | `switch_allocator` allocation efficiency (grants / maximum bipartite matching), `NUM_VCS` 1/2/3/4 | 1.0000 / 0.9136 / 0.8345 / 0.7795 | `08c0fdf` | `make sim TEST=tb_switch_allocator SEED=1` |
| D-003 | 2026-10-19 | `rr_arbiter` max wait under a held request, `N` = 1,2,3,4,5,8 | `N-1` in every case (bound tight) | `edce4cc` | `make sim TEST=tb_rr_arbiter SEED=1` |

`D-001` is **measured, not proven**, and tight only at `NUM_VCS <= 2`. Any paper sentence about the bound says "measured"; the proof is formal work in Phase 2.

## Raw log archive

Logs stay out of git. Each archive is named here so a row can be audited.

| id | date | contents | tool | where |
|---|---|---|---|---|
| A-001 | 2026-10-28 | full `logs/` from the lab Xcelium session: per-test lint, seeds 1-5, build logs, `summary.txt`, version stamps (50 files, 252 KB) | xrun 22.09-s003 | Drive; rename to `qual-2026-10-28-xcelium.zip` |
| A-002 | 2026-10-28 | `fifo_jg.log` and `jgproject/` session logs from the first JasperGold run | Jasper 2022.09p001 | Drive; rename to `qual-2026-10-28-jasper.zip` |

CI logs are separate: GitHub Actions uploads `logs/` as a run artifact, retained 14 days. Anything a number depends on is copied into an `A-nnn` archive before that window closes.
