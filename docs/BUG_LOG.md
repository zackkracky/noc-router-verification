# Bug log
 
Rules: a bug counts only if it was in merged RTL and caught by regression or a property (TIMELINE 5.6). Every fix PR adds a row here and the property or test that would have caught it.
 
| id | date | found by (test/property, seed) | symptom | root cause | fix PR | catching check added |
|---|---|---|---|---|---|---|
 
## Pre-merge findings

 
| id | date | found by (test/property, seed) | symptom | root cause | status | catching check |
|---|---|---|---|---|---|---|
| PM-001 | 2026-10-14 | P06 `a_p06_credit_iff_dequeue` (aashish/sva-fifo) bound via `bind_all` to `input_fifo` (revu/input-fifo), `t_fifo` seeds 1-3; integration check by Arnav | P06 fails at t=95 ns (first dequeue) on every seed; `credit_out` high one cycle after dequeue | `credit_out` registered inside `input_fifo` (`credit_out <= do_read`). INTERFACE.md s6 requires it combinational (`credit_out = deq`); s5.3 puts the single register in `input_port`. With both, credit return is 2 cycles instead of 1. `t_fifo` line 97 checks the same registered timing, so the unit test passed. | DONE. Fixed: `assign credit_out = rst_n && do_read;` in `input_fifo` (`main`, #11, 1fd956e) and same-cycle credit checks in `t_fifo` (Revanth) | P06 |