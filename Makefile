# Image URL to use all building/pushing image targets
IMG ?= namespace-controller:latest
# Produce CRDs that work back to Kubernetes 1.11 (no version conversion)
CRD_OPTIONS ?= "crd:trivialVersions=true,preserveUnknownFields=false"

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

# Setting SHELL to bash allows bash commands to be executed by recipes.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

.PHONY: all
all: build

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

.PHONY: fmt
fmt: ## Run go fmt against code.
	go fmt ./...

.PHONY: vet
vet: ## Run go vet against code.
	go vet ./...

.PHONY: test
test: ## Run tests.
	go test ./... -v -race -coverprofile=cover.out

.PHONY: lint
lint: ## Run golangci-lint
	@which golangci-lint > /dev/null || (echo "golangci-lint not found. Install it from https://golangci-lint.run/usage/install/" && exit 1)
	golangci-lint run ./...

##@ Build

.PHONY: vendor
vendor: ## Vendor dependencies (avoids network/TLS errors in validate/test; run once when online)
	go mod vendor

.PHONY: build
build: fmt vet ## Build manager binary.
	go build -o bin/controller ./cmd/controller

.PHONY: run
run: fmt vet ## Run a controller from your host.
	go run ./cmd/controller/main.go

.PHONY: docker-build
docker-build: ## Build docker image with the manager.
	docker build -t ${IMG} -f build/Dockerfile .

.PHONY: docker-push
docker-push: ## Push docker image with the manager.
	docker push ${IMG}

##@ Deployment

.PHONY: deploy
deploy: ## Deploy controller to the K8s cluster specified in ~/.kube/config.
	kubectl apply -f config/rbac/rbac.yaml
	kubectl apply -f config/manager/manager.yaml

.PHONY: undeploy
undeploy: ## Undeploy controller from the K8s cluster specified in ~/.kube/config.
	kubectl delete -f config/manager/manager.yaml
	kubectl delete -f config/rbac/rbac.yaml

.PHONY: deploy-all
deploy-all: ## Deploy everything using the combined deploy/controller.yaml
	kubectl apply -f deploy/controller.yaml

.PHONY: undeploy-all
undeploy-all: ## Undeploy everything
	kubectl delete -f deploy/controller.yaml

##@ Local Development (kind/minikube)

.PHONY: kind-load
kind-load: docker-build ## Load docker image into kind cluster (use KIND_CLUSTER_NAME=your-cluster if different)
	@which kind > /dev/null || (echo "kind not found. Install it from https://kind.sigs.k8s.io/" && exit 1)
	kind load docker-image ${IMG} --name ${KIND_CLUSTER_NAME}

.PHONY: minikube-load
minikube-load: docker-build ## Load docker image into minikube
	@which minikube > /dev/null || (echo "minikube not found. Install it from https://minikube.sigs.k8s.io/" && exit 1)
	eval $$(minikube docker-env) && docker build -t ${IMG} -f build/Dockerfile .

##@ Testing

.PHONY: test-local
test-local: ## Run controller locally for testing
	go run ./cmd/controller/main.go

.PHONY: create-test-secret
create-test-secret: ## Create a test secret in default namespace
	kubectl create secret generic my-secret \
		--from-literal=username=admin \
		--from-literal=password=secret123 \
		-n default --dry-run=client -o yaml | kubectl apply -f -

.PHONY: create-test-namespace
create-test-namespace: ## Create a test namespace with replication annotation
	kubectl apply -f deploy/examples/example-namespace.yaml

.PHONY: verify-replication
verify-replication: ## Verify secret was replicated to test namespace
	@echo "Checking if secret exists in test-namespace..."
	kubectl get secret my-secret -n test-namespace || echo "Secret not found!"

##@ Test & Validate (Kind cluster lifecycle)

# Kind cluster name used by test-and-validate script
KIND_CLUSTER_NAME ?= namespace-controller-test

.PHONY: test-validate
test-validate: ## Run full test: validate, test, create Kind cluster, E2E, destroy cluster
	./scripts/test-and-validate.sh all

.PHONY: kind-create
kind-create: ## Create Kind cluster for testing
	./scripts/test-and-validate.sh create

.PHONY: kind-destroy
kind-destroy: ## Destroy Kind cluster
	./scripts/test-and-validate.sh destroy

.PHONY: test-validate-check
test-validate-check: ## Run validation only (fmt, vet, build) — no cluster
	./scripts/test-and-validate.sh validate

.PHONY: test-validate-e2e
test-validate-e2e: ## Deploy to existing Kind cluster and run E2E (run kind-create first)
	./scripts/test-and-validate.sh e2e

##@ Cleanup

.PHONY: clean
clean: ## Clean build artifacts
	rm -rf bin/

.PHONY: clean-test
clean-test: ## Clean test resources
	kubectl delete namespace test-namespace --ignore-not-found=true
	kubectl delete secret my-secret -n default --ignore-not-found=true
