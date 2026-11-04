# RESULTS
 
Every number in the paper traces to a row here: the commit it was produced on, the exact command, the tool and version, and where the raw log lives. No number enters a draft without a row. Raw tool logs are never committed: they carry vendor confidentiality banners and absolute lab paths. Sanitized excerpts that back a specific row live in `docs/qual/<date>/`; the full logs are archived off-repo and named in the Raw log archive table.
 
Conventions:
- `commit` is the full-tree commit the run was made on, never a branch name.
- `command` is copy-pasteable from the repo root.
- Seeds are simulator-specific: Verilator and Xcelium do not generate the same traffic from the same seed number. Always quote `SIM=` with the seed.
- A run that failed is still a row. Deleting failures is how a measurement study loses its credibility.
- A mutation row names every mutant as an exact before/after source line. A row that does not is not auditable and does not enter the paper.
## R1. Tool qualification
 
| id | date | tool + version | commit | command | result | raw log |
|---|---|---|---|---|---|---|
| Q-001 | 2026-10-28 | Xcelium `xrun` 22.09-s003 | `08c0fdf` | `make check SEEDS="1 2 3 4 5" SIM=xcelium` | 48/48 PASS: 8 tests x (lint + seeds 1-5) | in repo: `docs/qual/2026-10-28/xcelium-summary.txt`; full set A-001 |
| Q-002 | 2026-10-28 | Xcelium `xrun` 22.09-s003 | `08c0fdf` | `make sim TEST=tb_fifo_link SEED=1 SIM=xcelium XRFLAGS=+define+FLIT_IF_CLOCKING` | PASS on all four `(F,V,D)` configs; `@(link.cb)` accepted, so the opt-in clocking blocks stay. Elaboration reports 18 clocking items, confirming the define was active. The original probe was run by hand: the Makefile had no define passthrough until `XRFLAGS` was added in the same PR, and the command above is the reproducible form | in repo: `docs/qual/2026-10-28/xcelium-clocking-probe.excerpt.log` |
| Q-003 | 2026-10-28 | JasperGold (Jasper Apps) 2022.09p001 | `08c0fdf` | `jg -batch formal/fifo.tcl` | **FAIL at `analyze`**: VERI-1906 x5 on `input_fifo` input ports, VERI-1072 module ignored; 0 properties elaborated, 0 proven. Cause TP-001 (`docs/BUG_LOG.md`) | in repo: `docs/qual/2026-10-28/jasper-fifo-analyze.excerpt.log` |
| Q-004 | 2026-10-28 | Verilator 5.020 | `08c0fdf` + TP-001 patch | `make check SEEDS="1 2 3"` then `make neg` | 32/32 PASS, `make neg` 2/2 PASS: the TP-001 fix is regression-neutral. Run on an unmerged patch, so the commit column is not a full-tree commit; Q-005 repeats it on the merged fix | not archived (reproducible locally) |
| Q-005 | 2026-11-03 | Verilator 5.020 | `907433f` | `make check SEEDS="1 2 3"` then `make neg` | 32/32 PASS, `make neg` 2/2 PASS on the merged TP-001 fix (#21) | not archived (reproducible locally) |
 
Open: P01-P06 have **no** JasperGold proof. The TP-001 fix merged in #21 (`907433f`); the first proof row lands when `formal/fifo.tcl` is re-run on it at the next lab session. Until then no draft, slide or application may say the FIFO properties are formally proven.
 
## R2. Unit-level mutation kills
 
Injected mutants only. Real defects live in `docs/BUG_LOG.md` and `docs/bugs/`; reviewers conflate the two if they share a table.
 
| id | date | block | mutants | killed | killed by | commit | command |
|---|---|---|---|---|---|---|---|
| M-001 | 2026-11-03 | `rr_arbiter` | 6 injected, 1 equivalent, 5 non-equivalent | 5/5 | `tb_rr_arbiter` reference model | `edce4cc` | `make sim TEST=tb_rr_arbiter SEED=1` per mutant |
| M-002 | 2026-11-03 | `switch_allocator` | 7 injected, 0 equivalent | 7/7 | `tb_switch_allocator` reference model + s7 contract checks | `08c0fdf` | `make sim TEST=tb_switch_allocator SEED=1` per mutant |
| M-003 | 2026-10-14 | `input_fifo` (SVA-only, TB checks non-fatal) | 9 injected, 2 equivalent, 7 non-equivalent | 4/7 | P06 (registered `credit_out`), P04 (no-increment), P05 (no-decrement), P01/P02 (`full` at DEPTH-1) | `3ea9243` | `make build TEST=tb_fifo` then `obj_tb_fifo/sim +sva_only` |
| M-004 | 2026-11-04 | `crossbar` | 5 injected, 0 equivalent | 5/5 | `tb_crossbar` reference checks at four (FLIT_WIDTH, NUM_VCS) points | `b2be922` | `make sim TEST=tb_crossbar SEED=1` per mutant |
| M-005 | 2026-11-04 | `output_unit` | 7 injected, 0 equivalent | 7/7 | `tb_output_unit` exact-count model at four (F,V,D) points | `b2be922` | `make sim TEST=tb_output_unit SEED=1` per mutant |
 
`M-001` note: the no-wrap mutant (`ptr_q <= grant_idx + 1` without the `N-1` check) is **equivalent at the ports** and is excluded from the denominator; only an internal `ptr_q < N` property distinguishes it (R03).
 
`M-003` note: two of the nine are equivalent under P01/P02 and are excluded from the denominator, as M-001 does. The named survivors are the simultaneous read/write count change (no bound hold property; `input_fifo.count_holds_correctly` exists inline) and a stuck `rd_ptr`/`wr_ptr` (data path, scoreboard). Both are assigned slots in `tb/sva/PLAN.md`.
 
`M-004` mutants, `rtl/back/crossbar.sv`. Each is a single-line substitution; the gate is the
`TEST PASSED` grep in `make sim`, so a surviving mutant would show as a passing run.

| id | class | before | after |
|---|---|---|---|
| XB-M1 | wrong source index | `issue_flit[o] \|= xb_flit[p] &` | `issue_flit[o] \|= xb_flit[o] &` |
| XB-M2 | transposed select | `xb_flit[p] & {FLIT_WIDTH{xbar_sel[o][p]}}` | `xb_flit[p] & {FLIT_WIDTH{xbar_sel[p][o]}}` |
| XB-M3 | VC path dropped | `issue_vc[o]   \|= xb_vc[p]   & {VC_W{xbar_sel[o][p]}};` | `issue_vc[o]   \|= '0;` |
| XB-M4 | VC wrong index | `issue_vc[o]   \|= xb_vc[p]   &` | `issue_vc[o]   \|= xb_vc[o]   &` |
| XB-M5 | stale output | `issue_flit[o] = '0;` | `issue_flit[o] = xb_flit[0];` |

`M-005` mutants, `rtl/back/output_unit.sv`:

| id | class | before | after |
|---|---|---|---|
| OU-M1 | off-by-one init | `ocredit_count[v] <= CNT_W'(BUFFER_DEPTH);` | `ocredit_count[v] <= CNT_W'(BUFFER_DEPTH-1);` |
| OU-M2 | missing hold | `default: ocredit_count[v] <= ocredit_count[v];` | `default: ocredit_count[v] <= ({ret[v], send[v]} == 2'b11) ? ocredit_count[v] - CNT_W'(1) : ocredit_count[v];` |
| OU-M3 | off-by-one threshold | `ocredit_avail[v] = (ocredit_count[v] != '0);` | `ocredit_avail[v] = (ocredit_count[v] > CNT_W'(1));` |
| OU-M4 | missing reset | `out_flit_valid <= 1'b0;` (reset branch) | `out_flit_valid <= 1'b1;` |
| OU-M5 | dropped qualifier | `ret[v]           = out_credit_valid && (out_credit_vc == VC_W'(v));` | `ret[v]           = out_credit_valid;` |
| OU-M6 | register repeats flit | `out_flit_valid <= issue;` | `out_flit_valid <= issue \| out_flit_valid;` |
| OU-M7 | debits every VC | `send[v]          = issue            && (issue_vc      == VC_W'(v));` | `send[v]          = issue;` |

M-004 and M-005 are the first R2 rows that satisfy the rule below: every mutant is recorded as an
exact source change, so any reviewer can reproduce the run. M-001, M-002 and M-003 cannot be, and
stay provisional until they are re-injected and recorded. Each mutant was applied alone to a clean
tree and reverted before the next.

Both rows are **Verilator-only**. Neither `tb_crossbar` nor `tb_output_unit` has been elaborated
under `xrun`: Q-001 covers the eight tests that existed on 2026-10-28 and not these two. By the
30 Oct entry condition they are not lab-qualified, and no paper sentence may present them as
cross-tool results until a lab session adds the Q row.

These are pilot measurements, not the paper's matrix. The paper's 37 mutants in 7 classes are injected only after the property plan is frozen.
 
**Audit, 2026-11-03.** Every R2 and R3 row was first dated before the commit it cites existed: `edce4cc` was created 2026-10-21 00:47 IST (M-001, D-003 dated 19 Oct), `3ea9243` 2026-10-21 03:00 IST (M-003 dated 14 Oct), `08c0fdf` 2026-10-25 23:38 IST (M-002, D-001, D-002 dated 21 Oct). Those runs were made on pre-squash branch commits that the squash merge replaced, which breaks the first convention above.
 
- **D-001, D-002 and D-003 were re-run** on the cited commits on 2026-11-03 with Verilator 5.020 and gave identical values to the last digit. Their dates now record that re-run; the first measurements are in SYNC.md.
- **M-001, M-002 and M-003 cannot be re-run**, because no mutant was recorded as a source change anywhere in the repository. The `command` column names how a mutant was run but not what it was. Their dates are the audit date to make clear the original run date is unverifiable, and the rows stay **provisional**: they do not enter a draft, a slide or an application until the mutants are re-injected and recorded.
- **M-003's count was wrong.** It read 9 injected and 5 killed. The detailed record (STATE.md, `tb/sva/fifo_sva.sv` row) names exactly four killed mutants: P06, P04, P05, and `full` at DEPTH-1 caught by P01/P02. No evidence in the repository supports a fifth. The row now reads 4 of 7 non-equivalent. The nine only reconcile if the stuck-pointer survivor is two mutants (`rd_ptr` and `wr_ptr` separately) rather than one, and the record does not say which; this cannot be settled without the mutants, which is the same gap as above.
- From M-004 on, every R2 row lists its mutants as exact before/after source lines.
## R3. Measured design characteristics
 
| id | date | metric | value | commit | command |
|---|---|---|---|---|---|
| D-001 | 2026-11-03 | `switch_allocator` starvation max wait, `NUM_VCS` 1/2/3/4 at seed 1 | 4 / 9 / 13 / 14 cycles against bound `N_SA = NUM_VCS*NUM_PORTS-1` = 4 / 9 / 14 / 19 | `08c0fdf` | `make sim TEST=tb_switch_allocator SEED=1` |
| D-002 | 2026-11-03 | `switch_allocator` allocation efficiency (grants / maximum bipartite matching), `NUM_VCS` 1/2/3/4 | 1.0000 / 0.9136 / 0.8345 / 0.7795 | `08c0fdf` | `make sim TEST=tb_switch_allocator SEED=1` |
| D-003 | 2026-11-03 | `rr_arbiter` max wait under a held request, `N` = 1,2,3,4,5,8 | `N-1` in every case (bound tight) | `edce4cc` | `make sim TEST=tb_rr_arbiter SEED=1` |
 
`D-001` is **measured, not proven**, and tight only at `NUM_VCS <= 2`. Any paper sentence about the bound says "measured"; the proof is formal work in Phase 2.
 
Dates are the 2026-11-03 re-run on the cited commits. The values are unchanged from the first measurement; only the provenance was corrected.
 
## Raw log archive
 
Logs stay out of git. Each archive is named here so a row can be audited.
 
| id | date | contents | tool | where |
|---|---|---|---|---|
| A-001 | 2026-10-28 | full `logs/` from the lab Xcelium session: per-test lint, seeds 1-5, build logs, `summary.txt`, version stamps (50 files, 252 KB) | xrun 22.09-s003 | Drive; rename to `qual-2026-10-28-xcelium.zip` |
| A-002 | 2026-10-28 | `fifo_jg.log` and `jgproject/` session logs from the first JasperGold run | Jasper 2022.09p001 | Drive; rename to `qual-2026-10-28-jasper.zip` |
 
CI logs are separate: GitHub Actions uploads `logs/` as a run artifact, retained 14 days. Anything a number depends on is copied into an `A-nnn` archive before that window closes.
 
