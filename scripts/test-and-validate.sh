#!/usr/bin/env bash
# test-and-validate.sh — Create/destroy Kind cluster, run tests, and validate namespace controller
# Usage:
#   ./scripts/test-and-validate.sh all          # Full run: create cluster, test, validate, destroy
#   ./scripts/test-and-validate.sh create       # Create Kind cluster only
#   ./scripts/test-and-validate.sh destroy      # Destroy Kind cluster only
#   ./scripts/test-and-validate.sh test         # Run Go tests (no cluster)
#   ./scripts/test-and-validate.sh validate     # Run fmt, vet, build (no cluster)
#   ./scripts/test-and-validate.sh e2e          # Deploy to cluster and run E2E (cluster must exist)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-namespace-controller-test}"
IMG="${IMG:-namespace-controller:latest}"
E2E_WAIT_SEC="${E2E_WAIT_SEC:-30}"
E2E_POLL_INTERVAL="${E2E_POLL_INTERVAL:-3}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

check_prereqs() {
  local missing=()
  for cmd in go docker kubectl; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    err "Missing required commands: ${missing[*]}"
    return 1
  fi
  return 0
}

check_kind() {
  if ! command -v kind &>/dev/null; then
    err "kind is required. Install from https://kind.sigs.k8s.io/"
    return 1
  fi
  return 0
}

# Use -mod=vendor when vendor exists to avoid network/TLS errors (e.g. x509 certificate issues)
mod_flag() {
  [[ -d "$ROOT_DIR/vendor" ]] && echo "-mod=vendor"
}

run_validate() {
  info "Running validation (fmt, vet, build)..."
  cd "$ROOT_DIR"
  local mod=$(mod_flag)
  if [[ -n "$mod" ]]; then
    info "Using $mod (vendor directory present)"
  else
    warn "No vendor/ directory. If you hit x509/certificate errors, run: go mod vendor   (when online), then re-run."
  fi
  go fmt ./...
  ok "go fmt passed"
  go vet $mod ./...
  ok "go vet passed"
  go build $mod -o bin/controller ./cmd/controller
  ok "go build passed"
  rm -f bin/controller
}

run_tests() {
  info "Running Go tests..."
  cd "$ROOT_DIR"
  local mod=$(mod_flag)
  [[ -n "$mod" ]] && info "Using $mod (vendor directory present)"
  local test_log=/tmp/namespace-controller-test.log
  if ! go test $mod ./... -v -race -count=1 2>&1 | tee "$test_log"; then
    err "Go test command failed. See $test_log"
    if grep -qE "x509|certificate|proxy.golang.org|dial tcp" "$test_log" 2>/dev/null; then
      warn "If you see certificate/network errors, run: go mod vendor   (when online), then re-run."
    fi
    return 1
  fi
  if grep -q "FAIL" "$test_log" 2>/dev/null; then
    err "Some tests failed. See $test_log"
    return 1
  fi
  ok "Go tests passed"
}

kind_create() {
  check_kind || return 1
  if kind get kubeconfig --name "$KIND_CLUSTER_NAME" &>/dev/null; then
    warn "Kind cluster '$KIND_CLUSTER_NAME' already exists. Use 'destroy' first to recreate."
    return 0
  fi
  info "Creating Kind cluster: $KIND_CLUSTER_NAME"
  # Use a writable kubeconfig path so we don't need to write to ~/.kube (avoids "operation not permitted" in restricted envs)
  local kind_kubeconfig
  kind_kubeconfig="$(mktemp -t "kind-kubeconfig-${KIND_CLUSTER_NAME}-XXXXXX")"
  trap "rm -f '${kind_kubeconfig}'" RETURN
  KUBECONFIG="$kind_kubeconfig" kind create cluster --name "$KIND_CLUSTER_NAME" --wait 2m
  ok "Kind cluster created"
}

kind_destroy() {
  check_kind || return 1
  if ! kind get kubeconfig --name "$KIND_CLUSTER_NAME" &>/dev/null; then
    warn "Kind cluster '$KIND_CLUSTER_NAME' does not exist."
    return 0
  fi
  info "Destroying Kind cluster: $KIND_CLUSTER_NAME"
  # Use a writable kubeconfig path so kind doesn't write to ~/.kube (avoids "operation not permitted" in restricted envs)
  local destroy_kubeconfig
  destroy_kubeconfig="$(mktemp -t "kind-destroy-kubeconfig-XXXXXX")"
  trap "rm -f '${destroy_kubeconfig}'" RETURN
  KUBECONFIG="$destroy_kubeconfig" kind delete cluster --name "$KIND_CLUSTER_NAME"
  ok "Kind cluster destroyed"
}

e2e_deploy_and_test() {
  # KUBECONFIG must be a *file path*, not the config content (long content causes "file name too long")
  local kubeconfig_file
  kubeconfig_file="$(mktemp -t "kind-kubeconfig-${KIND_CLUSTER_NAME}-XXXXXX")"
  kind get kubeconfig --name "$KIND_CLUSTER_NAME" > "$kubeconfig_file" 2>/dev/null || true
  if [[ ! -s "$kubeconfig_file" ]]; then
    rm -f "$kubeconfig_file"
    err "Kind cluster '$KIND_CLUSTER_NAME' not found. Run 'create' first."
    return 1
  fi
  export KUBECONFIG="$kubeconfig_file"
  # Clean up temp kubeconfig when script exits (path captured in trap string)
  trap "rm -f '${kubeconfig_file}'" EXIT

  cd "$ROOT_DIR"

  info "Building Docker image: $IMG"
  if ! docker build -t "$IMG" -f build/Dockerfile . ; then
    err "Docker build failed. Ensure Docker has write access to its config (e.g. ~/.docker)."
    return 1
  fi
  ok "Docker image built"

  info "Loading image into Kind cluster..."
  if ! kind load docker-image "$IMG" --name "$KIND_CLUSTER_NAME" ; then
    err "Kind load failed. Ensure the image was built (see above) and the cluster is running."
    return 1
  fi
  ok "Image loaded"

  info "Deploying controller (RBAC + Deployment)..."
  kubectl apply -f deploy/controller.yaml
  ok "Controller deployed"

  info "Waiting for controller deployment to be ready..."
  kubectl rollout status deployment/namespace-controller -n default --timeout=120s
  ok "Controller is ready"
  sleep 3
  info "Giving controller time to start namespace watch..."

  info "Ensuring clean test secret in default namespace (short keys only)..."
  kubectl delete secret my-secret -n default --ignore-not-found=true 2>/dev/null || true
  kubectl create secret generic my-secret \
    --from-literal=username=admin \
    --from-literal=password=secret123 \
    -n default
  ok "Test secret created"

  info "Deleting test-namespace if it exists (clean state)..."
  kubectl delete namespace test-namespace --ignore-not-found=true --timeout=60s 2>/dev/null || true
  sleep 3

  info "Creating test namespace with replication label..."
  kubectl apply -f deploy/examples/example-namespace.yaml
  ok "Test namespace created"

  info "Waiting up to ${E2E_WAIT_SEC}s for secret replication to test-namespace..."
  local i=0
  while [[ $i -lt $E2E_WAIT_SEC ]]; do
    if kubectl get secret my-secret -n test-namespace &>/dev/null; then
      ok "Secret 'my-secret' replicated to test-namespace"
      kubectl get secret my-secret -n test-namespace -o yaml | head -20
      return 0
    fi
    sleep "$E2E_POLL_INTERVAL"
    i=$((i + E2E_POLL_INTERVAL))
  done

  err "Secret was not replicated within ${E2E_WAIT_SEC}s. Controller logs:"
  kubectl logs -n default deployment/namespace-controller --tail=50 2>/dev/null || true
  return 1
}

run_all() {
  info "=== Full test run: validate → test → create cluster → e2e → destroy cluster ==="
  check_prereqs || return 1
  run_validate || return 1
  run_tests   || return 1
  check_kind  || return 1
  kind_destroy 2>/dev/null || true
  kind_create  || return 1
  e2e_deploy_and_test || return 1
  kind_destroy || return 1
  ok "=== All steps completed successfully ==="
}

usage() {
  echo "Usage: $0 {all|create|destroy|test|validate|e2e}"
  echo ""
  echo "  all      - Validate, test, create Kind cluster, run E2E, destroy cluster"
  echo "  create   - Create Kind cluster ($KIND_CLUSTER_NAME)"
  echo "  destroy  - Destroy Kind cluster ($KIND_CLUSTER_NAME)"
  echo "  test     - Run Go tests only (no cluster)"
  echo "  validate - Run go fmt, vet, build only (no cluster)"
  echo "  e2e      - Deploy controller to existing cluster and run E2E (cluster must exist)"
  echo ""
  echo "Env: KIND_CLUSTER_NAME, IMG, E2E_WAIT_SEC, E2E_POLL_INTERVAL"
}

case "${1:-}" in
  all)      run_all ;;
  create)   check_prereqs && check_kind && kind_create ;;
  destroy)  check_kind && kind_destroy ;;
  test)     check_prereqs && run_tests ;;
  validate) check_prereqs && run_validate ;;
  e2e)      check_prereqs && e2e_deploy_and_test ;;
  -h|--help|help|"") usage ;;
  *)        err "Unknown command: $1"; usage; exit 1 ;;
esac
