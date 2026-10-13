SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

SIM   ?= verilator
TEST  ?= t_smoke
SEED  ?= 1
WAVES ?= 0
LOGDIR := logs
LOG    := $(LOGDIR)/$(TEST)_s$(SEED)_$(SIM).log

# tb/tests/$(TEST).f if present, else filelist.f; FILELIST= overrides
FILELIST ?= $(firstword $(wildcard tb/tests/$(TEST).f) filelist.f)
SRCS := $(shell sed -e 's/#.*//' -e '/^[[:space:]]*$$/d' $(FILELIST) 2>/dev/null)

VL := verilator --timing --timescale 1ns/1ps --top-module $(TEST) -f $(FILELIST)
XR := xrun -sv -timescale 1ns/1ps -top $(TEST) -f $(FILELIST) -svseed $(SEED) \
      -xmlibdirname xcelium_$(TEST) -nocopyright -l $(LOG)

ifeq ($(WAVES),1)
  ifeq ($(SIM),xcelium)
    WAVE := $(LOGDIR)/$(TEST)_s$(SEED).vcd
    XR   += -access +r
  else
    WAVE := $(LOGDIR)/$(TEST)_s$(SEED).fst
    VL   += --trace-fst
  endif
  PLUS := +dumpfile=$(WAVE)
endif

.PHONY: lint sim waves clean check-sources

check-sources:
	@test -n "$(SRCS)" || { echo "FAIL: $(FILELIST) has no sources"; exit 1; }

lint: check-sources
ifeq ($(SIM),xcelium)
	@mkdir -p $(LOGDIR); xrun -sv -timescale 1ns/1ps -top $(TEST) -f $(FILELIST) -xmlibdirname xcelium_$(TEST) -nocopyright -elaborate -l $(LOGDIR)/$(TEST)_lint_xcelium.log
else
	$(VL) --lint-only -Wall
endif

sim: check-sources
	@mkdir -p $(LOGDIR)
ifeq ($(SIM),xcelium)
	$(XR) $(PLUS)
else
	$(VL) --binary -Wall -Wno-fatal --Mdir obj_$(TEST) -o sim
	obj_$(TEST)/sim +verilator+seed+$(SEED) +verilator+rand+reset+2 $(PLUS) | tee $(LOG)
endif
	@grep -qx "TEST PASSED" $(LOG) || { echo "FAIL: $(TEST)"; exit 1; }

waves:
	gtkwave $$(ls -t $(LOGDIR)/$(TEST)_s$(SEED).{fst,vcd} 2>/dev/null | head -1) &

clean:
	rm -rf obj_* xcelium_* logs xrun.history xrun.key *.shm