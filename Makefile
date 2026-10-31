NIM ?= nim
NIMFLAGS ?= --hints:off --usenimcache

.PHONY: test

test:
	$(NIM) c -r $(NIMFLAGS) tests/core_checks.nim
	$(NIM) c -r $(NIMFLAGS) tests/units_checks.nim
