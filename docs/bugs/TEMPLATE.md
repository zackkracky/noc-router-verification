# <ID>: <one-line symptom, searchable, no "bug in X">

Copy this file to `docs/bugs/<ID>.md`. Every field is filled or marked `n/a` with a reason. A record with blank fields is not reviewable and the fix PR is sent back.

| Field | Value |
|---|---|
| id | `B-nnn` merged-RTL defect / `PM-nnn` pre-merge / `TP-nnn` tool portability |
| title | one line, matches the heading |
| status | `NEW` → `TRIAGED` → `ASSIGNED` → `FIXED` → `VERIFIED` → `CLOSED`; or `REOPENED` / `DEFERRED` / `DUPLICATE` / `NOT-A-BUG` |
| severity | `S1` data loss, deadlock, protocol violation · `S2` functional error under legal stimulus · `S3` performance, fairness, bound violation without functional error · `S4` cosmetic, lint, portability |
| priority | `P1` blocks a gate · `P2` before phase exit · `P3` when convenient · `P4` backlog |
| class | `C1`-`C7`, see BUG_LOG.md |
| counts toward exit | yes / no, with the reason |
| block | file and module |
| config | `FLIT_WIDTH=`, `NUM_VCS=`, `BUFFER_DEPTH=`, and whether other configs were tried |
| reporter | who found it |
| owner | who fixes it |
| verifier | who confirms the fix — **must not be the owner** |
| found date | ISO |
| found in | commit the failure reproduces on |
| fixed in | PR number and commit |
| closed date | ISO, set by the verifier |
| resolution | `RTL fix` / `TB fix` / `SVA fix` / `spec clarification` / `tool workaround` / `wontfix` |
| found by | `DIRECTED` / `CR` / `SVA-SIM` / `FORMAL` / `LINT` / `COMPILE` / `REVIEW` / `COV-HOLE` |
| phase found | `unit` / `block-integration` / `router-integration` / `mesh` / `fpga` |
| time to detect | sim: failing sample time plus seeds tried · formal: wall-clock to cex · compile: `n/a (compile)` |

## 1. Symptom

Observed against expected. Quote the failure line from the log, not a paraphrase.

## 2. Reproduce

Exact commands, copy-pasteable, with `SIM=`, `SEED=`, and config overrides. Name the signals to look at and the time to look at them. A record nobody else can reproduce is not a record.

## 3. Root cause

The mechanism, not the location. Name the file and line, the construct, and the spec clause it contradicts (`INTERFACE.md sN`). If the spec is silent or wrong, say so — that makes this a spec bug and the resolution changes.

## 4. Fix

What changed and why that fix rather than the alternatives. Alternatives rejected, in one line each.

## 5. Escape analysis

**The field this log exists for.** Three questions, answered separately:

1. Which check already existed that should have caught this, and why did it not fire? ("No check existed" is an answer, and the worst one.)
2. Was anything asserting the wrong behaviour as correct? A test or property that passed on the broken RTL is a second defect and gets its own record.
3. What else in this class could still escape today?

## 6. Collateral sweep

The same mistake elsewhere. Name the pattern, state how the codebase was searched (`grep` used, files inspected), and list every other instance found or state that the sweep was clean. A fix applied only where the failure happened to surface is not finished.

## 7. Closure

| Item | Value |
|---|---|
| catching check added | property label, test name, or coverage point that fails on the pre-fix RTL |
| proof it catches | command and result, run on the old RTL |
| regression after fix | command and result |
| verifier sign-off | name, date, commit verified |

The catching check is mandatory. A fix with `none` here is not closed, whatever the regression says.
