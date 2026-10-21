# Deliberate illegal empty-read requests: do not bind environment constraints P01/P02.
# The RTL's existing safety assertions remain enabled; production RTL is unchanged.
rtl/pkg/noc_pkg.sv
rtl/front/input_fifo.sv
tb/tests/tb_fifo_empty_read.sv
