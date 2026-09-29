export LARZSCRIPT_PATH := lib

.PHONY: check plan test packages install-test clean

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

## real install verification: dpkg -i the built larzscript .deb (needs root -
## run under sudo/a container, not the proot LarzOS app env, where sudo is
## broken) and prove `larzscript pkg install <name>` genuinely works against
## the packaged binary, not a curled-in-CI one that happens to share the same
## $PATH name. This is the exact end-to-end path larzos-linux#10 broke
## silently (the deb shipped without larzpkg.lz) with nothing in CI to catch
## it - invoke /usr/bin/larzscript explicitly so this can't accidentally pass
## against a different binary earlier in $PATH.
install-test: packages
	sudo dpkg -i dist/larzscript_*.deb
	test -f /usr/share/larzscript/larzpkg.lz
	rm -rf /tmp/larzos-install-test && mkdir -p /tmp/larzos-install-test
	cd /tmp/larzos-install-test && /usr/bin/larzscript pkg install mathx
	test -f "$$HOME/.larzscript/lib/mathx.lz"
	printf 'import "mathx" as m\nlet x = m.mean([1,2,3])\nprint("install-test-ok")\n' > /tmp/larzos-install-test/check.lz
	/usr/bin/larzscript /tmp/larzos-install-test/check.lz | grep -q install-test-ok
	@echo "PASS install-test"

clean:
	rm -rf dist
