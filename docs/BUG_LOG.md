# Bug log

Index and metrics. One record per defect in `docs/bugs/<ID>.md`, written from `docs/bugs/TEMPLATE.md`. This file holds no narrative: if a cell needs a sentence, the sentence belongs in the record.

Owner: Aashish (V2). The fix PR author writes the record and updates the index in the same PR. A fix without a record is sent back.

Injected mutants are **not** here. They live in `docs/RESULTS.md` R2, because a reviewer who finds injected mutants and real defects in one table discounts both.

## Index

| id | title | sev | pri | class | block | status | found by | found | closed | record |
|---|---|---|---|---|---|---|---|---|---|---|
| PM-001 | `credit_out` asserts one cycle late | S2 | P1 | C1 | `input_fifo` | CLOSED | SVA-SIM | 2026-10-14 | 2026-10-14 | [PM-001](bugs/PM-001.md) |
| PM-002 | `t_fifo` checked `credit_out` one cycle late and passed PM-001 | S2 | P1 | C1 | `t_fifo` (test of `input_fifo`) | FIXED | SVA-SIM | 2026-10-14 | — | [PM-002](bugs/PM-002.md) |
| TP-001 | `input logic` illegal under `default_nettype none` | S4 | P1 | C7 | 5 files | FIXED | COMPILE | 2026-10-28 | — | [TP-001](bugs/TP-001.md) |
| PM-003 | every checker seeded from its `SEED` parameter alone, so the seeded regression ran one stimulus five times | S3 | P1 | C7 | `tb_crossbar`, `tb_output_unit` | FIXED | REVIEW | 2026-11-03 | — | [PM-003](bugs/PM-003.md) |

ID prefixes: `B-nnn` a defect found in RTL already merged to `main`; `PM-nnn` caught on a branch before merge; `TP-nnn` a cross-tool portability finding with no functional symptom. Only `B-nnn` counts toward the Phase 2 exit floor. The prefix is part of the citation and never changes after the record is pushed — reclassification changes the `counts toward exit` field in the record, not the ID.

## Metrics

Counts are from the index and are recomputed when a row changes, not estimated.

| Measure | Value as of 2026-11-04 |
|---|---|
| Counted bugs (`B-nnn`) in merged RTL | **0** — floor is 2 by 2027-02-28 |
| Open (not CLOSED) | 3 (PM-002 awaiting verifier sign-off; TP-001 awaiting a clean `analyze`; PM-003 awaiting a catching check, see below) |
| Pre-merge catches | 3 (PM-001 and PM-002 are one event; PM-003 is a second) |
| Portability findings | 1 |
| Reopened | 0 |
| Records with no catching check | 1 (PM-003 — a seed defect produces no failing run; rule 3 below cannot be met without a new check) |
| Escapes — defects that passed an existing check | 1 (PM-001, passed its own unit test) |

By detection technique — the column dimension of the paper's matrix:

| technique | count |
|---|---|
| SVA-SIM | 2 |
| COMPILE | 1 |
| REVIEW | 1 |
| DIRECTED, CR, FORMAL, LINT, COV-HOLE | 0 |

Discovery by week. A project with no bug curve has no convergence evidence, so this starts now rather than in March:

| week beginning | found | closed | open at end |
|---|---|---|---|
| 2026-10-12 | 2 | 1 | 1 |
| 2026-10-26 | 1 | 0 | 2 |
| 2026-11-02 | 1 | 0 | 3 |

PM-003 is the one record that does not satisfy rule 3. A seed defect produces no failing run, so no
catching check can be written that fails on the pre-fix source; the manual two-seed probe in the
record is the only evidence. Closing it needs either an automated two-seed comparison in `make
check` or an explicit team decision to accept the probe for this class. Until then it stays open and
is counted here as an exception rather than waived.

Reading of the current numbers: 0 counted bugs with 3 of 10 modules merged is expected, not reassuring. Unit tests on blocks that already pass will not produce counted bugs; the scoreboard (`V08`, `V09`) and integration after `router_top` closes will. If the count is still 0 at the end of January, the Phase 2 exit is at risk and the response is to bring integration forward, not to lower the floor.

## Field dictionary

`severity` — impact if it reached silicon, independent of how hard it is to fix:

| code | meaning |
|---|---|
| S1 | flit loss or corruption, deadlock, link protocol violation |
| S2 | functional error under legal stimulus; wrong route, wrong grant, credit leak |
| S3 | performance, fairness or bound violation with no functional error |
| S4 | cosmetic, lint, portability, documentation |

`priority` — order of work, set at triage and independent of severity. `P1` blocks a gate, `P2` before phase exit, `P3` when convenient, `P4` backlog. An S4 can be P1: TP-001 is cosmetic in simulation and blocks the entire formal plan.

`class` — the row dimension of the paper's detection matrix:

| code | class |
|---|---|
| C1 | protocol / handshake timing |
| C2 | credit accounting |
| C3 | buffer, pointer, occupancy |
| C4 | routing computation |
| C5 | allocation, arbitration, fairness |
| C6 | VC state machine |
| C7 | width, reset, structural, portability |

Provisional until Aashish confirms them against PAPER_PLAN v1.0. If that document names different classes these codes are remapped in one PR, which is why the class lives in a field and not in the ID.

`found by` — what detected it first: `DIRECTED`, `CR`, `SVA-SIM`, `FORMAL`, `LINT`, `COMPILE`, `REVIEW`, `COV-HOLE`.

`phase found` — `unit`, `block-integration`, `router-integration`, `mesh`, `fpga`. Bugs found late cost more; the distribution is a result in its own right.

`time to detect` — simulation: failing sample time plus seeds tried. Formal: wall-clock to counterexample. Compile or lint: `n/a (compile)`. Recorded when the row is created; reconstructing it from logs in March is not possible.

## Workflow

```
NEW -> TRIAGED -> ASSIGNED -> FIXED -> VERIFIED -> CLOSED
                                 |
                                 +-> REOPENED -> ASSIGNED
TRIAGED -> DEFERRED | DUPLICATE | NOT-A-BUG
```

Rules that are not negotiable:

1. **The verifier is never the owner.** The person who wrote the fix does not close the record. This is the same independence rule as cross-written assertions, applied to closure.
2. `FIXED` means the fix is merged. `CLOSED` means someone else reproduced the original failure, confirmed the fix removes it, and signed section 7 with a date and commit.
3. Every record carries a catching check that fails on the pre-fix RTL, with the command that demonstrates it. `none` is not a value.
4. A test or property that passed on the broken RTL is a second defect. It gets its own record, not a footnote in the first.
5. `NOT-A-BUG` and `DUPLICATE` records are kept, never deleted. A deleted record is an undocumented decision, and the index is also the audit trail for the paper.
