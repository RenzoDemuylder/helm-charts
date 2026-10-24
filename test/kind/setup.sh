#!/usr/bin/env bash
# Create the kind test cluster (idempotent) and install the cluster-wide dependencies charts rely on.
set -euo pipefail

cd "$(dirname "$0")/../.."

CLUSTER_NAME="${KIND_CLUSTER_NAME:-chart-testing}"
CNPG_CHART_VERSION="${CNPG_CHART_VERSION:-0.29.1}"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo ">> kind cluster '$CLUSTER_NAME' already exists"
else
  echo ">> creating kind cluster '$CLUSTER_NAME'"
  kind create cluster --name "$CLUSTER_NAME" --config test/kind/cluster.yaml --wait 120s
fi
kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null

# CloudNativePG operator + CRDs (cnpg permutation of the charts)
if ! helm status cnpg --namespace cnpg-system >/dev/null 2>&1; then
  echo ">> installing CloudNativePG operator ${CNPG_CHART_VERSION}"
  helm upgrade --install cnpg cloudnative-pg \
    --repo https://cloudnative-pg.github.io/charts --version "$CNPG_CHART_VERSION" \
    --namespace cnpg-system --create-namespace --wait --timeout 300s
fi

echo ">> cluster ready"
kubectl get nodes
