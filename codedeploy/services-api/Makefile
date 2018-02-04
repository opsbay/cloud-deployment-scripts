DEFAULT_GOAL := all
.PHONY : all clean prep build prep_bucket s3copy deploy mobileApi navianceAuthBridge

# Thanks Stack Overflow http://stackoverflow.com/a/8080530/424301
DIR := $(dir $(lastword $(MAKEFILE_LIST)))
SHELL := /bin/bash

SRC := $(DIR)/src
BUILD := $(DIR)/build
ARCHIVE_DIR := $(DIR)build/archive
PHP_BUILD_VERSION_FILE=$(ARCHIVE_DIR)/etc/phpversion.txt
PHP_BUILD_VERSION_DIR=$(ARCHIVE_DIR)/etc
APP_NAME := servicesapi
APP_PATH := opt/app
ARCHIVE := $(APP_NAME)
ZIP := $(BUILD)/$(ARCHIVE).zip
GRADLE_TARGETS := test bundle -x integrationTest
PHP_VERSION := 56
PHP_VERSION_CODE := $(shell $(DIR)../../bin/get-php-version.sh $(PHP_VERSION))
ifeq ($(PHP_VERSION_CODE),56)
        DOCKERFILE_NAME := Dockerfile
else
        DOCKERFILE_NAME := Dockerfile.ci
endif
PHP_TARGETS := alias php='/usr/bin/php$(PHP_VERSION)' && ./build.sh
PHP_TARGETS_V2 := cd /opt/app/build-deploy && sh build.sh
SKIP_RUN := false
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

BUCKET_NAME := unmanaged-codedeploy-$(AWS_ACCOUNT_ID)
BUCKET := s3://$(BUCKET_NAME)
# All application folder names
MOBILE_API := legacy-naviance-student-mobile-api
AUTH_BRIDGE := naviance-auth-bridge
STUDENT_COLLEGE_BRIDGE := naviance-student-college-bridge
NAV_API_V1 := legacy-nav-api-v1
NAV_API_V2 := legacy-nav-api-v2
NAV_SERV_BETA_ASSESSMENT := assessment-api-prototype
SUCCEED_LEGACY := succeed-legacy

# Key directory locations and variables by application
AUTH_BRIDGE_BUILD := $(DIR)../../../$(AUTH_BRIDGE)
AUTH_BRIDGE_PACKAGE := $(AUTH_BRIDGE_BUILD)/build/package
AUTH_BRIDGE_GRADLE_TARGETS := $(GRADLE_TARGETS)

STUDENT_COLLEGE_BRIDGE_BUILD := $(DIR)../../../$(STUDENT_COLLEGE_BRIDGE)
STUDENT_COLLEGE_BRIDGE_PACKAGE := $(STUDENT_COLLEGE_BRIDGE_BUILD)/build/package
STUDENT_COLLEGE_BRIDGE_GRADLE_TARGETS := $(GRADLE_TARGETS)

MOBILE_API_BUILD := $(DIR)../../../$(MOBILE_API)
NAV_API_V1_BUILD := $(DIR)../../../$(NAV_API_V1)

NAV_SERV_BETA_ASSESSMENT_BUILD := $(DIR)../../../$(NAV_SERV_BETA_ASSESSMENT)
NAV_SERV_BETA_ASSESSMENT_PACKAGE := $(NAV_SERV_BETA_ASSESSMENT_BUILD)/build/package
NAV_SERV_BETA_ASSESSMENT_PHP_TARGETS := $(PHP_TARGETS)

NAV_API_V2_BUILD := $(DIR)../../../$(NAV_API_V2)
NAV_API_V2_PACKAGE := $(NAV_API_V2_BUILD)/build/package
NAV_API_V2_TARGETS := $(PHP_TARGETS_V2)

SUCCEED_LEGACY_BUILD :=$(DIR)../../../$(SUCCEED_LEGACY)
SUCCEED_LEGACY_BUILD_DEPLOY_FOLDER := build-deploy
SUCCEED_LEGACY_BUILD_DEPLOY := $(SUCCEED_LEGACY_BUILD)/$(SUCCEED_LEGACY_BUILD_DEPLOY_FOLDER)
SUCCEED_LEGACY_PACKAGE := $(SUCCEED_LEGACY_BUILD)/build/package
SUCCEED_LEGACY_GRADLE_TARGETS := clean init npmInstall prepareBundle copyBundle
SUCCEED_LEGACY_DOCKERFILE_NAME := Dockerfile.ci
SUCCEED_LEGACY_CONTAINER_TAG_NAME := $(SUCCEED_LEGACY)-codedeploy-$(PHP_VERSION_CODE):$(shell $(GET_BUILD_NUMBER) $(DIR)Makefile)
SUCCEED_LEGACY_APP_PATH := var/www/applications/succeed-legacy

SOURCES := $(wildcard $(SRC)/*) $(wildcard $(SRC)/bin/*) $(wildcard $(SRC)/etc/*) $(DIR)$(DOCKERFILE_NAME)

CONTAINER_TAG_NAME := $(APP_NAME)-codedeploy-$(PHP_VERSION_CODE):$(shell $(GET_BUILD_NUMBER) $(DIR)Makefile)

DEPLOYMENT_APP := tf-servicesapi-$(PHP_VERSION_CODE)
DEPLOYMENT_GROUP := qa

# docker build is fast to run the second time around.
# don't sweat the dependencies.
build:
	$(DIR)/../../bin/vpn-check.sh
	@echo "Build main Docker container"
	docker build -f=$(DOCKERFILE_NAME) . -t $(CONTAINER_TAG_NAME)
	@echo "Docker built OK: $(DOCKERFILE_NAME) yielding $(CONTAINER_TAG_NAME)"
	@echo "Build Succeed Legacy Docker container"
		cd $(SUCCEED_LEGACY_BUILD) \
       	&& docker build -f=$(SUCCEED_LEGACY_BUILD_DEPLOY_FOLDER)/$(SUCCEED_LEGACY_DOCKERFILE_NAME) . -t $(SUCCEED_LEGACY_CONTAINER_TAG_NAME) \
			&& echo "Docker built OK with $(SUCCEED_LEGACY_DOCKERFILE_NAME)"

$(ZIP): $(SOURCES)
	$(DIR)/../../bin/vpn-check.sh
	docker run --rm -v $$(pwd):/$(SUCCEED_LEGACY_APP_PATH) $(SUCCEED_LEGACY_CONTAINER_TAG_NAME) /bin/bash -c \
		"/bin/bash --login -c '\
			php --version \
				| head -n1 \
				| cut -d\" \" -f2 \
				| cut -d\".\" -f1,2 \
				| cut -d\".\" -f1,2'" \
				> $(PHP_BUILD_VERSION_FILE)
	# Check for the PHP version here and fail early.
	PHP_BUILD_VERSION=$$(cat $(PHP_BUILD_VERSION_FILE)); \
	PHP_VERSION_PARSED=$$($(DIR)../../bin/get-php-version.sh $$PHP_BUILD_VERSION); \
	if [ $$PHP_VERSION_PARSED != "$(PHP_VERSION_CODE)" ]; then \
		echo "ERROR: The project was built with PHP version $$PHP_VERSION_PARSED but the expected version is $(PHP_VERSION_CODE)"; \
		exit 1; \
	fi
	if [ $(SKIP_RUN) = false ]; then \
		echo "******** Building $(SUCCEED_LEGACY)" &&  \
		docker run -i --rm \
			-v $$(pwd)/../../../$(SUCCEED_LEGACY):/$(SUCCEED_LEGACY_APP_PATH) \
			$(SUCCEED_LEGACY_CONTAINER_TAG_NAME) \
			/bin/sh -c \
			'cd /$(SUCCEED_LEGACY_APP_PATH); ./gradlew $(SUCCEED_LEGACY_GRADLE_TARGETS)' && \
		echo "******** Building $(AUTH_BRIDGE)" &&  \
		docker run -i --rm \
			-v $$(pwd)/../../../$(AUTH_BRIDGE):/$(APP_PATH) \
			$(CONTAINER_TAG_NAME) \
			/bin/sh -c \
			'cd /$(APP_PATH); ./gradlew $(AUTH_BRIDGE_GRADLE_TARGETS)' && \
		echo "******** Building $(STUDENT_COLLEGE_BRIDGE)" &&  \
		docker run -i --rm \
			-v $$(pwd)/../../../$(STUDENT_COLLEGE_BRIDGE)/:/$(APP_PATH) \
			$(CONTAINER_TAG_NAME) \
			/bin/sh -c \
			'cd /$(APP_PATH); ./gradlew $(STUDENT_COLLEGE_BRIDGE_GRADLE_TARGETS)' && \
		echo "******** Building $(NAV_SERV_BETA_ASSESSMENT)" &&  \
		docker run -i --rm \
			-v $$(pwd)/../../../$(NAV_SERV_BETA_ASSESSMENT)/:/$(APP_PATH) \
			$(CONTAINER_TAG_NAME) \
			/bin/sh -c \
			'cd /$(APP_PATH); $(NAV_SERV_BETA_ASSESSMENT_PHP_TARGETS)' && \
		echo "******** Building $(NAV_API_V2)" &&  \
		docker run -i --rm \
			-v $$(pwd)/../../../$(NAV_API_V2)/:/$(APP_PATH) \
			$(CONTAINER_TAG_NAME) \
			/bin/sh -c \
			'cd /$(APP_PATH); $(NAV_API_V2_TARGETS)'; \
	fi

	@echo "******** Collecting CodeDeploy common files from $(SRC)"
	rsync -a $(SRC)/ $(ARCHIVE_DIR)/
	rsync -a \
		$(DIR)../../bin/aws/ \
		$(DIR)../../bin/manage-splunk.sh \
		$(ARCHIVE_DIR)/bin/
	for f in $(ARCHIVE_DIR)/appspec.yml $(ARCHIVE_DIR)/bin/common.sh $(ARCHIVE_DIR)/etc/*.json; do \
	    sed -i.bak -e "s/{{ APP_NAME }}/${APP_NAME}/g;s/{{ PHP_VERSION }}/${PHP_VERSION_CODE}/" $$f \
		&& rm -f $$f.bak; \
	done
	@echo "******** Collecting $(SUCCEED_LEGACY) files"
	rsync -a $(SUCCEED_LEGACY_PACKAGE)/ $(ARCHIVE_DIR)/$(SUCCEED_LEGACY)
	@echo "******** Collecting $(AUTH_BRIDGE) files"
	rsync -a $(AUTH_BRIDGE_PACKAGE)/ $(ARCHIVE_DIR)/$(AUTH_BRIDGE)
	@echo "******** Collecting $(STUDENT_COLLEGE_BRIDGE) files"
	rsync -a $(STUDENT_COLLEGE_BRIDGE_PACKAGE)/ $(ARCHIVE_DIR)/$(STUDENT_COLLEGE_BRIDGE)
	@echo "******** Collecting $(NAV_SERV_BETA_ASSESSMENT) files"
	# Changing permission to console file to fix an error
	if [[ -f  $(NAV_SERV_BETA_ASSESSMENT_PACKAGE)/console ]]; then \
		sudo chmod 755 $(NAV_SERV_BETA_ASSESSMENT_PACKAGE)/console; \
	fi
	rsync -a $(NAV_SERV_BETA_ASSESSMENT_PACKAGE)/ $(ARCHIVE_DIR)/$(NAV_SERV_BETA_ASSESSMENT)
	@echo "******** Collecting $(NAV_API_V2) files"
	rsync -a $(NAV_API_V2_PACKAGE)/ $(ARCHIVE_DIR)/$(NAV_API_V2)
	@echo "******** Collecting $(MOBILE_API) files"
	# Thanks Stack Overflow https://unix.stackexchange.com/a/100661/137901
	rsync -a --exclude='.git/' $(MOBILE_API_BUILD)/ $(ARCHIVE_DIR)/$(MOBILE_API)
	@echo "******** Collecting $(NAV_API_V1) files"
	# Thanks Stack Overflow https://unix.stackexchange.com/a/100661/137901
	rsync -a --exclude='.git/' $(NAV_API_V1_BUILD)/ $(ARCHIVE_DIR)/$(NAV_API_V1)
	# Thanks Stack Overflow https://unix.stackexchange.com/a/100661/137901
	rsync -a --exclude='.git/' $(NAV_API_V1_BUILD)/ $(ARCHIVE_DIR)/$(NAV_API_V1)
	@echo "******** Zipping CodeDeploy Archive"
	. $(DIR)../../bin/common.sh \
		&& ensure_zip
	cd $(ARCHIVE_DIR) \
		&& zip -q -r ../../$(ZIP) *
	# We are going to fake out Make by touching this file when we are
	# done with the build, so that we can avoid re-running the docker
	# stuff and the zip file if we can avoid it.
	touch $(DOCKERFILE_NAME)

clean:
	rm -rf $(BUILD)

distclean: clean
	rm -rf $(AUTH_BRIDGE_BUILD)/build


prep:
	mkdir -p $(PHP_BUILD_VERSION_DIR)

prep_bucket:
	. $(DIR)/../../env.sh && \
	    . $(DIR)../../bin/common.sh \
			&& ensure_awscli
	. $(DIR)/../../env.sh && \
		aws s3 ls $(BUCKET) >/dev/null \
			|| aws s3 mb $(BUCKET)

deploy: prep $(ZIP) s3copy
	. $(DIR)/../../env.sh && \
	S3_FILE=$(get_s3_file,$(ZIP),$(ARCHIVE)) && \
	deployment=$$(aws deploy create-deployment \
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

s3copy: $(ZIP) prep_bucket
	. $(DIR)/../../env.sh && \
		$(call s3_copy,$(ZIP),$(ARCHIVE))

all: prep build $(ZIP) prep_bucket s3copy
