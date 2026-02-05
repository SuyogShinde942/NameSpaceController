# Deployment Guide

This guide will help you build and deploy the namespace controller to your Kubernetes cluster.

## Prerequisites

- Docker installed
- Kubernetes cluster (local or remote)
- kubectl configured to access your cluster
- Go 1.21+ (for local development)

## Step 1: Build the Docker Image

### Option A: Build and push to a registry

```bash
# Build the image
docker build -t your-registry/namespace-controller:latest .

# Push to registry (replace with your registry)
docker push your-registry/namespace-controller:latest
```

### Option B: Build and load for local cluster (kind/minikube)

For **kind**:
```bash
docker build -t namespace-controller:latest .
kind load docker-image namespace-controller:latest
```

For **minikube**:
```bash
eval $(minikube docker-env)
docker build -t namespace-controller:latest .
```

## Step 2: Update the Deployment Image

If you used a registry, update `controller.yaml`:
```yaml
image: your-registry/namespace-controller:latest
```

If using local image (kind/minikube), it's already set to:
```yaml
image: namespace-controller:latest
imagePullPolicy: IfNotPresent
```

## Step 3: Deploy the Controller

```bash
kubectl apply -f controller.yaml
```

Verify the deployment:
```bash
kubectl get deployment namespace-controller -n default
kubectl get pods -n default -l app=namespace-controller
```

## Step 4: Check Controller Logs

```bash
kubectl logs -f deployment/namespace-controller -n default
```

You should see:
```
Controller started successfully!
Waiting for namespaces with 'replicate-secret' annotation...
Annotation format: replicate-secret: source-namespace/secret-name
```

## Step 5: Test the Controller

### 5.1 Create a source secret

```bash
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123 \
  -n default
```

### 5.2 Create a namespace with replication annotation

```bash
kubectl create namespace test-namespace
kubectl annotate namespace test-namespace replicate-secret="default/my-secret"
```

Or use the example file:
```bash
kubectl apply -f example-namespace.yaml
```

### 5.3 Verify secret replication

```bash
# Check if secret was created
kubectl get secret my-secret -n test-namespace

# Verify the secret data
kubectl get secret my-secret -n test-namespace -o yaml
```

### 5.4 Check controller logs

```bash
kubectl logs -f deployment/namespace-controller -n default
```

You should see:
```
New namespace created: test-namespace
  Found replication annotation: source=default, secret=my-secret
  Successfully replicated secret my-secret to namespace test-namespace
```

## Troubleshooting

### Controller not starting

1. Check pod status:
   ```bash
   kubectl describe pod -l app=namespace-controller -n default
   ```

2. Check logs:
   ```bash
   kubectl logs -l app=namespace-controller -n default
   ```

### Permission errors

If you see permission errors, verify RBAC:
```bash
kubectl get clusterrole namespace-controller-cluster-role
kubectl get clusterrolebinding namespace-controller-cluster-binding
kubectl get serviceaccount namespace-controller -n default
```

### Secret not replicated

1. Check if namespace has the correct annotation:
   ```bash
   kubectl get namespace test-namespace -o jsonpath='{.metadata.annotations}' && echo
   ```

2. Verify annotation format (should be `namespace/secret-name`):
   ```bash
   kubectl get namespace test-namespace -o jsonpath='{.metadata.annotations.replicate-secret}'
   ```

3. Check if source secret exists:
   ```bash
   kubectl get secret my-secret -n default
   ```

4. Check controller logs for errors

## Cleanup

To remove the controller:
```bash
kubectl delete -f controller.yaml
```

To remove test resources:
```bash
kubectl delete namespace test-namespace
kubectl delete secret my-secret -n default
```

## Development Mode (Local Testing)

For local development without Docker:

1. Make sure you have a valid kubeconfig:
   ```bash
   kubectl config current-context
   ```

2. Run the controller locally:
   ```bash
   go run main.go
   ```

3. In another terminal, create test resources as described above.

The controller will automatically detect it's running locally and use your kubeconfig file.
