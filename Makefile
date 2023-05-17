SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -O extglob -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

ifeq ($(.DEFAULT_GOAL),)
ifneq ($(shell test -f .env; echo $$?), 0)
$(error Cannot find a .env file; copy .env.sample and customise)
endif
endif

# Wrap the build in a check for an existing .env file
ifeq ($(shell test -f .env; echo $$?), 0)
include .env
ENVVARS := $(shell sed -ne 's/ *\#.*$$//; /./ s/=.*$$// p' .env )
$(foreach var,$(ENVVARS),$(eval $(shell echo export $(var)="$($(var))")))

.DEFAULT_GOAL := help

VERSION := $(shell cat ./VERSION)
COMMIT_HASH := $(shell git log -1 --pretty=format:"sha-%h")
PLATFORMS := "linux/arm/v7,linux/arm64/v8,linux/amd64"

BUILD_FLAGS ?= 

LOOKBUSY := lookbusy
LOOKBUSY_BUILDER := $(LOOKBUSY)-builder
LOOKBUSY_USER := vicchi
LOOKBUSY_REPO := ${GITHUB_REGISTRY}/${LOOKBUSY_USER}
LOOKBUSY_IMAGE := ${LOOKBUSY}
LOOKBUSY_DOCKERFILE := ./docker/${LOOKBUSY}/Dockerfile

HADOLINT_IMAGE := hadolint/hadolint

.PHONY: help
help: ## Show this help message
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' Makefile

.PHONY: lint
lint: lint-dockerfiles	## Run all linters on the code base

.PHONY: lint-dockerfiles
.PHONY: _lint-dockerfiles ## Lint all Dockerfiles
lint-dockerfiles: lint-${LOOKBUSY}-dockerfile

.PHONY: lint-${LOOKBUSY}-dockerfile
lint-${LOOKBUSY}-dockerfile:
	$(MAKE) _lint_dockerfile -e BUILD_DOCKERFILE="${LOOKBUSY_DOCKERFILE}"

BUILD_TARGETS := build_lookbusy

.PHONY: build
build: $(BUILD_TARGETS) ## Build all images

REBUILD_TARGETS := rebuild_lookbusy

.PHONY: rebuild
rebuild: $(REBUILD_TARGETS) ## Rebuild all images (no cache)

# lookbusy targets

build_lookbusy:	repo_login	## Build the lookbusy image
	$(MAKE) _build_image \
		-e BUILD_DOCKERFILE=./docker/$(LOOKBUSY)/Dockerfile \
		-e BUILD_IMAGE=$(LOOKBUSY_IMAGE)

rebuild_lookbusy:	## Rebuild the lookbusy image (no cache)
	$(MAKE) _build_image \
		-e BUILD_DOCKERFILE=./docker/$(LOOKBUSY)/Dockerfile \
		-e BUILD_IMAGE=$(LOOKBUSY_IMAGE) \
		-e BUILD_FLAGS="--no-cache"

.PHONY: _lint_dockerfile
_lint_dockerfile:
	docker run --rm -i -e HADOLINT_IGNORE=DL3008,DL3018,DL3003 ${HADOLINT_IMAGE} < ${BUILD_DOCKERFILE}

.PHONY: _build_image
_build_image:
	docker buildx inspect $(LOOKBUSY_BUILDER) > /dev/null 2>&1 || \
		docker buildx create --name $(LOOKBUSY_BUILDER) --bootstrap --use
	docker buildx build --platform=$(PLATFORMS) \
		--file ${BUILD_DOCKERFILE} --push \
		--tag ${LOOKBUSY_REPO}/${BUILD_IMAGE}:latest \
		--tag ${LOOKBUSY_REPO}/${BUILD_IMAGE}:$(VERSION) \
		--tag ${LOOKBUSY_REPO}/${BUILD_IMAGE}:$(COMMIT_HASH) \
		$(BUILD_FLAGS) \
		--ssh default $(BUILD_FLAGS) .

.PHONY: repo_login
repo_login:
	echo "${GITHUB_PAT}" | docker login ${GITHUB_REGISTRY} -u ${GITHUB_USER} --password-stdin

# No .env file; fail the build
else
.DEFAULT:
	$(error Cannot find a .env file; copy .env.sample and customise)
endif
