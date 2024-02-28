default: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s %s\n\033[0m", $$1, $$2}'

# general
APP_NAME           := hostdb-collector-openstack
APP_VER            := 0.2
CIRCLE_WORKFLOW_ID ?= ""
DATACENTERS        := sin sj va va2
WORK_DIR           := $(shell pwd)

# git
ifeq ($(CIRCLECI), true)
GIT_BRANCH_DIRTY = $(CIRCLE_BRANCH)
else
GIT_BRANCH_DIRTY = $(shell git rev-parse --abbrev-ref HEAD)
endif
GIT_BRANCH     = $(shell echo "$(GIT_BRANCH_DIRTY)" | sed s/[[:punct:]]/_/g | tr '[:upper:]' '[:lower:]')
GIT_COMMIT_MSG = $(shell git log -1 --pretty=%B | tr '[:cntrl:]' ',' | sed 's/,*$$//g' | sed 's/,/, /g')
GIT_COMMIT_NUM = $(shell git rev-list --count HEAD)
GIT_COMMIT_SHA = $(shell git rev-list -1 HEAD | cut -b 1-7)

# version
ifeq ($(GIT_BRANCH), master)
TAG     = latest
VERSION = $(APP_VER).$(GIT_COMMIT_NUM)
else
TAG     = $(GIT_BRANCH)
VERSION = $(APP_VER).$(GIT_COMMIT_NUM).$(GIT_BRANCH)
endif
export TAG
export VERSION

# container
CONTAINER_REPO       := registry.pdxfixit.com
CONTAINER_IMAGE_NAME := $(CONTAINER_REPO)/$(APP_NAME)
REGISTRY_USER        ?= ""
REGISTRY_PASS        ?= ""

# docker env file
ifneq ("$(wildcard env.list)","")
	DOCKER_ENV = --env-file ./env.list
endif
DOCKER_RUN_OPTIONS = -it --rm --name $(APP_NAME) $(DOCKER_ENV)

.PHONY: build
build: ## create container image
	docker build --pull -t $(APP_NAME) \
		--label "name=$(APP_NAME)" \
		--label "vendor=PDXfixIT, LLC" \
		--label "version=$(VERSION)" \
		--label "maintainer=Ben Sandberg <info@pdxfixit.com>" \
		.

.PHONY: push
push: ## push container image to registry
ifeq ($(strip $(REGISTRY_USER)),)
	@echo "Username required (e.g. make push REGISTRY_USER=username REGISTRY_PASS=password)"
	exit 1
endif
ifeq ($(strip $(REGISTRY_PASS)),)
	@echo "Password required (e.g. make push REGISTRY_USER=username REGISTRY_PASS=password)"
	exit 1
endif
ifndef NEWRELIC_APIKEY
	$(error New Relic API Key not set)
endif
	if [ "$$(docker images -q $(APP_NAME))" == "" ]; then $(MAKE) build; fi
	docker tag $(APP_NAME) $(CONTAINER_IMAGE_NAME):$(VERSION)
	docker tag $(APP_NAME) $(CONTAINER_IMAGE_NAME):$(TAG)
	docker tag $(APP_NAME) $(CONTAINER_IMAGE_NAME):$(GIT_COMMIT_SHA)

	@echo $(REGISTRY_PASS) | docker login -u $(REGISTRY_USER) --password-stdin $(CONTAINER_REPO)
	docker push $(CONTAINER_IMAGE_NAME):$(VERSION)
	docker push $(CONTAINER_IMAGE_NAME):$(TAG)
	docker push $(CONTAINER_IMAGE_NAME):$(GIT_COMMIT_SHA)

	jq -n --arg msg "$(GIT_COMMIT_MSG)" '{"deployment":{"revision":"$(GIT_COMMIT_SHA)","description":$$msg,"user":"hostdb-collector-openstack"}}' > json.txt
	curl -i -X POST -H 'X-Api-Key: $(NEWRELIC_APIKEY)' -H 'Content-Type: application/json' -d @json.txt 'https://api.newrelic.com/v2/applications/1234567890/deployments.json'
	rm json.txt

.PHONY: sample_data
sample_data: ## output collected data to a file
	if [ "$$(docker images -q $(APP_NAME))" == "" ]; then $(MAKE) build; fi
	mkdir -p sample-data
	$(foreach dc,$(DATACENTERS),time docker run $(DOCKER_RUN_OPTIONS) -e SAMPLE_DATA=true -e DATACENTER=$(dc) -v `pwd`/sample-data:/sample-data $(APP_NAME);)

.PHONY: stop
stop: ## stop the container
	if [ "$$(docker ps -a -q -f 'name=$(APP_NAME)')" ]; then docker stop -t0 $(APP_NAME); fi

.PHONY: run
run: ## run the container
	if [ "$$(docker images -q $(APP_NAME))" == "" ]; then $(MAKE) build; fi
	docker run $(DOCKER_RUN_OPTIONS) $(APP_NAME)

.PHONY: clean
clean: ## clean up any artifacts
	rm -rf $(WORK_DIR)/sample-data
	if [ "$$(docker ps -a -q -f 'name=$(APP_NAME)')" ]; then docker stop -t0 $(APP_NAME); fi
	if [ "$$(docker images -q $(APP_NAME))" ]; then docker rmi $(APP_NAME); fi
