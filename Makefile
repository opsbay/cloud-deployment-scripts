# Run linters on a wide variety of file types
#
# Syntax:
#     make
#
# Examples:
#
#     # Run all linters
#     make
#
#     # Run just the YAML linter
#     make yaml
#

.DEFAULT_GOAL := all
.phony: prep shellcheck packer-validate yaml all

SHELL := /bin/bash

# Thanks Stack Overflow http://stackoverflow.com/a/8080530/424301
DIR := $(dir $(lastword $(MAKEFILE_LIST)))

# Thanks Stack Overflow http://stackoverflow.com/a/18258352/424301
# This expression has a limitation that it won't work on directories that have spaces
rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))

# Thanks Stack Overflow https://stackoverflow.com/a/4210072/424301
CODEDEPLOY_BASH_SOURCES = $(shell find codedeploy/ -path */build -prune -o -name '*.sh' | grep -v build\$)
YAML_SOURCES = $(shell find $(DIR) -path */build -prune -o -name '*.yml' | grep -v build\$)
BASH_SOURCES := $(CODEDEPLOY_BASH_SOURCES) \
	       $(call rwildcard, $(DIR)terraform, *.sh) \
	       $(call rwildcard, $(DIR)packer/bin, *.sh) \
           $(wildcard $(DIR)*.sh) \
           $(wildcard $(DIR)bin/*.sh)

prep:
	@. $(DIR)bin/common.sh && ensure_awscli
	@$(DIR)bin/install-shellcheck.sh
	@if [[ ! -s $(DIR)env.sh ]]; then \
		cp $(DIR)/env.sh.sample $(DIR)/env.sh; \
	fi

shellcheck:
	@echo "***** Linting bash with ShellCheck"
	@shellcheck $(BASH_SOURCES)

packer-validate:
	@echo "***** Linting packer files"
	@cd $(DIR)packer && make validate

yaml:
	@echo "***** Linting YAML files"
	@docker run -i --rm  \
		-v "$$PWD":/usr/src/myapp -w /usr/src/myapp \
		ruby:2.1 \
		ruby /usr/src/myapp/bin/yamllint.rb $(YAML_SOURCES)

terraform-fmt:
	@echo "***** Checking terraform formatting"
	@. $(DIR)bin/common.sh && ensure_terraform_installed
	@cd $(DIR)terraform \
		&& output=$$(export PATH="$$PATH:$$HOME/tools/" && terraform fmt -write=false -list=true -diff=true) \
		&& if [ -n "$$output" ]; then \
		echo 'Running 'terraform fmt' on the terraform files made these changes:'; \
			echo "$$output"; \
			echo "Run 'terraform fmt' in the terraform directory and commit again"; \
			exit 1; \
		fi

all: prep terraform-fmt shellcheck packer-validate yaml

