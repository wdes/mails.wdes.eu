all: create-temp-env setup test teardown

.PHONY: setup test teardown create-temp-env

create-temp-env:
	mktemp -d -t desportes_infra_tests.XXXXXX > /tmp/current-temp-env

setup:
	$(eval TEMP_DIR ?= $(shell cat /tmp/current-temp-env))
	if [ -z "$(TEMP_DIR)" ]; then echo 'Missing TEMP_DIR env !'; exit 1; fi
	set -eu
	cp docker-compose.yml dockerl user-patches.sh $(TEMP_DIR)
	cp tests/.env.test1 $(TEMP_DIR)/.env
	rm -vf tests/data/acme.sh/*/*.cer
	rm -vf tests/data/acme.sh/*/ca.*
	cp -rp tests $(TEMP_DIR)
	cp -rp scripts $(TEMP_DIR)
	$(TEMP_DIR)/tests/make-certs.sh
	# rxrxrx
	chmod 555 -R tests/data/acme.sh
	@cd $(TEMP_DIR)
	@echo "Running in $(PWD)"
	mkdir -p ./tests/data/phpldapadmin
	openssl req -nodes -x509 -newkey rsa:4096 -keyout ./tests/data/phpldapadmin/phpldapadmin-certificate.key \
    -out ./tests/data/phpldapadmin/phpldapadmin-certificate.crt -days 15 \
    -subj "/C=FR/O=Wdes SAS/OU=Test/CN=phpldapadmin/emailAddress=williamdes@wdes.fr"
	# Build images
	$(TEMP_DIR)/dockerl build
	# Build images
	$(TEMP_DIR)/dockerl pull
	# Bring down just in case
	$(TEMP_DIR)/dockerl down || echo 'maybe already down'
	# Bring up
	$(TEMP_DIR)/dockerl up -d --remove-orphans || $(TEMP_DIR)/dockerl up -d --remove-orphans
	# Sleep 10 sec
	@sleep 10
	# Seed ldap test users
	$(TEMP_DIR)/tests/seeding/seed-ldap.sh
	# Build phpunit test suite
	$(TEMP_DIR)/dockerl -f tests/php/docker-compose.yml build

test:
	$(eval TEMP_DIR ?= $(shell cat /tmp/current-temp-env))
	if [ -z "$(TEMP_DIR)" ]; then echo 'Missing TEMP_DIR env !'; exit 1; fi
	# Run phpunit test suite
	BUILDKIT_PROGRESS=plain $(TEMP_DIR)/dockerl -f tests/php/docker-compose.yml up --build --exit-code-from run-tests --abort-on-container-exit

teardown:
	$(eval TEMP_DIR ?= $(shell cat /tmp/current-temp-env))
	if [ -z "$(TEMP_DIR)" ]; then echo 'Missing TEMP_DIR env !'; exit 1; fi
	# Stop
	$(TEMP_DIR)/dockerl stop
	# Show logs
	$(TEMP_DIR)/dockerl logs
	# Destroy
	$(TEMP_DIR)/dockerl down
	# Cleanup
	rm /tmp/current-temp-env
	sudo rm -rf $(TEMP_DIR)
