SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c
.DEFAULT_GOAL := help

# SIM: verilator | xcelium. No trailing comments on variable lines (make keeps the spaces).
SIM ?= verilator
TEST ?= t_smoke
SEED ?= 1
WAVES ?= 0
LOGDIR := logs
LOG := $(LOGDIR)/$(TEST)_s$(SEED)_$(SIM).log
BUILD := obj_$(TEST)
XR_LIB := xcelium_$(TEST)

# tb/tests/$(TEST).f if present, else filelist.f; FILELIST= overrides
FILELIST ?= $(firstword $(wildcard tb/tests/$(TEST).f) filelist.f)
SRCS := $(shell sed -e 's/#.*//' -e '/^[[:space:]]*$$/d' $(FILELIST) 2>/dev/null)

VL := verilator --timing --timescale 1ns/1ps --top-module $(TEST) -f $(FILELIST)
XR := xrun -sv -timescale 1ns/1ps -top $(TEST) -f $(FILELIST) -svseed $(SEED) \
      -xmlibdirname $(XR_LIB) -nocopyright

ifeq ($(WAVES),1)
ifeq ($(SIM),xcelium)
WAVE := $(LOGDIR)/$(TEST)_s$(SEED).vcd
XR += -access +r
else
WAVE := $(LOGDIR)/$(TEST)_s$(SEED).fst
VL_TRACE := --trace-fst
endif
PLUS := +dumpfile=$(WAVE)
endif

.PHONY: help check-sources lint lint-rtl build sim run waves regress cov formal clean

help:
	@echo "make lint     TEST=tb_noc_pkg                Verilator -Wall, warnings fatal"
	@echo "make lint-rtl FILE=rtl/back/rr_arbiter.sv   one RTL file, no testbench"
	@echo "make build    TEST=tb_noc_pkg                compile only"
	@echo "make sim      TEST=tb_noc_pkg SEED=1         build + run, require TEST PASSED (run = alias)"
	@echo "make sim      TEST=tb_noc_pkg WAVES=1        also dump logs/<test>_s<seed>.fst"
	@echo "make waves    TEST=tb_noc_pkg SEED=1         open that dump in GTKWave"
	@echo "make sim      TEST=tb_noc_pkg SIM=xcelium    same test on xrun (VCD if WAVES=1)"
	@echo "make regress | cov | formal                Phase 2"
	@echo "make clean"

check-sources:
	@test -n "$(SRCS)" || { echo "FAIL: $(FILELIST) has no sources"; exit 1; }

lint: check-sources
ifeq ($(SIM),xcelium)
	@mkdir -p $(LOGDIR)
	$(XR) -elaborate -l $(LOGDIR)/$(TEST)_lint_xcelium.log
else
	$(VL) --lint-only -Wall
endif

build: check-sources
	@mkdir -p $(LOGDIR)
ifeq ($(SIM),xcelium)
	$(XR) -elaborate -l $(LOGDIR)/$(TEST)_build_xcelium.log
else
	$(VL) --binary -Wall -Wno-fatal $(VL_TRACE) --Mdir $(BUILD) -o sim
endif

sim: build
ifeq ($(SIM),xcelium)
	$(XR) -R -l $(LOG) $(PLUS)
else
	$(BUILD)/sim +seed=$(SEED) +verilator+seed+$(SEED) +verilator+rand+reset+2 $(PLUS) | tee $(LOG)
endif
	@grep -qx "TEST PASSED" $(LOG) || { echo "FAIL: $(TEST) did not print TEST PASSED"; exit 1; }

run: sim

waves:
	@f=$$(ls -t $(LOGDIR)/$(TEST)_s$(SEED).fst $(LOGDIR)/$(TEST)_s$(SEED).vcd 2>/dev/null | head -1); \
	 test -n "$$f" || { echo "no dump: make sim TEST=$(TEST) SEED=$(SEED) WAVES=1 first"; exit 1; }; \
	 gtkwave "$$f" $(wildcard tb/tests/waves/$(TEST).gtkw) &

regress:
	@echo "not yet: Phase 2"

cov:
	@echo "not yet: Phase 2"

formal:
	@echo "not yet: Phase 2"

clean:
	rm -rf obj_* xcelium_* logs xrun.history xrun.key *.shm

# Lint one RTL file standalone. Package compiled first so imports resolve.
PKG ?= rtl/pkg/noc_pkg.sv
lint-rtl:
	@test -n "$(FILE)" || { echo "usage: make lint-rtl FILE=rtl/<path>.sv"; exit 1; }
	@test -f "$(FILE)" || { echo "no such file: $(FILE)"; exit 1; }
	@test "$(FILE)" != "$(PKG)" || { echo "package has no top module; use: make lint TEST=tb_noc_pkg"; exit 1; }
	verilator --lint-only -Wall --timescale 1ns/1ps \
	  $(wildcard $(PKG)) $(FILE)