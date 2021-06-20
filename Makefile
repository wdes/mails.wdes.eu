all: setup test teardown

.PHONY: test

setup:
	$(eval TEMP_DIR := $(shell mktemp -d -t desportes_infra_tests.XXXXXX))
	set -eu
	cp docker-compose.yml dockerl user-patches.sh $(TEMP_DIR)
	cp tests/.env.test1 $(TEMP_DIR)/.env
	cp -rp tests $(TEMP_DIR)
	cp -rp dockers $(TEMP_DIR)
	cp -rp scripts $(TEMP_DIR)
	cp -rp data $(TEMP_DIR)
	@cd $(TEMP_DIR)
	@echo "Running in $(PWD)"
	# Build images
	$(TEMP_DIR)/dockerl build
	# Build images
	$(TEMP_DIR)/dockerl pull
	# Bring down just in case
	$(TEMP_DIR)/dockerl down || echo 'maybe already down'
	# Bring up
	$(TEMP_DIR)/dockerl up -d || $(TEMP_DIR)/dockerl up -d
	# Sleep 10 sec
	@sleep 10
	# Seed ldap test users
	$(TEMP_DIR)/tests/seeding/seed-ldap.sh
	# Build phpunit test suite
	$(TEMP_DIR)/dockerl -f tests/php/docker-compose.yml build

test:
	# Run phpunit test suite
	$(TEMP_DIR)/dockerl -f tests/php/docker-compose.yml up --build --exit-code-from run-tests --abort-on-container-exit

teardown:
	# Stop
	$(TEMP_DIR)/dockerl stop
	# Show logs
	$(TEMP_DIR)/dockerl logs
	# Destroy
	$(TEMP_DIR)/dockerl down
	# Cleanup
	rm -rf $(TEMP_DIR)
