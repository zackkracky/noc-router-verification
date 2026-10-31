# Bug log

Three tables, deliberately separate. A reviewer who sees injected mutants and real defects in one table discounts both, so they never share a table: injected mutants live in `docs/RESULTS.md` R2 and are not recorded here at all.

| Table | Holds | Counts toward Phase 2 exit |
|---|---|---|
| 1. Counted bugs (`B-nnn`) | defects found in RTL **already merged to `main`**, caught by regression, a property or formal | yes — floor is 2 by 2027-02-28 |
| 2. Pre-merge findings (`PM-nnn`) | defects caught on a branch before the RTL reached `main` | no |
| 3. Tool portability findings (`TP-nnn`) | code legal in one tool and rejected by another; no functional symptom in simulation | no |

Owner: Aashish (V2). The fix PR author adds the row in the same PR as the fix; a bug fix without a row is sent back.

## Column dictionary

Fixed vocabularies, so four people over four months produce rows the paper can aggregate without rewriting them.

`class` — one of seven bug classes, the row dimension of the paper's detection matrix:

| code | class |
|---|---|
| C1 | protocol / handshake timing |
| C2 | credit accounting |
| C3 | buffer, pointer, occupancy |
| C4 | routing computation |
| C5 | allocation, arbitration, fairness |
| C6 | VC state machine |
| C7 | width, reset, structural, portability |

`technique` — what detected it **first**, the column dimension of the matrix: `COMPILE`, `LINT`, `DIRECTED`, `CR` (constrained-random), `SVA-SIM`, `FORMAL`, `REVIEW`.

`time-to-kill` — cost of detection, measured not estimated:
- simulation: simulated time to the first failing sample, plus the number of seeds tried before one hit it (`95 ns, 1st seed`).
- formal: wall-clock to counterexample or proof (`12 s cex`).
- compile or lint: `n/a (compile)` — detection is immediate and seed-independent.

`catching check` — the property label or test that fails on the old RTL. A fix whose cell is `none` is not finished.

Rules: the seven classes above are provisional until Aashish confirms them against PAPER_PLAN v1.0 — if that document names different classes, these codes change and every row is remapped in one PR. Class assignment on a borderline row is the log owner's call and is stated, not silently reassigned.

## 1. Counted bugs

| id | date | class | technique | time-to-kill | found by | symptom | root cause | fix (PR, commit) | catching check added |
|---|---|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | *none yet* | — | — | — |

Phase 2 exit requires at least 2 rows here by 2027-02-28, found in merged RTL. The count is 0 with 3 of 10 modules merged. The route to rows is the scoreboard (`V08`, `V09`) and the integration tests after `router_top` closes, not more unit tests on blocks that already pass.

## 2. Pre-merge findings

| id | date | class | technique | time-to-kill | found by | symptom | root cause | status | catching check |
|---|---|---|---|---|---|---|---|---|---|
| PM-001 | 2026-10-14 | C1 | SVA-SIM | 95 ns, every seed (1-3) | `P06` `a_p06_credit_iff_dequeue`, bound to `input_fifo` via `bind_all` from branch `aashish/sva-fifo` against `revu/input-fifo`; test then named `t_fifo` (now `tb_fifo`), seeds 1-3; integration check by Arnav | `P06` fails at t=95 ns, the first dequeue, on every seed: `credit_out` rises one cycle after the dequeue | `credit_out` was registered inside `input_fifo` (`credit_out <= do_read`). INTERFACE.md s6 requires it combinational (`credit_out = deq`) and s5.3 puts the single register in `input_port`; with both, credit return took 2 cycles instead of 1. The unit test encoded the same registered timing at line 97, so it passed — the property caught what the test asserted as correct | DONE. `assign credit_out = rst_n && do_read;` in `input_fifo` (PR #13, `1fd956e`; issue #11), plus same-cycle credit checks in the unit test (Revanth) | `P06` |

PM-001 is the cleanest methodology anecdote in the project so far: an independent property contradicted a passing unit test written by the RTL author, which is the separation-of-ownership rule paying for itself. Worth a sentence in the paper's methodology section, cited as pre-merge and not counted.

## 3. Tool portability findings

| id | date | class | technique | time-to-kill | found by | symptom | root cause | status | catching check |
|---|---|---|---|---|---|---|---|---|---|
| TP-001 | 2026-10-28 | C7 | COMPILE | n/a (compile) | JasperGold 2022.09p001 `analyze -sv12` of `formal/fifo.tcl` on `main` `08c0fdf`: 5x VERI-1906 plus 1x VERI-1072, 6 errors. The same lines appear as `xmvlog` NODNTW warnings in every 2026-10-28 `xrun` log, which is how the full affected set was established | Jasper refuses to analyze `input_fifo`, the module is ignored, and the session dies at line 4 of the Tcl. Nothing elaborates, so no property can be proven. Xcelium substitutes `wire` with a warning and simulates correctly; Verilator is silent | Under `` `default_nettype none ``, an ANSI `input logic x` port declares a data type but no net type, so the port kind falls back to the default net type, which is `none` (IEEE 1800-2017 s23.2.2.3) — illegal. Verific enforces it, Xcelium and Verilator are lenient. 25 input ports in 5 files: `input_fifo` 5, `rr_arbiter` 4, `switch_allocator` 4, `fifo_sva` 9, `flit_driver` 3. Outputs are unaffected: `output logic` is a variable | FIX PENDING (patch 2026-10-28, branch `arnav/formal-fifo`): `input wire logic` on all 25 ports; README convention 7 and the module template amended. `make check SEEDS="1 2 3"` 32/32 and `make neg` 2/2 green on Verilator 5.020 after the change, so the fix is regression-neutral. Closes when the fix merges **and** `formal/fifo.tcl` re-runs past `analyze` | `formal/fifo.tcl` `analyze` step; `xrun` logs scanned for NODNTW at each qualification |

TP-001 is not a bug in the router and must never be counted as one. It is still a result: it is the first thing formal found that three years of simulation would not have, and it belongs in the paper only as a one-line observation that cross-tool elaboration catches a class simulation cannot see. Claiming more from it than that invites a reviewer to ask what else was never compiled.
