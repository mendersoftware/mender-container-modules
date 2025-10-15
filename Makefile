DESTDIR ?= /
prefix ?= $(DESTDIR)
moduledir ?= /usr/share/mender/modules/v3

# No-op for this project
build:

install: install-docker-compose

install-docker-compose:
	install -d -m 755 $(prefix)$(moduledir)
	install -m 755 src/docker-compose $(prefix)$(moduledir)/

uninstall: uninstall-docker-compose

uninstall-docker-compose:
	rm -f src/docker-compose $(prefix)$(moduledir)/docker-compose
	-rmdir $(prefix)$(moduledir)

.PHONY: build
.PHONY: install
.PHONY: install-docker-compose
.PHONY: uninstall
.PHONY: uninstall-docker-compose
