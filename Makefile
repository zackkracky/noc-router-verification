SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

VERILATOR ?= verilator
TEST ?= t_smoke
SEED ?= 1
FILELIST ?= filelist.f
BUILD := obj_$(TEST)
LOGDIR := logs

# Non-comment source paths. An empty file list is an error.
SRCS := $(shell sed -e 's/#.*//' -e '/^[[:space:]]*$$/d' $(FILELIST) 2>/dev/null)

.PHONY: help check-sources lint build sim run regress cov formal clean

help:
	@echo "make lint"
	@echo "make sim TEST=t_smoke SEED=1"
	@echo "make clean"

check-sources:
	@test -n "$(SRCS)" || { echo "FAIL: $(FILELIST) contains no source files"; exit 1; }

lint: check-sources
	$(VERILATOR) --lint-only --timing -Wall --top-module $(TEST) -f $(FILELIST)

build: check-sources
	$(VERILATOR) --binary --timing -Wall -Wno-fatal --top-module $(TEST) -f $(FILELIST) --Mdir $(BUILD) -o sim

sim: build
	@mkdir -p $(LOGDIR)
	@$(BUILD)/sim +seed=$(SEED) +verilator+seed+$(SEED) | tee $(LOGDIR)/$(TEST)_s$(SEED).log
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
