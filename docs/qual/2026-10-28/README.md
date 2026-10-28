# Lab tool qualification, 2026-10-28

Evidence for the `Q-00x` rows in `docs/RESULTS.md` R1. Run on the college lab machine against `main` at `08c0fdf`.

| File | Backs | Contents |
|---|---|---|
| `tool-versions.txt` | all rows | tool version strings and the commit under test |
| `xcelium-summary.txt` | `Q-001` | `logs/summary.txt` verbatim: 8 tests x (lint + seeds 1-5), 48/48 PASS |
| `xcelium-clocking-probe.excerpt.log` | `Q-002` | the `FLIT_IF_CLOCKING` probe result lines for all four `(F,V,D)` configs |
| `jasper-fifo-analyze.excerpt.log` | `Q-003` | the failing `analyze` of `formal/fifo.tcl`: VERI-1906 x5, VERI-1072, exit 1. Root cause is TP-001 in `docs/BUG_LOG.md` |

These are excerpts, deliberately. Raw tool logs are **not** committed:

- Cadence logs carry a confidentiality and trade-secret banner. This repository is public.
- They embed absolute lab paths including an account identifier, which the README Process section bans from commits.
- The remainder is Cadence startup boilerplate that backs no result.

Redactions in the excerpt files: lab scratch paths are `<lab-scratch>`, tool install paths are `<tool-install>`. Nothing else is altered, no PASS/FAIL line is removed, and the failing run is kept in full.

Full logs live in the off-repo archives named in `docs/RESULTS.md` under Raw log archive (`A-001`, `A-002`). Anyone re-deriving a number pulls those; anyone auditing a claim reads the excerpt here.

Reproduce (lab machine, from repo root; the lab shell behaves as csh, so use `|& tee` not `2>&1 | tee`):

```
make check SEEDS="1 2 3 4 5" SIM=xcelium
make sim TEST=tb_fifo_link SEED=1 SIM=xcelium XRFLAGS="+define+FLIT_IF_CLOCKING"
jg -batch formal/fifo.tcl
```
