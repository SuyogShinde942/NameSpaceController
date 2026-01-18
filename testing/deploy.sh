#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./deploy.sh <version> <dockerhub_id> [namespace] [platform]
#
# Examples:
#   ./deploy.sh 0.1.1 rahul079
#   ./deploy.sh 0.1.1 rahul079 default
#   ./deploy.sh 0.1.1 rahul079 default linux/amd64
#   ./deploy.sh 0.1.1 rahul079 default linux/amd64,linux/arm64

VERSION="${1:-}"
DOCKERHUB_ID="${2:-rahul079}"
NAMESPACE="${3:-default}"
PLATFORM="${4:-linux/amd64,linux/arm64}"

if [[ -z "$VERSION" ]]; then
  echo "Missing arguments!"
  echo "Usage: $0 <version> <dockerhub_id> [namespace] [platform]"
  exit 1
fi

IMAGE="${DOCKERHUB_ID}/actions:${VERSION}"

# Always run from repo root (script is inside testing/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

echo "-----------------------------------------"
echo "Repo Root  : ${REPO_ROOT}"
echo "Version    : ${VERSION}"
echo "DockerHub  : ${DOCKERHUB_ID}"
echo "Namespace  : ${NAMESPACE}"
echo "Platform   : ${PLATFORM}"
echo "Image      : ${IMAGE}"
echo "-----------------------------------------"

# Ensure buildx is ready
docker buildx create --use >/dev/null 2>&1 || true
docker buildx inspect --bootstrap >/dev/null

echo "Building + pushing image using buildx..."
docker buildx build \
  --platform "${PLATFORM}" \
  -f testing/Dockerfile \
  -t "${IMAGE}" \
  --push \
  .

echo "Updating Kubernetes deployment..."
kubectl create deployment actions \
  --image="${IMAGE}" \
  -n "${NAMESPACE}" \
  --dry-run=client -o yaml > testing/manifests/actions.yaml

kubectl apply -f testing/manifests/actions.yaml

# kubectl rollout status deployment/actions -n "${NAMESPACE}"


# create clusterrole and clusterrolebinding as this is not namespace scoped. 
# kubectl create role poddepl --resource pods,deployments --verb list --dry-run=client -oyaml > ./manifests/role.yaml
# kubectl create -f ./manifests/role.yaml
# kubectl create rolebinding poddepl --role poddepl --serviceaccount default:default --dry-run=client -oyaml > ./manifests/roleBinding.yaml
# kubectl create -f ./manifests/roleBinding.yaml

