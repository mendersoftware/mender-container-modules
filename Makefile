DESTDIR ?= /
prefix ?= $(DESTDIR)
moduledir ?= /usr/share/mender/modules/v3
bindir ?= /usr/bin

# No-op for this project
build:

# "check" is common in many projects so let's have it as an alias
check: test

test:
	@tests/test_docker-compose.sh

coverage:
	@bashcov tests/test_docker-compose.sh

clean:
	rm -rf coverage

install: install-docker-compose

install-generators: install-gen_docker-compose

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

.PHONY: build
.PHONY: check
.PHONY: test
.PHONY: coverage
.PHONY: clean
.PHONY: install
.PHONY: install-generators
.PHONY: install-docker-compose
.PHONY: install-gen_docker-compose
.PHONY: uninstall
.PHONY: uninstall-docker-compose
.PHONY: uninstall-gen_docker-compose
