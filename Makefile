export LARZSCRIPT_PATH := lib

.PHONY: check plan test packages clean

## syntax-check every Larzscript file (use in CI)
check:
	@ok=1; \
	for f in $$(find bin lib packages examples -name '*.lz') bin/larz-system bin/larz-pkg; do \
	  larzscript --check "$$f" >/dev/null 2>&1 && echo "ok   $$f" || { echo "FAIL $$f"; ok=0; }; \
	done; \
	[ $$ok -eq 1 ]

## show the plan for the reference spec
plan:
	larzscript bin/larz-system plan examples/system.lz

## functional smoke test - plans must succeed and report pending changes
test: check
	larzscript bin/larz-system plan examples/system.lz | grep -q 'change(s) pending'
	larzscript bin/larz-system plan examples/server.lz | grep -q 'change(s) pending'
	larzscript bin/larz-pkg show packages/larz-desktop | grep -q larz-desktop
	@echo "PASS"

## build every distro package into dist/
packages:
	@for d in packages/*/; do larzscript bin/larz-pkg deb "$$d"; done

clean:
	rm -rf dist
