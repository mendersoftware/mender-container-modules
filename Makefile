DESTDIR ?= /
prefix ?= $(DESTDIR)
moduledir ?= /usr/share/mender/modules/v3

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

install-docker-compose:
	install -d -m 755 $(prefix)$(moduledir)
	install -m 755 src/docker-compose $(prefix)$(moduledir)/

uninstall: uninstall-docker-compose

uninstall-docker-compose:
	rm -f src/docker-compose $(prefix)$(moduledir)/docker-compose
	-rmdir $(prefix)$(moduledir)

.PHONY: build
.PHONY: check
.PHONY: test
.PHONY: coverage
.PHONY: clean
.PHONY: install
.PHONY: install-docker-compose
.PHONY: uninstall
.PHONY: uninstall-docker-compose
