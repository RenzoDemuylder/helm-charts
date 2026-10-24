#!/usr/bin/env bash
# Install every chart with every values file in charts/<name>/ci/ into the current (kind) cluster,
# run `helm test`, and check the upgrade path from the last published release.
#
# Usage: test/e2e.sh [chart ...]      (default: every chart except the common library)
# Env:   KEEP=1       keep namespaces/releases after the run (debugging)
#        UPGRADE=0    skip the upgrade-from-published-release check
#        OCI_REPO     where released charts live (default oci://ghcr.io/renzodemuylder/charts)
set -uo pipefail

cd "$(dirname "$0")/.."

OCI_REPO="${OCI_REPO:-oci://ghcr.io/renzodemuylder/charts}"
TIMEOUT="${TIMEOUT:-300s}"
RUN_ID="$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n')"

charts=("$@")
if [[ ${#charts[@]} -eq 0 ]]; then
  for dir in charts/*/; do
    name="$(basename "$dir")"
    [[ "$name" == "common" ]] && continue
    charts+=("$name")
  done
fi

failures=()

diagnose() {
  local ns="$1"
  echo "::group::diagnostics for namespace $ns"
  kubectl get all,pvc,networkpolicy,clusters.postgresql.cnpg.io -n "$ns" -o wide 2>&1 || true
  kubectl get events -n "$ns" --sort-by=.lastTimestamp 2>&1 | tail -n 40 || true
  for pod in $(kubectl get pods -n "$ns" -o name 2>/dev/null); do
    echo "--- describe $pod"
    kubectl describe -n "$ns" "$pod" 2>&1 | tail -n 40 || true
    echo "--- logs $pod"
    kubectl logs -n "$ns" "$pod" --all-containers --tail=60 2>&1 || true
  done
  echo "::endgroup::"
}

cleanup() {
  local release="$1" ns="$2"
  [[ "${KEEP:-0}" == "1" ]] && { echo ">> KEEP=1: leaving release $release in namespace $ns"; return; }
  helm uninstall "$release" --namespace "$ns" --wait --timeout 120s >/dev/null 2>&1 || true
  kubectl delete namespace "$ns" --wait=false >/dev/null 2>&1 || true
}

# run_case <chart> <case> [values file]
run_case() {
  local chart="$1" case="$2" values="${3:-}"
  local release="${chart:0:12}-${case:0:12}-${RUN_ID}"
  release="${release//_/-}"
  local ns="e2e-${release}"
  local args=()
  [[ -n "$values" ]] && args+=(--values "$values")

  echo
  echo "=== ${chart} / ${case} (namespace ${ns})"
  if ! helm install "$release" "charts/${chart}" --namespace "$ns" --create-namespace \
      --wait --wait-for-jobs --timeout "$TIMEOUT" "${args[@]}"; then
    diagnose "$ns"; failures+=("${chart}/${case}: install"); cleanup "$release" "$ns"; return
  fi
  if ! helm test "$release" --namespace "$ns" --logs --timeout "$TIMEOUT"; then
    diagnose "$ns"; failures+=("${chart}/${case}: helm test"); cleanup "$release" "$ns"; return
  fi
  echo "ok: ${chart}/${case}"
  cleanup "$release" "$ns"
}

# run_upgrade <chart> <values file>: install the latest published release, upgrade to the working tree
run_upgrade() {
  local chart="$1" values="${2:-}"
  local release="${chart:0:12}-upg-${RUN_ID}"
  local ns="e2e-${release}"
  local args=()
  [[ -n "$values" ]] && args+=(--values "$values")

  local published
  published="$(helm show chart "${OCI_REPO}/${chart}" 2>/dev/null | awk '/^version:/ {print $2}')"
  if [[ -z "$published" ]]; then
    echo ">> ${chart}: no published release found at ${OCI_REPO}/${chart}, skipping upgrade check"
    return
  fi

  echo
  echo "=== ${chart} / upgrade ${published} -> working tree (namespace ${ns})"
  if ! helm install "$release" "${OCI_REPO}/${chart}" --version "$published" --namespace "$ns" --create-namespace \
      --wait --timeout "$TIMEOUT" "${args[@]}"; then
    diagnose "$ns"; failures+=("${chart}/upgrade: install published ${published}"); cleanup "$release" "$ns"; return
  fi
  if ! helm upgrade "$release" "charts/${chart}" --namespace "$ns" --wait --timeout "$TIMEOUT" "${args[@]}"; then
    diagnose "$ns"; failures+=("${chart}/upgrade: upgrade from ${published}"); cleanup "$release" "$ns"; return
  fi
  if ! helm test "$release" --namespace "$ns" --logs --timeout "$TIMEOUT"; then
    diagnose "$ns"; failures+=("${chart}/upgrade: helm test after upgrade"); cleanup "$release" "$ns"; return
  fi
  echo "ok: ${chart}/upgrade from ${published}"
  cleanup "$release" "$ns"
}

for chart in "${charts[@]}"; do
  [[ -d "charts/${chart}" ]] || { echo "unknown chart: ${chart}" >&2; exit 2; }
  helm dependency build "charts/${chart}" >/dev/null || { failures+=("${chart}: dependency build"); continue; }

  shopt -s nullglob
  files=("charts/${chart}"/ci/*-values.yaml)
  shopt -u nullglob

  if [[ ${#files[@]} -eq 0 ]]; then
    run_case "$chart" default
  else
    for f in "${files[@]}"; do
      case_name="$(basename "$f" -values.yaml)"
      run_case "$chart" "$case_name" "$f"
    done
  fi

  if [[ "${UPGRADE:-1}" == "1" ]]; then
    run_upgrade "$chart" "$([[ -f "charts/${chart}/ci/default-values.yaml" ]] && echo "charts/${chart}/ci/default-values.yaml")"
  fi
done

echo
if [[ ${#failures[@]} -gt 0 ]]; then
  echo "FAILED:"
  printf '  - %s\n' "${failures[@]}"
  exit 1
fi
echo "all e2e cases passed"
