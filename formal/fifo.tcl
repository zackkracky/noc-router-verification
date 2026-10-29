# fifo.tcl: JasperGold run of fifo_sva on input_fifo; P01/P02 become assumes via +define+FORMAL
# usage (lab): jg -batch formal/fifo.tcl   (from repo root)
clear -all

analyze -sv12 +define+FORMAL \
  rtl/front/input_fifo.sv \
  tb/sva/fifo_sva.sv \
  tb/sva/bind_all.sv                    ;# same sources as tb/tests/tb_fifo.f, minus the test

elaborate -top input_fifo               ;# bind_all attaches u_fifo_sva; defaults WIDTH=64 DEPTH=4

clock clk
reset -expression {!rst_n}              ;# sync active-low, matches disable iff (!rst_n)

set_prove_time_limit 600s
prove -all                              ;# P03-P06 asserts under P01/P02 assumes

report -summary                         ;# paste into docs/RESULTS.md with commit hash and this command
