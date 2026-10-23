# One entry point for every check, used identically on a laptop and in CI.
# Needs: helm, docker. `make e2e` additionally needs kind and kubectl.
#   make test      static checks (lint, unit, schema, policy)
#   make e2e       real installs on a hardened kind cluster
#   make all       everything

SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

# Pinned tool images (run in containers so nothing has to be installed)
HELM_UNITTEST_IMAGE ?= helmunittest/helm-unittest:4.3.0-1.2.1
KUBECONFORM_IMAGE   ?= ghcr.io/yannh/kubeconform:v0.7.0
KYVERNO_IMAGE       ?= ghcr.io/kyverno/kyverno-cli:v1.15.0
CRD_SCHEMA_LOCATION ?= https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json

CHARTS     := $(notdir $(patsubst %/,%,$(wildcard charts/*/)))
APP_CHARTS := $(filter-out common,$(CHARTS))
RENDER_DIR := .render
DOCKER_RUN := docker run --rm --user $$(id -u):$$(id -g) -v "$$PWD:/work" -w /work

.PHONY: help all test lint unit render schema policy e2e cluster cluster-delete readme clean
help:
	@sed -n 's/^#   \(make [a-z-]*\) */\1/p' $(MAKEFILE_LIST)

all: test e2e

test: lint unit schema policy

deps:
	@for c in $(CHARTS); do helm dependency build charts/$$c >/dev/null; done
.PHONY: deps

## lint: helm lint --strict for every chart, with defaults and with every ci values file
lint: deps
	@for c in $(CHARTS); do \
	  echo ">> lint $$c"; helm lint --strict charts/$$c; \
	  for f in charts/$$c/ci/*-values.yaml; do [ -e "$$f" ] || continue; echo ">> lint $$c ($$f)"; helm lint --strict charts/$$c -f "$$f"; done; \
	done

## unit: helm-unittest suites in charts/*/tests
unit: deps
	@for c in $(APP_CHARTS); do \
	  [ -d charts/$$c/tests ] || { echo "!! charts/$$c has no tests/ directory" >&2; exit 1; }; \
	  $(DOCKER_RUN) $(HELM_UNITTEST_IMAGE) charts/$$c; \
	done

## render: manifests of every chart x ci values file into .render/<chart>/<case>.yaml
render: deps
	@rm -rf $(RENDER_DIR)
	@for c in $(APP_CHARTS); do \
	  mkdir -p $(RENDER_DIR)/$$c; \
	  files=$$(ls charts/$$c/ci/*-values.yaml 2>/dev/null || true); \
	  if [ -z "$$files" ]; then helm template ci charts/$$c --namespace ci > $(RENDER_DIR)/$$c/default.yaml; fi; \
	  for f in $$files; do \
	    n=$$(basename $$f -values.yaml); echo ">> render $$c/$$n"; \
	    helm template ci charts/$$c --namespace ci -f $$f --api-versions monitoring.coreos.com/v1 > $(RENDER_DIR)/$$c/$$n.yaml; \
	  done; \
	done

## schema: kubeconform (strict) on the rendered manifests; CRDs are validated against the datreeio catalog
schema: render
	@$(DOCKER_RUN) $(KUBECONFORM_IMAGE) -strict -summary \
	  -schema-location default -schema-location '$(CRD_SCHEMA_LOCATION)' $(RENDER_DIR)

## policy: Kyverno CLI, repo-wide house style (test/policies) against the rendered manifests
policy: render
	@for f in $$(find $(RENDER_DIR) -name '*.yaml' | sort); do \
	  echo ">> policy $$f"; \
	  $(DOCKER_RUN) $(KYVERNO_IMAGE) apply test/policies --resource "$$f" --detailed-results --policy-report=false >/dev/null || { \
	    $(DOCKER_RUN) $(KYVERNO_IMAGE) apply test/policies --resource "$$f" 2>&1 | grep -v '^$$' || true; exit 1; }; \
	done

## cluster: create the hardened kind cluster (PodSecurity restricted, NetworkPolicy enforcement, CNPG operator)
cluster:
	test/kind/setup.sh

cluster-delete:
	kind delete cluster --name $${KIND_CLUSTER_NAME:-chart-testing}

## e2e: install each chart with each ci values file, helm test, upgrade from the last release (E2E_CHARTS="scrob" to narrow)
e2e: cluster
	test/e2e.sh $(E2E_CHARTS)

## readme: regenerate the Parameters tables
readme:
	@for c in $(APP_CHARTS); do npx --yes @bitnami/readme-generator-for-helm@2.7.2 --values charts/$$c/values.yaml --readme charts/$$c/README.md; done

clean:
	rm -rf $(RENDER_DIR) charts/*/charts/*.tgz
