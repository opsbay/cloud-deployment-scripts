.DEFAULT_GOAL := all
.PHONY : all clean prep

# Thanks Stack Overflow http://stackoverflow.com/a/8080530/424301
DIR := $(dir $(lastword $(MAKEFILE_LIST)))
SHELL := /bin/bash

SRC := $(DIR)/src
BUILD := $(DIR)/build

AWS_ACCOUNT_ID := $(shell \
	    . $(DIR)/../../bin/common.sh >/dev/null 2>&1  && \
		    get_aws_account_id)

# Thanks Stack Overflow https://stackoverflow.com/questions/38801796/makefile-set-if-variable-is-empty
ifeq ($(AWS_ACCOUNT_ID),)
     $(error AWS_ACCOUNT_ID not defined)
endif

BUCKET_NAME := unmanaged-codedeploy-$(AWS_ACCOUNT_ID)
BUCKET :=  s3://$(BUCKET_NAME)
MONITOR_DEPLOYMENT := $(DIR)../../bin/monitor-deployment.sh
GET_BUILD_NUMBER := $(DIR)../../bin/get_build_number.sh
get_s3_file=$(2)-$(shell  $(GET_BUILD_NUMBER) $(1)).zip

DEPLOYMENT_APP := tf-testapp-56
DEPLOYMENT_GROUP := qa
#
# Setting IASF=true sets the CodeDeply deployment flag "--ignore-application-stop-failure"
# in order to work around a failed application stop lifecycle event.
IASF := false
ifeq ($(IASF),true)
	IASF_FLAG := --ignore-application-stop-failure
else
	IASF_FLAG :=
endif


SOURCES := $(wildcard $(SRC)/*) $(wildcard $(SRC)/bin/*) $(wildcard $(SRC)/etc/*)

APP_NAME := nodejs

ARCHIVE := $(APP_NAME)
ZIP := $(BUILD)/$(ARCHIVE).zip

clean:
	rm -rf $(BUILD)

prep:
	. $(DIR)../../bin/common.sh \
		&& ensure_awscli
	mkdir -p $(BUILD)

prep_bucket:
	. $(DIR)/../../env.sh && \
	    . $(DIR)../../bin/common.sh \
			&& ensure_awscli
	. $(DIR)/../../env.sh && \
		aws s3 ls $(BUCKET) >/dev/null \
			|| aws s3 mb $(BUCKET)

clean:
	rm -rf $(BUILD)

prep:
	mkdir -p $(BUILD)

prep_bucket:
	. $(DIR)/../../env.sh && \
	    . $(DIR)../../bin/common.sh \
			&& ensure_awscli
	. $(DIR)/../../env.sh && \
		aws s3 ls $(BUCKET) >/dev/null \
			|| aws s3 mb $(BUCKET)

$(ZIP): $(SOURCES)
	$(DIR)/../../bin/vpn-check.sh
	echo $(SOURCES)
	rsync -a $(SRC)/ $(BUILD)
	rsync -a \
		$(DIR)../../bin/aws/ \
		$(BUILD)/bin/
	for f in $(BUILD)/appspec.yml $(BUILD)/bin/common.sh $(BUILD)/etc/nodejs.service; do \
		sed -i.bak -e "s/{{ APP_NAME }}/${APP_NAME}/g" $$f; \
		rm -f $$f.bak; \
	done
	cd $(BUILD) && zip -r ../$(ZIP) *

deploy: prep $(ZIP) s3copy
	. $(DIR)/../../env.sh && \
	    . $(DIR)../../bin/common.sh  && \
			ensure_awscli && \
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


all: prep $(ZIP) prep_bucket s3copy
