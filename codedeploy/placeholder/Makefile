.DEFAULT_GOAL := all
.PHONY : all clean prep prep_bucket s3copy deploy

# Thanks Stack Overflow http://stackoverflow.com/a/8080530/424301
DIR := $(dir $(lastword $(MAKEFILE_LIST)))
SHELL := /bin/bash
SRC := $(DIR)/src
BUILD := $(DIR)/build
PHP_BUILD_VERSION_FILE=$(ARCHIVE_DIR)/etc/phpversion.txt
PHP_BUILD_VERSION_DIR=$(ARCHIVE_DIR)/etc
APP_NAME := placeholder
ARCHIVE_DIR := $(DIR)build/archive
MONITOR_DEPLOYMENT := $(DIR)../../bin/monitor-deployment.sh
GET_BUILD_NUMBER := $(DIR)../../bin/get_build_number.sh
get_s3_file=$(2)-$(shell  $(GET_BUILD_NUMBER) $(1)).zip
AWS_ACCOUNT_ID := $(shell \
	. $(DIR)/../../bin/common.sh >/dev/null 2>&1  && \
	get_aws_account_id)

# Thanks Stack Overflow https://stackoverflow.com/questions/38801796/makefile-set-if-variable-is-empty
ifeq ($(AWS_ACCOUNT_ID),)
     $(error AWS_ACCOUNT_ID not defined)
endif

CODEDEPLOY_BUCKET_ACCOUNT := 253369875794
BUCKET_NAME := unmanaged-codedeploy-$(CODEDEPLOY_BUCKET_ACCOUNT)
BUCKET := s3://$(BUCKET_NAME)

# This determines what version of PHP to deploy.
# Possible values are '5.6' '56' '53' '5.3'. This gets parsed.
# TODO: 5.3 - feature/aws-migration
# TODO: 5.6 - feature/php-56-upgrade (feature/NAWS-320-prod-frontend-succeed56 for now)
PHP_VERSION := 56

# Do not override this directly
PHP_VERSION_CODE := $(shell $(DIR)../../bin/get-php-version.sh $(PHP_VERSION))

# Other values that work: tf-testapp-56 tf-testapp-ubuntu
DEPLOYMENT_APP := tf-testapp-$(PHP_VERSION_CODE)
DEPLOYMENT_GROUP := qa

# Setting IASF=true sets the CodeDeply deployment flag "--ignore-application-stop-failure"
# in order to work around a failed application stop lifecycle event.
IASF := false
ifeq ($(IASF),true)
	IASF_FLAG := --ignore-application-stop-failure
else
	IASF_FLAG :=
endif

# Thanks Stack Overflow http://stackoverflow.com/a/18258352/424301
# This expression has a limitation that it won't work on directories that have spaces
rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))

SOURCES := $(call rwildcard, $(SRC), *)

GET_BUILD_NUMBER := $(DIR)../../bin/get_build_number.sh

APP_NAME := placeholder

ARCHIVE1 := $(APP_NAME)-01
ARCHIVE2 := $(APP_NAME)-02

ZIP1 := $(BUILD)/$(ARCHIVE1).zip
ZIP2 := $(BUILD)/$(ARCHIVE2).zip

clean:
	rm -rf $(BUILD)

prep:
	mkdir -p $(ARCHIVE_DIR)

prep_bucket:
	. $(DIR)/../../env.sh && \
	    . $(DIR)../../bin/common.sh \
			&& ensure_awscli
	. $(DIR)/../../env.sh && \
		aws s3 ls $(BUCKET) >/dev/null \
			|| aws s3 mb $(BUCKET)

$(ZIP1): $(SOURCES)
	rsync -a $(SRC)/ $(ARCHIVE_DIR)
	rsync -a \
		$(DIR)../../bin/aws/ \
		$(DIR)../../bin/manage-splunk.sh \
		$(ARCHIVE_DIR)/bin/
	for f in $(ARCHIVE_DIR)/appspec.yml $(ARCHIVE_DIR)/bin/common.sh $(ARCHIVE_DIR)/etc/*.json; do \
		sed -i.bak -e "s/{{ APP_NAME }}/${APP_NAME}/g" $$f; \
		rm -f $$f.bak; \
	done
	mkdir -p $(PHP_BUILD_VERSION_DIR)
	echo $(PHP_VERSION_CODE) > $(PHP_BUILD_VERSION_FILE)
	. $(DIR)../../bin/common.sh \
		&& ensure_zip
	cd $(ARCHIVE_DIR) \
		&& zip -r ../../$(ZIP1) *

$(ZIP2): $(SOURCES) $(ZIP1)
	sed -i.bak -e 's/Version 1/Version 2/' $(ARCHIVE_DIR)/www/index.html
	rm -f $(ARCHIVE_DIR)/www/index.html.bak
	cd $(ARCHIVE_DIR) \
		&& zip -r ../../$(ZIP2) *

# This uses a trick from https://stackoverflow.com/a/11474509/424301 to scroll the screen up
deploy: prep $(ZIP1) $(ZIP2) s3copy
	. $(DIR)/../../env.sh && \
	    . $(DIR)../../bin/common.sh \
			&& ensure_awscli
	. $(DIR)/../../env.sh && \
		S3_FILE=$(call get_s3_file,$(ZIP1),$(ARCHIVE1)) && \
        deployment=$$(aws deploy create-deployment \
		        $(IASF_FLAG) \
                --application-name $(DEPLOYMENT_APP) \
                --s3-location bucket=$(BUCKET_NAME),key=$(APP_NAME)/$$S3_FILE,bundleType=zip \
                --deployment-group-name $(DEPLOYMENT_GROUP) \
                --output text)  && \
        $(MONITOR_DEPLOYMENT) $$deployment

s3_copy = S3_FILE=$(call get_s3_file,$(1),$(2)) && \
			S3_PHP_BUILD_VERSION_FILE=$(BUCKET)/$(APP_NAME)/$${S3_FILE}.php-version.txt && \
            aws s3 ls $(BUCKET)/$(APP_NAME)/$$S3_FILE \
            && echo "File in S3 is already up to date" \
            || (aws s3 cp $(1) $(BUCKET)/$(APP_NAME)/$$S3_FILE && \
				aws s3 cp $(PHP_BUILD_VERSION_FILE) $$S3_PHP_BUILD_VERSION_FILE)


s3copy: $(ZIP1) $(ZIP2) prep_bucket
	. $(DIR)../../bin/common.sh \
		&& ensure_awscli \
	. $(DIR)/../../env.sh && \
		$(call s3_copy,$(ZIP1),$(ARCHIVE1))
	. $(DIR)/../../env.sh && \
		$(call s3_copy,$(ZIP2),$(ARCHIVE2))

all: prep $(ZIP1) $(ZIP2) s3copy
