# -----------------------------------------------------------------------------
# NoC router verification - Makefile (V1)
#   make help                     list targets
#   make lint                     static check of every file in filelist.f
#   make build                    compile RTL + testbench
#   make run TEST=smoke SEED=3    build + run one test
#   make regress                  run every test in TESTS
#   make clean
# -----------------------------------------------------------------------------
SHELL    := /bin/bash
.SHELLFLAGS := -o pipefail -c

VERILATOR ?= verilator
TOP       ?= tb_top
TEST      ?= smoke
SEED      ?= 1
TESTS     ?= smoke
FILELIST  ?= filelist.f
BUILD     ?= build
LOGDIR    := $(BUILD)/logs

# Warnings do not fail the build for now. Remove -Wno-fatal once the RTL is clean.
VFLAGS    := --timing -Wall -Wno-fatal --top-module $(TOP) -f $(FILELIST)

# Source files listed in filelist.f (comments and blank lines ignored)
SRCS := $(shell grep -vE '^\s*(\#|$$)' $(FILELIST) 2>/dev/null)

.PHONY: help lint build run regress clean

help:
	@echo "targets: lint build run regress clean"
	@echo "vars   : TEST=$(TEST) SEED=$(SEED) TOP=$(TOP) FILELIST=$(FILELIST)"

lint:
	if [ -z "$(SRCS)" ]; then echo "[skip] $(FILELIST) has no sources yet"; exit 0; fi; \
	$(VERILATOR) --lint-only $(VFLAGS)

build:
	if [ -z "$(SRCS)" ]; then echo "[skip] $(FILELIST) has no sources yet"; exit 0; fi; \
	$(VERILATOR) --binary $(VFLAGS) --Mdir $(BUILD) -o sim

run: build
	if [ -z "$(SRCS)" ]; then echo "[skip] nothing to run"; exit 0; fi; \
	mkdir -p $(LOGDIR); \
	$(BUILD)/sim +TEST=$(TEST) +verilator+seed+$(SEED) +verilator+rand+reset+2 \
	| tee $(LOGDIR)/$(TEST)_s$(SEED).log; \
	grep -q "TEST PASSED" $(LOGDIR)/$(TEST)_s$(SEED).log \
	|| { echo "FAIL: $(TEST) seed $(SEED)"; exit 1; }

regress: build
	if [ -z "$(SRCS)" ]; then echo "[skip] nothing to run"; exit 0; fi; \
	fail=0; \
	for t in $(TESTS); do \
	$(MAKE) --no-print-directory run TEST=$$t SEED=$(SEED) || fail=1; \
	done; \
	exit $$fail

clean:
	rm -rf $(BUILD)
