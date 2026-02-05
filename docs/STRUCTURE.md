# Project Structure

This document describes the directory structure of the namespace controller project.

## Directory Layout

```
namespacecontroller/
├── cmd/
│   └── controller/
│       └── main.go                 # Application entry point
│
├── pkg/
│   ├── client/
│   │   └── client.go               # Kubernetes client creation
│   └── controller/
│       └── controller.go           # Core controller logic
│
├── config/
│   ├── rbac/
│   │   └── rbac.yaml               # RBAC manifests (ServiceAccount, ClusterRole, ClusterRoleBinding)
│   └── manager/
│       └── manager.yaml            # Deployment manifest
│
├── deploy/
│   ├── controller.yaml             # Combined deployment (all-in-one)
│   └── examples/
│       └── example-namespace.yaml   # Example namespace with replication annotation
│
├── build/
│   └── Dockerfile                  # Container image build definition
│
├── docs/
│   ├── LEARNING_GUIDE.md           # Learning guide for developers
│   ├── README_DEPLOYMENT.md        # Deployment instructions
│   └── STRUCTURE.md                # This file
│
├── bin/                            # Build output (gitignored)
│   └── controller                  # Compiled binary
│
├── Makefile                        # Build automation
├── go.mod                          # Go module definition
├── go.sum                          # Go module checksums
├── .dockerignore                   # Docker build exclusions
├── .gitignore                      # Git exclusions
└── README.md                       # Main project documentation
```

## Package Descriptions

### `cmd/controller/`

Contains the main application entry point. This package:
- Initializes the Kubernetes client
- Detects in-cluster vs local mode
- Sets up signal handling for graceful shutdown
- Starts the controller

**Key functions:**
- `main()` - Entry point, handles initialization and signal processing

### `pkg/client/`

Provides Kubernetes client creation functionality. This package:
- Creates Kubernetes clientsets
- Handles both in-cluster and local kubeconfig scenarios
- Provides helper functions for kubeconfig path resolution

**Key functions:**
- `CreateClient(kubeconfigPath string)` - Creates a Kubernetes client interface
- `GetKubeconfigPath()` - Returns default kubeconfig path for local development

### `pkg/controller/`

Contains the core controller logic. This package:
- Watches for namespace creation events
- Parses replication annotation
- Retrieves source secrets
- Creates secrets in target namespaces

**Key types:**
- `Controller` - Main controller struct

**Key functions:**
- `NewController(clientset)` - Creates a new controller instance
- `Start(ctx)` - Begins watching namespaces
- `handleNamespaceCreated()` - Processes namespace creation events
- `parseReplicationLabel()` - Extracts source namespace and secret name from labels
- `getSourceSecret()` - Retrieves secret from source namespace
- `createSecretInNamespace()` - Creates secret copy in target namespace

## Configuration Files

### `config/rbac/rbac.yaml`

Contains RBAC (Role-Based Access Control) manifests:
- **ServiceAccount**: Identity for the controller pod
- **ClusterRole**: Permissions needed (watch namespaces, get/create secrets)
- **ClusterRoleBinding**: Binds the ClusterRole to the ServiceAccount

### `config/manager/manager.yaml`

Contains the Deployment manifest for the controller:
- Container image specification
- Resource limits and requests
- Service account reference

### `deploy/controller.yaml`

Combined manifest that includes both RBAC and Deployment. Useful for quick deployment.

## Build Files

### `build/Dockerfile`

Multi-stage Docker build:
1. **Builder stage**: Compiles the Go binary
2. **Runtime stage**: Minimal Alpine image with the binary

### `Makefile`

Provides convenient commands for:
- Building (local and Docker)
- Testing
- Deployment
- Local development

## Documentation

### `docs/LEARNING_GUIDE.md`

Comprehensive guide for learning:
- Step-by-step implementation instructions
- Go concepts explained
- Testing procedures
- Common pitfalls

### `docs/README_DEPLOYMENT.md`

Deployment guide covering:
- Building Docker images
- Deploying to Kubernetes
- Testing the controller
- Troubleshooting

## Best Practices

This structure follows Go and Kubernetes operator best practices:

1. **Separation of concerns**: Business logic in `pkg/`, entry point in `cmd/`
2. **Reusability**: Packages can be imported by other projects
3. **Testability**: Clear package boundaries make testing easier
4. **Standard layout**: Follows common Go project structure conventions
5. **Kubernetes conventions**: Config files organized by purpose (RBAC, manager)

## Adding New Features

When adding new features:

1. **New packages**: Add to `pkg/` if reusable, or keep in existing package if specific
2. **New commands**: Add to `cmd/` if creating a new binary
3. **New configs**: Add to `config/` with appropriate subdirectory
4. **New examples**: Add to `deploy/examples/`
5. **Documentation**: Update relevant docs in `docs/`

## Build Output

The `bin/` directory contains compiled binaries and is gitignored. Build with:
```bash
make build        # Creates bin/controller
```

## Dependencies

Dependencies are managed via `go.mod` and `go.sum`. Add new dependencies with:
```bash
go get <package>
```
