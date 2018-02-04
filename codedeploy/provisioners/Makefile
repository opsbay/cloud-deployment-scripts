.DEFAULT_GOAL := all
.PHONY : all clean prep prep_bucket deploy s3copy

# One of the great strengths of using Make for this is that it can avoid re-building code
# when it is not needed. This Makefile takes pains to enumerate the build products and
# avoids building and uploading a new archive if there have been no changes.

# Thanks Stack Overflow http://stackoverflow.com/a/8080530/424301
DIR := $(dir $(lastword $(MAKEFILE_LIST)))
SHELL := /bin/bash
SRC := $(DIR)src
ARCHIVE_DIR := $(DIR)build/archive
ARTIFACTS := $(ARCHIVE_DIR)/artifacts
APP_NAME := provisioners

ARTIFACT_BASE_URL := https://artifactory01.hobsonshighered.com/artifactory/naviance-stable/com/naviance/api/provisioner

application_data_version :=
application_data_name := application-data-provisioner
APPLICATION_DATA_URL:= $(ARTIFACT_BASE_URL)/$(application_data_name)/$(application_data_version)/$(application_data_name)-$(application_data_version).jar

college_core_version :=
college_core_name := college-core-provisioner
COLLEGE_CORE_URL := $(ARTIFACT_BASE_URL)/$(college_core_name)/$(college_core_version)/$(college_core_name)-$(college_core_version).jar

college_destination_core_version :=
college_destination_core_name := college-destination-core-provisioner
COLLEGE_DESTINATION_CORE_URL := $(ARTIFACT_BASE_URL)/$(college_destination_core_name)/$(college_destination_core_version)/$(college_destination_core_name)-$(college_destination_core_version).jar

school_core_name := school-core-provisioner
school_core_version :=
SCHOOL_CORE_URL := $(ARTIFACT_BASE_URL)/$(school_core_name)/$(school_core_version)/$(school_core_name)-$(school_core_version).jar

BUILD := $(DIR)build
AWS_ACCOUNT_ID := $(shell \
	. $(DIR)/../../bin/common.sh >/dev/null 2>&1  && \
	get_aws_account_id)
# Thanks Stack Overflow https://stackoverflow.com/questions/38801796/makefile-set-if-variable-is-empty
ifeq ($(AWS_ACCOUNT_ID),)
	$(error AWS_ACCOUNT_ID not defined)
endif

BUCKET_NAME := unmanaged-codedeploy-$(AWS_ACCOUNT_ID)
BUCKET := s3://$(BUCKET_NAME)
MONITOR_DEPLOYMENT := $(DIR)../../bin/monitor-deployment.sh
GET_BUILD_NUMBER := $(DIR)../../bin/get_build_number.sh
get_s3_file=$(2)-$(shell  $(GET_BUILD_NUMBER) $(1)).zip
DEPLOYMENT_APP := tf-${APP_NAME}
DEPLOYMENT_GROUP := qa
SOURCES := $(wildcard $(SRC)/*) $(wildcard $(SRC)/bin/*)
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

$(ZIP): $(SOURCES)
	$(DIR)/../../bin/vpn-check.sh

	curl -o $(ARTIFACTS)/$(application_data_name).jar --basic --user ${ARTIFACTORY_DEV_USERNAME}:${ARTIFACTORY_DEV_PASSWORD} $(APPLICATION_DATA_URL);
	curl -o $(ARTIFACTS)/$(college_core_name).jar --basic --user ${ARTIFACTORY_DEV_USERNAME}:${ARTIFACTORY_DEV_PASSWORD} $(COLLEGE_CORE_URL);
	curl -o $(ARTIFACTS)/$(college_destination_core_name).jar --basic --user ${ARTIFACTORY_DEV_USERNAME}:${ARTIFACTORY_DEV_PASSWORD} $(COLLEGE_DESTINATION_CORE_URL);
	curl -o $(ARTIFACTS)/$(school_core_name).jar --basic --user ${ARTIFACTORY_DEV_USERNAME}:${ARTIFACTORY_DEV_PASSWORD} $(SCHOOL_CORE_URL);

	rsync -a $(SRC)/ $(ARCHIVE_DIR)/
	rsync -a \
		$(DIR)../../bin/aws/ \
		$(DIR)../../bin/manage-splunk.sh \
		$(DIR)../../bin/newrelic/ \
		$(ARCHIVE_DIR)/bin/
	for f in $(ARCHIVE_DIR)/appspec.yml $(ARCHIVE_DIR)/bin/common.sh; do \
		sed -i.bak -e "s/{{ APP_NAME }}/${APP_NAME}/g" $$f \
			&& rm -f $$f.bak; \
	done
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
    aws s3 ls $(BUCKET)/$(APP_NAME)/$$S3_FILE \
	    && echo "File in S3 is already up to date" \
		|| aws s3 cp $(1) $(BUCKET)/$(APP_NAME)/$$S3_FILE

s3copy: $(ZIP) prep_bucket
	. $(DIR)../../bin/common.sh \
		&& ensure_awscli \
	. $(DIR)/../../env.sh && \
		$(call s3_copy,$(ZIP),$(ARCHIVE))

all: prep $(ZIP) s3copy
