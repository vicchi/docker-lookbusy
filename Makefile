SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -O extglob -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

.DEFAULT_GOAL := help

VAULT := homelab
VERSION := $(shell cat ./VERSION)
COMMIT_HASH := $(shell git log -1 --pretty=format:"sha-%h")
PLATFORMS := "linux/arm/v7,linux/arm64/v8,linux/amd64"

BUILD_FLAGS ?= 

HADOLINT_IMAGE := hadolint/hadolint

ifndef HOMELAB_OP_SERVICE_ACCOUNT_TOKEN
$(error HOMELAB_OP_SERVICE_ACCOUNT_TOKEN is not set in your environment)
endif

.PHONY: help
help: ## Show this help message
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' Makefile

.PHONY: dotenv
dotenv: .env	## Setup build secrets in .env files

.env: .env.template
	OP_SERVICE_ACCOUNT_TOKEN=${HOMELAB_OP_SERVICE_ACCOUNT_TOKEN} VAULT=$(VAULT) op inject --force --in-file $< --out-file $@

# Wrap the build in a check for an existing .env file
ifeq ($(shell test -f .env; echo $$?), 0)
include .env
ENVVARS := $(shell sed -ne 's/ *\#.*$$//; /./ s/=.*$$// p' .env )
$(foreach var,$(ENVVARS),$(eval $(shell echo export $(var)="$($(var))")))

LOOKBUSY := lookbusy
LOOKBUSY_BUILDER := $(LOOKBUSY)-builder
LOOKBUSY_USER := vicchi
LOOKBUSY_REPO := ${GITHUB_REGISTRY}/${LOOKBUSY_USER}
LOOKBUSY_IMAGE := ${LOOKBUSY}
LOOKBUSY_DOCKERFILE := ./docker/${LOOKBUSY}/Dockerfile

.PHONY: lint
lint: lint-dockerfiles lint-compose	## Run all linters on the code base

.PHONY: lint-dockerfiles
.PHONY: _lint-dockerfiles ## Lint all Dockerfiles
lint-dockerfiles: lint-${LOOKBUSY}-dockerfile

.PHONY: lint-${LOOKBUSY}-dockerfile
lint-${LOOKBUSY}-dockerfile:
	$(MAKE) _lint_dockerfile -e BUILD_DOCKERFILE="${LOOKBUSY_DOCKERFILE}"

.PHONY: lint-compose
lint-compose:	## Lint docker-compose.yml
	docker compose -f docker-compose.yml config 1> /dev/null

BUILD_TARGETS := build_lookbusy

.PHONY: build
build: $(BUILD_TARGETS) ## Build all images

REBUILD_TARGETS := rebuild_lookbusy

.PHONY: rebuild
rebuild: $(REBUILD_TARGETS) ## Rebuild all images (no cache)

RELEASE_TARGETS := release_lookbusy

.PHONY: release
release: $(RELEASE_TARGETS)	## Tag all images

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

release_lookbusy: build_lookbusy	## Tag the lookbusy image
	$(MAKE) _tag_image \
		-e BUILD_IMAGE=$(LOOKBUSY_IMAGE) \
		-e BUILD_TAG=$(COMMIT_HASH)
	$(MAKE) _tag_image \
		-e BUILD_IMAGE=$(LOOKBUSY_IMAGE) \
		-e BUILD_TAG=$(VERSION)

.PHONY: _lint_dockerfile
_lint_dockerfile:
	docker run --rm -i -e HADOLINT_IGNORE=DL3008,DL3018,DL3003 ${HADOLINT_IMAGE} < ${BUILD_DOCKERFILE}

.PHONY: _init_builder
init_builder:
	docker buildx inspect $(LOOKBUSY_BUILDER) > /dev/null 2>&1 || \
		docker buildx create --name $(LOOKBUSY_BUILDER) --bootstrap --use

.PHONY: _build_image
_build_image: repo_login _init_builder
	docker buildx build --platform=$(PLATFORMS) \
		--file ${BUILD_DOCKERFILE} \
		--push \
		--tag ${LOOKBUSY_REPO}/${BUILD_IMAGE}:latest \
		--provenance=false \
		--tag ${LOOKBUSY_REPO}/${BUILD_IMAGE}:latest \
		--build-arg VERSION=${VERSION} \
		--build-arg UBUNTU_VERSION=${UBUNTU_VERSION} \
		--ssh default \
		$(BUILD_FLAGS) .

.PHONY: _tag_image
_tag_image: repo_login
	docker buildx imagetools create ${LOOKBUSY_REPO}/$(BUILD_IMAGE):latest \
		--tag ${LOOKBUSY_REPO}/$(BUILD_IMAGE):$(BUILD_TAG)

.PHONY: repo_login
repo_login:
	echo "${GITHUB_PAT}" | docker login ${GITHUB_REGISTRY} -u ${GITHUB_USER} --password-stdin

.PHONY: up
up: repo_login	## Bring the container stack up
	docker compose up -d

.PHONY: down
down:	## Bring the container stack down
	docker compose down

.PHONY: pull
pull:	## Pull all current Docker images
	docker compose pull

.PHONY: restart
restart: down up	## Restart the container stack

# No .env file; fail the build
else
.DEFAULT:
	$(error Cannot find a .env file; run make dotenv)
endif
