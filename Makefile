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

OS := linux
ARCH := $(shell uname -i)
VERSION := $(shell cat ./VERSION)
COMMIT_HASH := $(shell git log -1 --pretty=format:"sha-%h")

BUILD_FLAGS ?= 

LOOKBUSY := lookbusy
LOOKBUSY_REPO := ${GITHUB_REGISTRY}/woeplanet
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

RELEASE_TARGETS := release_lookbusy

.PHONY: release
release: $(RELEASE_TARGETS)	## Tag and push all images

# spelunker-service targets

build_lookbusy:	## Build the lookbusy image
	$(MAKE) _build_image \
		-e BUILD_DOCKERFILE=./docker/$(LOOKBUSY)/Dockerfile \
		-e BUILD_IMAGE=$(LOOKBUSY_IMAGE)
	$(MAKE) _tag_image \
		-e BUILD_IMAGE=$(LOOKBUSY_IMAGE) \
		-e BUILD_TAG=latest

rebuild_lookbusy:	## Rebuild the lookbusy image (no cache)
	$(MAKE) _build_image \
		-e BUILD_DOCKERFILE=./docker/$(LOOKBUSY)/Dockerfile \
		-e BUILD_IMAGE=$(LOOKBUSY_IMAGE) \
		-e BUILD_FLAGS="--no-cache"
	$(MAKE) _tag_image \
		-e BUILD_IMAGE=$(LOOKBUSY_IMAGE) \
		-e BUILD_TAG=latest

release_lookbusy: build_lookbusy repo_login	## Tag and push lookbusy image
	$(MAKE) _release_image \
		-e BUILD_IMAGE=$(LOOKBUSY_IMAGE)

.PHONY: _lint_dockerfile
_lint_dockerfile:
	docker run --rm -i -e HADOLINT_IGNORE=DL3008,DL3018,DL3003 ${HADOLINT_IMAGE} < ${BUILD_DOCKERFILE}

.PHONY: _build_image
_build_image:
	DOCKER_BUILDKIT=1 docker build --platform="$(OS)/$(ARCH)" --file ${BUILD_DOCKERFILE} --tag ${BUILD_IMAGE} --ssh default $(BUILD_FLAGS) .

.PHONY: _release_image
_release_image:
	$(MAKE) _tag_image \
		-e BUILD_IMAGE=$(BUILD_IMAGE) \
		-e BUILD_TAG=$(VERSION)
	$(MAKE) _tag_image \
		-e BUILD_IMAGE=$(BUILD_IMAGE) \
		-e BUILD_TAG=$(COMMIT_HASH)
	$(MAKE) _registry_tag_image \
		-e BUILD_IMAGE=$(BUILD_IMAGE) \
		-e BUILD_TAG=latest
	$(MAKE) _registry_tag_image \
		-e BUILD_IMAGE=$(BUILD_IMAGE) \
		-e BUILD_TAG=$(VERSION)
	$(MAKE) _registry_tag_image \
		-e BUILD_IMAGE=$(BUILD_IMAGE) \
		-e BUILD_TAG=$(COMMIT_HASH)

	docker push ${LOOKBUSY_REPO}/$(BUILD_IMAGE):latest
	docker push ${LOOKBUSY_REPO}/$(BUILD_IMAGE):$(VERSION)
	docker push ${LOOKBUSY_REPO}/$(BUILD_IMAGE):$(COMMIT_HASH)

.PHONY: _tag_image
_tag_image:
	docker tag ${BUILD_IMAGE} ${BUILD_IMAGE}:${BUILD_TAG}

.PHONY: _registry_tag_image
_registry_tag_image:
	docker tag ${BUILD_IMAGE} ${LOOKBUSY_REPO}/${BUILD_IMAGE}:${BUILD_TAG}

.PHONY: repo_login
repo_login:
	echo "${GITHUB_PAT}" | docker login ${GITHUB_REGISTRY} -u ${GITHUB_USER} --password-stdin

# No .env file; fail the build
else
.DEFAULT:
	$(error Cannot find a .env file; copy .env.sample and customise)
endif
