# See http://clarkgrubb.com/makefile-style-guide
MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

APP ?= go-proxy-multiarch
PORT ?= 8989
PROJECT ?= gitlab.domain.tld/projects/$(APP)

GIT_COMMIT := $(shell git rev-parse --short HEAD)
BUILD_TIME := $(shell date -u '+%F_%T')

# Docker vars
DOCKER_REGISTRY ?= registry.domain.tld
DOCKER_REPOSITORY ?= projects/$(APP)
DOCKER_IMAGE_NAME := ${DOCKER_REGISTRY}/${DOCKER_REPOSITORY}
DOCKER_TAG ?= ${GIT_COMMIT}
DOCKER_IMAGE ?= ${DOCKER_IMAGE_NAME}:${DOCKER_TAG}
DOCKER_LATEST ?= ${DOCKER_IMAGE_NAME}:latest

# Go build flags
GOOS ?= linux
GOARCH ?= amd64
GOLDFLAGS := '-w -s -extldflags "-static" -X ${PROJECT}/version.Release="${DOCKER_TAG}" -X ${PROJECT}/version.Commit="${DOCKER_TAG}" -X ${PROJECT}/version.BuildTime="${BUILD_TIME}"'

#help:
#	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# Help target
help:
	@echo ''
	@echo 'Usage: make [TARGET]'
	@echo 'Targets:'
	@echo '  help     	display this message'
	@echo '  docker    	build and push docker images to provided registry'
	@echo '  fmt      	gofmt vendor'
	@echo '  test     	run go test'
	@echo '  lint     	run go linter'
	@echo '  lint       run go dep'
	@echo '  all     	run go fmt lint build (default make)'
	@echo '  push     	push to docker repository'
	@echo ''

.PHONY: help

# Get the docker experimental env var
DOCKER_CLI_EXPERIMENTAL := $(shell echo $(DOCKER_CLI_EXPERIMENTAL))

# Dynamic targets
PLATFORMS ?= linux/amd64 linux/386 linux/arm linux/arm64 darwin/amd64 darwin/386

temp = $(subst /, ,$@)
GOOS = $(word 1, $(temp))
GOARCH = $(word 2, $(temp))

.PHONY: all
all: fmt lint test docker

.PHONY: docker
docker: publish manifests

.PHONY: $(PLATFORMS) manifests publish
publish: $(PLATFORMS)
$(PLATFORMS):
	@echo "-> $@"
	@echo "Building Docker containers"
	docker build -t ${DOCKER_IMAGE_NAME}:$(GOOS)-$(GOARCH)-${DOCKER_TAG} \
	-t ${DOCKER_IMAGE_NAME}:$(GOOS)-$(GOARCH)-latest --build-arg PORT=${PORT} \
	--build-arg GOLDFLAGS=$(GOLDFLAGS) --build-arg GOOS=$(GOOS) --build-arg GOARCH=$(GOARCH) ./
	@echo "Push Docker containers to registry ${DOCKER_REGISTRY}/${DOCKER_REPOSITORY}"
	docker push ${DOCKER_IMAGE_NAME}:$(GOOS)-$(GOARCH)-${DOCKER_TAG}
	docker push ${DOCKER_IMAGE_NAME}:$(GOOS)-$(GOARCH)-latest
	docker manifest create --amend "${DOCKER_IMAGE_NAME}:${DOCKER_TAG}" "${DOCKER_IMAGE_NAME}:$(GOOS)-$(GOARCH)-${DOCKER_TAG}"
	docker manifest annotate "${DOCKER_IMAGE_NAME}:${DOCKER_TAG}" "${DOCKER_IMAGE_NAME}:$(GOOS)-$(GOARCH)-${DOCKER_TAG}" --os=$(GOOS) --arch=$(GOARCH)
	docker manifest create --amend "${DOCKER_IMAGE_NAME}:latest" "${DOCKER_IMAGE_NAME}:$(GOOS)-$(GOARCH)-latest"
	docker manifest annotate "${DOCKER_IMAGE_NAME}:latest" "${DOCKER_IMAGE_NAME}:$(GOOS)-$(GOARCH)-latest" --os=$(GOOS) --arch=$(GOARCH)

manifests:
	@echo "-> $@"
	docker manifest push "${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
	docker manifest push "${DOCKER_IMAGE_NAME}:latest"

.PHONY: run
run:
	@echo "-> $@"
	docker stop $(APP) 2>/dev/null || true && docker rm --force $(APP)} 2>/dev/null || true
	docker run --name $(APP) -p ${PORT}:${PORT} --rm -e "PORT=${PORT}" ${DOCKER_IMAGE_NAME}:linux-amd64-latest

.PHONY: test
test:
	@echo "-> $@"
	go test -v -race ./...

.PHONY: fmt
fmt:
	@echo "-> $@"
	@gofmt -s -l ./ | grep -v vendor | tee /dev/stderr

.PHONY: lint
lint:
	@echo "-> $@"
	@go get -u golang.org/x/lint/golint
	@golint ./... | tee /dev/stderr
	@go get -u golang.org/x/tools/go/analysis/cmd/vet
	@go vet --all

.PHONY: dep
dep:
	@echo "-> $@"
	@go get -u github.com/golang/dep/cmd/dep
	@dep init && dep ensure -vendor-only
