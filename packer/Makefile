.DEFAULT_GOAL := all
.PHONY : prereq build validate post all

# Thanks Stack Overflow http://stackoverflow.com/a/8080530/424301
DIR := $(dir $(lastword $(MAKEFILE_LIST)))
SHELL := /bin/bash

PACKER_JSON ?= machines/all.json

source_env := . $(DIR)../env.sh

prereq:
	$(DIR)bin/run-packer.sh prereq

validate:
	$(DIR)bin/run-packer.sh validate

prep:
	$(DIR)bin/run-packer.sh prep

build: prereq validate prep
	$(DIR)bin/run-packer.sh build

post:
	$(DIR)bin/run-packer.sh post

all: build post

