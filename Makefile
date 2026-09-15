DESTDIR ?= /
prefix ?= $(DESTDIR)
moduledir ?= /usr/share/mender/modules/v3
bindir ?= /usr/bin

build: src/docker-compose src/gen_docker-compose

src/docker-compose: src/docker-compose.in src/docker-compose_base.sh
	m4 --prefix-builtins --include=src src/docker-compose.in > $@
	chmod a+x $@

src/gen_docker-compose: src/gen_docker-compose.in src/gen_docker-compose_base.sh
	m4 --prefix-builtins --include=src src/gen_docker-compose.in > $@
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

install-generators: build install-gen_docker-compose

install-docker-compose:
	install -d -m 755 $(prefix)$(moduledir)
	install -m 755 src/docker-compose $(prefix)$(moduledir)/

install-gen_docker-compose:
	install -d -m 755 $(prefix)$(bindir)
	install -m 755 src/gen_docker-compose $(prefix)$(bindir)/

uninstall: uninstall-docker-compose

uninstall-generators: uninstall-gen_docker-compose

uninstall-docker-compose:
	rm -f src/docker-compose $(prefix)$(moduledir)/docker-compose
	-rmdir $(prefix)$(moduledir)

uninstall-gen_docker-compose:
	rm -f $(prefix)$(bindir)/gen_docker-compose
	-rmdir $(prefix)$(bindir)

# Tell Make to automatically delete corrupted output files on failure
.DELETE_ON_ERROR:

.PHONY: build
.PHONY: check
.PHONY: test
.PHONY: coverage
.PHONY: clean
.PHONY: install
.PHONY: install-docker-compose
.PHONY: install-generators
.PHONY: install-gen_docker-compose
.PHONY: uninstall
.PHONY: uninstall-docker-compose
.PHONY: uninstall-generators
.PHONY: uninstall-gen_docker-compose
