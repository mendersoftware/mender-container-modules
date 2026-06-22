DESTDIR ?= /
prefix ?= $(DESTDIR)
moduledir ?= /usr/share/mender/modules/v3

build: src/docker-compose

src/docker-compose: src/docker-compose.in src/docker-compose_base.sh
	m4 --prefix-builtins --include=src src/docker-compose.in > $@
	chmod a+x $@

# "check" is common in many projects so let's have it as an alias
check: test

test: build
	@tests/test_docker-compose.sh

coverage:
	@bashcov tests/test_docker-compose.sh

clean:
	rm -rf coverage

install: build install-docker-compose

install-docker-compose:
	install -d -m 755 $(prefix)$(moduledir)
	install -m 755 src/docker-compose $(prefix)$(moduledir)/

uninstall: uninstall-docker-compose

uninstall-docker-compose:
	rm -f src/docker-compose $(prefix)$(moduledir)/docker-compose
	-rmdir $(prefix)$(moduledir)

# Tell Make to automatically delete corrupted output files on failure
.DELETE_ON_ERROR:

.PHONY: build
.PHONY: check
.PHONY: test
.PHONY: coverage
.PHONY: clean
.PHONY: install
.PHONY: install-docker-compose
.PHONY: uninstall
.PHONY: uninstall-docker-compose
