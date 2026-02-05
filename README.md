# Namespace Controller

A Kubernetes controller that automatically replicates secrets from a source namespace to target namespaces based on a namespace annotation.

## Overview

This controller watches for namespace creation events and automatically replicates secrets when a namespace is created with a specific **annotation**. The annotation format is:

```
replicate-secret: "source-namespace/secret-name"
```

(Annotations are used rather than labels because label values cannot contain `/`.)

## Features

- ✅ Automatic secret replication on namespace creation
- ✅ Works both in-cluster and locally (auto-detects)
- ✅ Proper RBAC permissions
- ✅ Graceful error handling
- ✅ Deep copy of secret data to avoid reference issues
- ✅ Graceful shutdown on SIGTERM/SIGINT

## Project Structure

```
namespacecontroller/
├── cmd/
│   └── controller/          # Main application entry point
│       └── main.go
├── pkg/
│   ├── client/               # Kubernetes client setup
│   │   └── client.go
│   └── controller/           # Controller logic
│       └── controller.go
├── config/
│   ├── rbac/                 # RBAC manifests
│   │   └── rbac.yaml
│   └── manager/              # Deployment manifests
│       └── manager.yaml
├── deploy/
│   ├── controller.yaml       # Combined deployment (RBAC + Deployment)
│   └── examples/             # Example manifests
│       └── example-namespace.yaml
├── build/
│   └── Dockerfile            # Container image build
├── docs/
│   ├── LEARNING_GUIDE.md     # Learning guide for developers
│   └── DEPLOYMENT.md         # Deployment instructions
├── Makefile                  # Build automation
├── go.mod                    # Go dependencies
└── README.md                 # This file
```

## Quick Start

### Prerequisites

- Go 1.21+
- Docker (for building images)
- Kubernetes cluster (local or remote)
- kubectl configured

---

## Step-by-step: Test with Docker + Kind + Namespace

End-to-end flow: build image → run Kind → deploy controller → create namespace and verify replication.

**Prerequisites:** Docker, [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation), `kubectl`.

### Step 1: Build the Docker image

From the project root:

```bash
make docker-build
```

This builds `namespace-controller:latest` (or set `IMG=your-name:tag`).

### Step 2: Create a Kind cluster

```bash
kind create cluster --name namespace-controller-test
```

Point `kubectl` at it (Kind does this automatically):

```bash
kubectl cluster-info --context kind-namespace-controller-test
```

### Step 3: Load the image into Kind

Kind doesn’t pull from Docker Hub by default, so load your local image:

```bash
make kind-load
```

This builds the image (if needed) and loads it into the cluster.

### Step 4: Deploy the controller

```bash
kubectl apply -f deploy/controller.yaml
```

Wait until the controller pod is running:

```bash
kubectl get pods -n default -l app=namespace-controller
kubectl logs -f deployment/namespace-controller -n default
```

(Ctrl+C to stop following logs.)

### Step 5: Create a source secret

The controller copies a secret from a source namespace into namespaces that have the replication annotation. Create the source secret in `default`:

```bash
kubectl create secret generic my-secrets \
  --from-literal=username=admin \
  --from-literal=password=secret123 \
  -n default
```

### Step 6: Create a namespace (with replication annotation)

Create a namespace with the replication annotation so that `my-secret` from `default` is replicated into it:

```bash
kubectl apply -f deploy/examples/example-namespace.yaml
```

### Step 7: Verify replication

Check that the secret was copied into the new namespace:

```bash
kubectl get secret my-secrets -n test-namespace
```

You should see `my-secrets` in `test-namespace`. Optionally inspect controller logs:

```bash
kubectl logs deployment/namespace-controller -n default --tail=50
```

### Cleanup

```bash
# Remove test namespace and secret
make clean-test

# Remove controller and RBAC
kubectl delete -f deploy/controller.yaml

# Delete Kind cluster
kind delete cluster --name namespace-controller-test
```

---

### Local Development

1. **Run the controller locally:**
   ```bash
   make run
   # or
   go run ./cmd/controller/main.go
   ```

2. **Build the binary:**
   ```bash
   make build
   ```

### Deploy to Kubernetes

1. **Build the Docker image:**
   ```bash
   make docker-build
   ```

2. **For local clusters (kind/minikube):**
   ```bash
   # For kind
   make kind-load
   
   # For minikube
   make minikube-load
   ```

3. **Deploy the controller:**
   ```bash
   make deploy-all
   # or
   kubectl apply -f deploy/controller.yaml
   ```

4. **Check controller logs:**
   ```bash
   kubectl logs -f deployment/namespace-controller -n default
   ```

## Usage

### 1. Create a source secret

```bash
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123 \
  -n default
```

### 2. Create a namespace with replication annotation

```bash
kubectl create namespace test-namespace
kubectl annotate namespace test-namespace replicate-secret="default/my-secret"
```

Or use the example file:
```bash
kubectl apply -f deploy/examples/example-namespace.yaml
```

### 3. Verify secret replication

```bash
kubectl get secret my-secret -n test-namespace
```

## Makefile Targets

```bash
# Development
make run              # Run controller locally
make build            # Build binary
make test             # Run tests
make fmt              # Format code
make vet              # Run go vet
make vendor           # Vendor deps (avoids network/TLS errors; run once when online)

# Docker
make docker-build     # Build Docker image
make docker-push     # Push Docker image

# Deployment
make deploy           # Deploy using config/ manifests
make deploy-all       # Deploy using deploy/controller.yaml
make undeploy         # Remove controller

# Local cluster
make kind-load        # Load image into kind
make minikube-load    # Load image into minikube

# Testing
make create-test-secret      # Create test secret
make create-test-namespace    # Create test namespace
make verify-replication       # Verify replication worked
make clean-test              # Clean test resources

# Test & Validate (Kind cluster lifecycle)
make test-validate           # Full run: validate → test → create Kind → E2E → destroy Kind
make kind-create             # Create Kind cluster (namespace-controller-test)
make kind-destroy            # Destroy Kind cluster
make test-validate-check     # Validate only (fmt, vet, build) — no cluster
make test-validate-e2e       # Deploy to existing Kind cluster and run E2E
```

### Test and validate script

The `scripts/test-and-validate.sh` script creates/destroys a Kind cluster and runs validation and E2E:

```bash
# Full run: validate, test, create Kind cluster, run E2E, destroy cluster
./scripts/test-and-validate.sh all
# or
make test-validate

# Individual steps
./scripts/test-and-validate.sh validate   # fmt, vet, build (no cluster)
./scripts/test-and-validate.sh test       # Go tests (no cluster)
./scripts/test-and-validate.sh create    # Create Kind cluster
./scripts/test-and-validate.sh e2e       # Deploy and run E2E (cluster must exist)
./scripts/test-and-validate.sh destroy   # Destroy Kind cluster
```

**Prerequisites:** `go`, `docker`, `kubectl`, and [kind](https://kind.sigs.k8s.io/).

**Env:** `KIND_CLUSTER_NAME` (default: `namespace-controller-test`), `IMG`, `E2E_WAIT_SEC`, `E2E_POLL_INTERVAL`.

**Troubleshooting (x509 / certificate errors):** If validate or test fail with TLS/certificate errors when fetching modules, run once (when online): `make vendor`. The script will then use vendored dependencies and avoid network access for build/test.

## Configuration

### Annotation Format

The controller looks for namespaces with the annotation (annotations allow `/` in values; labels do not):
```
replicate-secret: "source-namespace/secret-name"
```

**Examples:**
- `replicate-secret: "default/my-secret"` - Replicates `my-secret` from `default` namespace
- `replicate-secret: "kube-system/ca-cert"` - Replicates `ca-cert` from `kube-system` namespace

### RBAC Permissions

The controller requires:
- **Namespaces**: `get`, `list`, `watch` (cluster-scoped)
- **Secrets**: `get`, `list` (to read from source), `create`, `update`, `patch` (to create in target)

See `config/rbac/rbac.yaml` for details.

## Architecture

```
┌─────────────────┐
│  Kubernetes     │
│  API Server     │
└────────┬────────┘
         │
         │ Watch Namespaces
         │
┌────────▼────────┐
│   Controller    │
│                 │
│  ┌───────────┐  │
│  │  Watcher  │  │
│  └─────┬─────┘  │
│        │        │
│  ┌─────▼─────┐  │
│  │  Handler  │  │
│  └─────┬─────┘  │
│        │        │
│  ┌─────▼─────┐  │
│  │ Replicator│  │
│  └───────────┘  │
└─────────────────┘
```

## Development

### Code Structure

- **`cmd/controller/main.go`**: Entry point, handles signal processing and initialization
- **`pkg/client/client.go`**: Kubernetes client creation (supports in-cluster and local)
- **`pkg/controller/controller.go`**: Core controller logic (watching, parsing, replicating)

### Adding Features

1. **Watch for secret updates**: Modify `pkg/controller/controller.go` to also watch secrets
2. **Multiple secrets**: Support comma-separated list in the label
3. **Label selectors**: Add namespace label selectors for filtering

See `docs/LEARNING_GUIDE.md` for detailed learning resources.

## Troubleshooting

### Controller not starting

```bash
# Check pod status
kubectl describe pod -l app=namespace-controller -n default

# Check logs
kubectl logs -l app=namespace-controller -n default
```

### Permission errors

```bash
# Verify RBAC
kubectl get clusterrole namespace-controller-cluster-role
kubectl get clusterrolebinding namespace-controller-cluster-binding
kubectl get serviceaccount namespace-controller -n default
```

### Controller says "Successfully replicated" but `kubectl get secret` shows no resources

Your **kubectl context** is likely pointing at a different cluster than the one the controller is using. The secret was created in the cluster the controller is connected to.

1. See which context you're using:
   ```bash
   kubectl config current-context
   ```
2. If the controller runs **in-cluster** (e.g. in Kind), use that cluster's context when running kubectl. For a Kind cluster named `namespace-controller-test`:
   ```bash
   kubectl config use-context kind-namespace-controller-test
   kubectl get secret -n test-namespace
   ```
3. If you ran the controller **locally** (`make run`), it used the context that was current when it started. Use the same context with kubectl, or restart the controller after switching to the desired context.

### Secret not replicated

1. Check namespace annotation:
   ```bash
   kubectl get namespace <namespace> -o jsonpath='{.metadata.annotations}' && echo
   ```

2. Verify annotation format:
   ```bash
   kubectl get namespace <namespace> -o jsonpath='{.metadata.annotations.replicate-secret}'
   ```

3. Check if source secret exists:
   ```bash
   kubectl get secret <secret-name> -n <source-namespace>
   ```

4. Check controller logs for errors

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `make test`
5. Format code: `make fmt`
6. Submit a pull request

## License

This project is open source and available under the MIT License.

## Resources

- [Kubernetes Go Client Documentation](https://pkg.go.dev/k8s.io/client-go)
- [Kubernetes Controller Patterns](https://kubernetes.io/docs/concepts/architecture/controller/)
- [Go by Example](https://gobyexample.com/)
