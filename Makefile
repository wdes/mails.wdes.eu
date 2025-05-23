IMAGE_TAG ?= docker-mailserver
TEST_ADDR ?= mailserver
# All: linux/amd64,linux/arm64,linux/riscv64,linux/ppc64le,linux/s390x,linux/386,linux/mips64le,linux/mips64,linux/arm/v7,linux/arm/v6
PLATFORM ?= linux/amd64

ACTION ?= load
PROGRESS_MODE ?= plain

ACME_DOMAIN = emails.mail-server.intranet
DKIM_DOMAIN = mail-server.intranet

.PHONY: docker-test run-test cleanup-test test

all: docker-test

docker-test: test

test: setup-test run-test cleanup-test
setup: setup-test

check-env:
	$(eval TEMP_DIR ?= $(shell cat /tmp/current-temp-env))
	if [ -z "$(TEMP_DIR)" ]; then echo 'Missing TEMP_DIR env !'; exit 1; fi

run-test: check-env
	# Run phpunit test suite
	IMAGE_TAG="${IMAGE_TAG}" \
	$(TEMP_DIR)/dockerl -f $(TEMP_DIR)/tests/php/compose-sut.yml up --exit-code-from=sut --abort-on-container-exit

cleanup-test: check-env
	@echo "Stopping and removing the container"
	IMAGE_TAG="${IMAGE_TAG}" \
	$(TEMP_DIR)/dockerl -f $(TEMP_DIR)/tests/compose-tests.yml down
	sudo rm -rf $(TEMP_DIR)
	rm -v /tmp/current-temp-env

create-temp-env:
	mktemp -d -t desportes_infra_tests.XXXXXX > /tmp/current-temp-env

setup-test-files: check-env
	set -eu
	cp -rv compose.yml dockerl user-patches.sh rspamd internal-dns $(TEMP_DIR)
	cp tests/.env.test1 $(TEMP_DIR)/.env
	sed -i 's|<rootdir>|$(TEMP_DIR)|' $(TEMP_DIR)/.env
	rm -vf $(TEMP_DIR)/tests/data/acme.sh/*/*.csr
	rm -vf $(TEMP_DIR)/tests/data/acme.sh/*/*.cer
	rm -vf $(TEMP_DIR)/tests/data/acme.sh/*/ca.*
	mkdir $(TEMP_DIR)/tests
	mkdir -p $(TEMP_DIR)/tests/data/acme.sh/$(ACME_DOMAIN)_ecc
	cp tests/make-certs.sh $(TEMP_DIR)/tests/
	cp -rp tests/php $(TEMP_DIR)/tests/
	cp -rp tests/seeding $(TEMP_DIR)/tests/
	cp -v tests/compose-tests.yml $(TEMP_DIR)/tests/compose-tests.yml
	cp -v tests/data/acme.sh/$(ACME_DOMAIN)_ecc/*.*nf $(TEMP_DIR)/tests/data/acme.sh/$(ACME_DOMAIN)_ecc

	# Generate opendkim keys
	mkdir -p $(TEMP_DIR)/tests/data/mailconfig/opendkim/keys/$(DKIM_DOMAIN)/
	openssl genrsa -out $(TEMP_DIR)/tests/data/mailconfig/opendkim/keys/$(DKIM_DOMAIN)/mail.private 2048
	openssl rsa -in $(TEMP_DIR)/tests/data/mailconfig/opendkim/keys/$(DKIM_DOMAIN)/mail.private -pubout -out $(TEMP_DIR)/tests/data/mailconfig/opendkim/keys/$(DKIM_DOMAIN)/mail.txt

	chmod 777 -R $(TEMP_DIR)/tests/data/acme.sh
	$(TEMP_DIR)/tests/make-certs.sh
	# rxrxrx
	chmod 555 -R $(TEMP_DIR)/tests/data/acme.sh

setup-test: create-temp-env check-env setup-test-files
	set -eu
	# Build images
	$(TEMP_DIR)/dockerl -f $(TEMP_DIR)/tests/compose-tests.yml build
	# Build images
	$(TEMP_DIR)/dockerl -f $(TEMP_DIR)/tests/compose-tests.yml pull
	# Bring down just in case
	$(TEMP_DIR)/dockerl -f $(TEMP_DIR)/tests/compose-tests.yml down || echo 'maybe already down'
	# Bring up
	$(TEMP_DIR)/dockerl -f $(TEMP_DIR)/tests/compose-tests.yml up -d --remove-orphans || $(TEMP_DIR)/dockerl -f $(TEMP_DIR)/tests/compose-tests.yml up -d --remove-orphans
	# Sleep 10 sec
	@sleep 10
	# Seed ldap test users
	$(TEMP_DIR)/tests/seeding/seed-ldap.sh
	# Print all containers
	$(TEMP_DIR)/dockerl -f $(TEMP_DIR)/tests/compose-tests.yml ps -a
	# Print mailserver container logs
	$(TEMP_DIR)/dockerl -f $(TEMP_DIR)/tests/compose-tests.yml logs mailserver
	# Check DNS works
	$(TEMP_DIR)/dockerl -f $(TEMP_DIR)/tests/compose-tests.yml exec mailserver dig emails.mail-server.intranet +short
	# Build phpunit test suite
	$(TEMP_DIR)/dockerl -f $(TEMP_DIR)/tests/php/compose-sut.yml build
