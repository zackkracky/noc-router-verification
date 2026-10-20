SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c
.DEFAULT_GOAL := help

# SIM: verilator | xcelium. No trailing comments on variable lines (make keeps the spaces).
SIM ?= verilator
TEST ?= tb_smoke
SEED ?= 1
WAVES ?= 0
LOGDIR := logs
LOG := $(LOGDIR)/$(TEST)_s$(SEED)_$(SIM).log
BUILD := obj_$(TEST)
XR_LIB := xcelium_$(TEST)

# tb/tests/$(TEST).f if present, else filelist.f; FILELIST= overrides
FILELIST ?= $(firstword $(wildcard tb/tests/$(TEST).f) filelist.f)
SRCS := $(shell sed -e 's/#.*//' -e '/^[[:space:]]*$$/d' $(FILELIST) 2>/dev/null)

VL := verilator --timing --assert --timescale 1ns/1ps --top-module $(TEST) -f $(FILELIST)
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

# make check: every tb/tests/*.f, lint once, sim per seed; summary in logs/summary.txt
TESTS ?= $(sort $(basename $(notdir $(wildcard tb/tests/*.f))))
SEEDS ?= 1

.PHONY: help check-sources lint lint-rtl build sim run waves check regress cov formal clean

help:
	@echo "make lint     TEST=tb_noc_pkg                Verilator -Wall, warnings fatal"
	@echo "make lint-rtl FILE=rtl/back/rr_arbiter.sv   one RTL file, no testbench"
	@echo "make build    TEST=tb_noc_pkg                compile only"
	@echo "make sim      TEST=tb_noc_pkg SEED=1         build + run, require TEST PASSED (run = alias)"
	@echo "make sim      TEST=tb_noc_pkg WAVES=1        also dump logs/<test>_s<seed>.fst"
	@echo "make waves    TEST=tb_noc_pkg SEED=1         open that dump in GTKWave"
	@echo "make sim      TEST=tb_noc_pkg SIM=xcelium    same test on xrun (VCD if WAVES=1)"
	@echo "make check    SEEDS=\"1 2 3\"                lint + sim every tb/tests/*.f, summary in logs/summary.txt (CI runs this)"
	@echo "make regress | cov | formal                Phase 2"
	@echo "make clean"

check-sources:
	@test -n "$(SRCS)" || { echo "FAIL: $(FILELIST) has no sources"; exit 1; }

lint: check-sources
ifeq ($(SIM),xcelium)
	@mkdir -p $(LOGDIR)
	$(XR) -elaborate -l $(LOGDIR)/$(TEST)_lint_xcelium.log
else
	@mkdir -p $(LOGDIR)
	$(VL) --lint-only -Wall 2>&1 | tee $(LOGDIR)/$(TEST)_lint_verilator.log
endif

build: check-sources
	@mkdir -p $(LOGDIR)
ifeq ($(SIM),xcelium)
	$(XR) -elaborate -l $(LOGDIR)/$(TEST)_build_xcelium.log
else
	$(VL) --binary -Wall -Wno-fatal $(VL_TRACE) --Mdir $(BUILD) -o sim 2>&1 | tee $(LOGDIR)/$(TEST)_build_verilator.log
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

# lint each test once, sim each seed; logs stay in logs/, one line per result in logs/summary.txt
check:
	@mkdir -p $(LOGDIR); rm -f $(LOGDIR)/summary.txt; fail=0; \
	test -n "$(TESTS)" || { echo "FAIL: no tb/tests/*.f found"; exit 1; }; \
	for t in $(TESTS); do \
	  if $(MAKE) --no-print-directory lint TEST=$$t SIM=$(SIM) >/dev/null 2>&1; then r=PASS; else r=FAIL; fail=1; fi; \
	  printf '%-20s %-8s %s  %s\n' "$$t" lint "$$r" "$(LOGDIR)/$${t}_lint_$(SIM).log" | tee -a $(LOGDIR)/summary.txt; \
	  for s in $(SEEDS); do \
	    if $(MAKE) --no-print-directory sim TEST=$$t SEED=$$s SIM=$(SIM) WAVES=$(WAVES) >/dev/null 2>&1; then r=PASS; else r=FAIL; fail=1; fi; \
	    printf '%-20s %-8s %s  %s\n' "$$t" "seed=$$s" "$$r" "$(LOGDIR)/$${t}_s$${s}_$(SIM).log" | tee -a $(LOGDIR)/summary.txt; \
	  done; \
	done; \
	exit $$fail

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