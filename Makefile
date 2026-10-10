
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

VERILATOR ?= verilator
TEST ?= t_smoke
SEED ?= 1
FILELIST ?= $(if $(filter t_fifo,$(TEST)),filelist_fifo.f,filelist.f)
BUILD := obj_$(TEST)
LOGDIR := logs

SRCS := $(shell sed -e 's/#.*//' -e '/^[[:space:]]*$$/d' $(FILELIST) 2>/dev/null)
VFLAGS := --timing -Wall -Wno-fatal --trace --top-module $(TEST) -f $(FILELIST)

.PHONY: help check-sources lint build sim run regress cov formal clean

help:
	@echo "make lint TEST=t_smoke"
	@echo "make sim TEST=t_smoke SEED=1"
	@echo "make lint TEST=t_fifo"
	@echo "make sim TEST=t_fifo SEED=1"
	@echo "make clean"

check-sources:
	@test -n "$(SRCS)" || { echo "FAIL: $(FILELIST) contains no source files"; exit 1; }

lint: check-sources
	$(VERILATOR) --lint-only --timing -Wall -Wno-fatal --top-module $(TEST) -f $(FILELIST)

build: check-sources
	$(VERILATOR) --binary $(VFLAGS) --Mdir $(BUILD) -o sim

sim: build
	@mkdir -p $(LOGDIR)
	@set -o pipefail; $(BUILD)/sim +seed=$(SEED) +verilator+seed+$(SEED) +verilator+rand+reset+2 | tee $(LOGDIR)/$(TEST)_s$(SEED).log
	@grep -qx "TEST PASSED" $(LOGDIR)/$(TEST)_s$(SEED).log || { echo "FAIL: $(TEST) did not print TEST PASSED"; exit 1; }

run: sim

regress:
	@echo "not yet: Phase 2"

cov:
	@echo "not yet: Phase 2"

formal:
	@echo "not yet: Phase 2"

clean:
	rm -rf obj_* logs
