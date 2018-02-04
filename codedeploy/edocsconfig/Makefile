.DEFAULT_GOAL := all
.PHONY : all build clean distclean prep prep_bucket deploy s3copy

# One of the gret strengths of using Make for this is that it can avoid re-building code
# when it is not needed. This Makefile takes pains to enumerate the build products and
# avoids building and uploading a new archive if there have been no changes.

# Thanks Stack Overflow http://stackoverflow.com/a/8080530/424301
DIR := $(dir $(lastword $(MAKEFILE_LIST)))
SHELL := /bin/bash

SRC := $(DIR)/src
ARCHIVE_DIR := $(DIR)build/archive
ARTIFACTS := $(ARCHIVE_DIR)/artifacts
APP_NAME := edocsconfig
SERVER_USER := edocsapi
APP_REPO := naviance-service-manager
SERVICE := management-service
UPSTREAM_BUILD := ../../../$(APP_REPO)
UPSTREAM_BUILD_LIBS := $(UPSTREAM_BUILD)/$(SERVICE)/build/libs/
SKIP_RUN := false
APP_PATH := /opt/$(APP_NAME)
GRADLE_TARGETS := $(SERVICE):clean $(SERVICE):build
GRADLE_AUTH := -PhobsonsRepositoryUsername=${ARTIFACTORY_DEV_USERNAME} -PhobsonsRepositoryPassword=${ARTIFACTORY_DEV_PASSWORD}
BUILD := $(DIR)/build
ARTIFACTORY_REFERENCE :=

AWS_ACCOUNT_ID := $(shell \
	. $(DIR)/../../bin/common.sh >/dev/null 2>&1  && \
	get_aws_account_id)

# Thanks Stack Overflow https://stackoverflow.com/questions/38801796/makefile-set-if-variable-is-empty
ifeq ($(AWS_ACCOUNT_ID),)
	$(error AWS_ACCOUNT_ID not defined)
endif

BUCKET_NAME :=  unmanaged-codedeploy-$(AWS_ACCOUNT_ID)
BUCKET :=  s3://$(BUCKET_NAME)
MONITOR_DEPLOYMENT := $(DIR)../../bin/monitor-deployment.sh
GET_BUILD_NUMBER := $(DIR)../../bin/get_build_number.sh
get_s3_file=$(2)-$(shell  $(GET_BUILD_NUMBER) $(1)).zip
JAR_NAME := $(SERVICE).jar
CONTAINER_TAG_NAME := $(APP_NAME)-codedeploy:latest
DOCKERFILE_NAME := Dockerfile
DEPLOYMENT_APP := tf-${DEPLOYMENT_APP}
DEPLOYMENT_GROUP := qa

SOURCES := $(wildcard $(SRC)/*) $(wildcard $(SRC)/bin/*) $(wildcard $(SRC)/etc/*)
ARCHIVE := $(APP_NAME)
ZIP := $(BUILD)/$(ARCHIVE).zip

clean:
	rm -rf $(BUILD)

prep:
	mkdir -p $(ARTIFACTS)

prep_bucket:
	. $(DIR)/../../env.sh && \
	    . $(DIR)../../bin/common.sh \
			&& ensure_awscli
	. $(DIR)/../../env.sh && \
		aws s3 ls $(BUCKET) >/dev/null \
			|| aws s3 mb $(BUCKET)

build:
	$(DIR)/../../bin/vpn-check.sh
	if [[ -z "$(ARTIFACTORY_REFERENCE)" ]]; then \
		docker build -f=$(DOCKERFILE_NAME) . -t $(CONTAINER_TAG_NAME) \
		&& echo "Docker built OK with $(DOCKERFILE_NAME)"; \
	else \
		echo "No need to build docker, we are using artifactory"; \
	fi

$(ZIP):
	$(DIR)/../../bin/vpn-check.sh
	if [[ -z "$(ARTIFACTORY_REFERENCE)" ]]; then \
		if [ $(SKIP_RUN) = false ]; then \
			cd $(UPSTREAM_BUILD) && \
			if [[ -z "${BUILD_NUMBER}" ]]; then \
				docker run --rm -v $$(pwd):/$(APP_PATH) -v ~/.gradle:/root/.gradle $(CONTAINER_TAG_NAME) /bin/bash -c \
				"/bin/bash --login -c '\
					cd $(APP_PATH) && \
					export GRADLE_USER_HOME="~/.gradle" && \
					JAVA_HOME=/usr/java/default/ ./gradlew $(GRADLE_TARGETS)'"; \
			else \
				docker run --rm -v $$(pwd):/$(APP_PATH) $(CONTAINER_TAG_NAME) /bin/bash -c \
				"/bin/bash --login -c '\
					cd $(APP_PATH) && \
					export GRADLE_USER_HOME="~/.gradle" && \
					JAVA_HOME=/usr/java/default/ ./gradlew $(GRADLE_AUTH) $(GRADLE_TARGETS)'"; \
			fi; \
		fi \
	else \
		mkdir -p $(UPSTREAM_BUILD_LIBS) && \
		curl -o $(UPSTREAM_BUILD_LIBS)${JAR_NAME} --basic --user ${ARTIFACTORY_DEV_USERNAME}:${ARTIFACTORY_DEV_PASSWORD} $(ARTIFACTORY_REFERENCE); \
	fi
	rsync -a $(SRC)/ $(ARCHIVE_DIR)/
	rsync -a \
		$(DIR)../../bin/aws/ \
		$(DIR)../../bin/manage-splunk.sh \
		$(DIR)../../bin/newrelic/ \
		$(ARCHIVE_DIR)/scripts/
	for f in $(ARCHIVE_DIR)/appspec.yml $(ARCHIVE_DIR)/scripts/common.sh; do \
		sed -i.bak -e "s/{{ APP_NAME }}/${APP_NAME}/g;s/{{ JAR_NAME }}/${JAR_NAME}/g;s/{{ SERVER_USER }}/${SERVER_USER}/g" $$f \
			&& rm -f $$f.bak; \
	done
	cp -a \
		$$(find $(UPSTREAM_BUILD_LIBS) -name '$(JAR_BASE)*.jar' | head -1 ) \
		$(ARTIFACTS)/$(JAR_NAME)
	. $(DIR)../../bin/common.sh \
		&& ensure_zip
	cd $(ARCHIVE_DIR) \
		&& zip -q -r ../../$(ZIP) *

deploy: prep $(ZIP) s3copy
	. $(DIR)/../../env.sh && \
	S3_FILE=$(call get_s3_file,$(ZIP),$(ARCHIVE)) && \
	deployment=$$(aws deploy create-deployment \
        $(IASF_FLAG) \
		--application-name $(DEPLOYMENT_APP) \
		--s3-location bucket=$(BUCKET_NAME),key=$(APP_NAME)/$$S3_FILE,bundleType=zip \
		--deployment-group-name $(DEPLOYMENT_GROUP) \
		--output text)  && \
	$(MONITOR_DEPLOYMENT) $$deployment

s3_copy = S3_FILE=$(call get_s3_file,$(1),$(2)) && \
    aws s3 ls $(BUCKET)/$(APP_NODE)/$$S3_FILE \
	    && echo "File in S3 is already up to date" \
		|| aws s3 cp $(1) $(BUCKET)/$(APP_NAME)/$$S3_FILE

s3copy: $(ZIP) prep_bucket
	. $(DIR)../../bin/common.sh \
		&& ensure_awscli \
	. $(DIR)/../../env.sh && \
		$(call s3_copy,$(ZIP),$(ARCHIVE))

all: prep build $(ZIP) s3copy
