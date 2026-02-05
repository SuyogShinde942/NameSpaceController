# Learning Guide: Secret Replication Controller

## Overview
This guide will help you implement a Kubernetes controller that replicates secrets from a source namespace to target namespaces based on a namespace annotation.

## How It Works

### Annotation Format
When creating a namespace, add this annotation (we use an annotation because label values cannot contain `/`):
```yaml
metadata:
  annotations:
    replicate-secret: "source-namespace/secret-name"
```

Example:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-new-namespace
  annotations:
    replicate-secret: "default/my-secret"
```

This tells the controller: "When this namespace is created, copy the secret `my-secret` from the `default` namespace into this namespace."

## Implementation Steps

### Step 1: Parse the Replication Annotation ✅ (Your Task)

**Function:** `parseReplicationAnnotation(annotations map[string]string)`

**What you need to do:**
1. Check if the `replicate-secret` annotation exists in the annotations map
2. Split the value by "/" to get namespace and secret name
3. Return the values

**Go concepts you'll learn:**
- Working with `map[string]string` (Go's map/dictionary)
- String manipulation with `strings.Split()`
- Multiple return values in Go
- The `ok` idiom: `value, exists := map[key]`

**Example code structure:**
```go
value, exists := annotations["replicate-secret"]
if !exists {
    return "", "", false  // Annotation not found
}
parts := strings.Split(value, "/")
if len(parts) != 2 {
    return "", "", false  // Invalid format
}
return parts[0], parts[1], true  // namespace, secret-name, found
```

**Test it:**
- Try with valid annotation: `"default/my-secret"`
- Try with missing annotation
- Try with invalid format: `"just-a-string"`

---

### Step 2: Get the Source Secret (Your Task)

**Function:** `getSourceSecret(clientset, sourceNamespace, secretName)`

**What you need to do:**
1. Use the Kubernetes client to get a secret
2. Handle errors (secret might not exist!)

**Go concepts you'll learn:**
- Working with Kubernetes API client
- Error handling in Go
- Context usage (`context.TODO()`)

**Kubernetes API pattern:**
```go
secret, err := clientset.CoreV1().Secrets(sourceNamespace).Get(
    context.TODO(), 
    secretName, 
    metav1.GetOptions{},
)
```

**Important:** Always check for errors! The secret might not exist.

---

### Step 3: Create Secret in Target Namespace ✅ (Your Task)

**Function:** `createSecretInNamespace(clientset, targetNamespace, sourceSecret)`

**What you need to do:**
1. Create a **new** Secret object (don't reuse the source secret!)
2. Copy the secret data and type
3. Set the namespace to the target namespace
4. Create it using the API

**Go concepts you'll learn:**
- Creating new objects in Go
- Copying data (maps, slices)
- Struct initialization
- Pointer types (`*corev1.Secret`)

**Important concepts:**
- You MUST create a new Secret object, not modify the source one
- The `Data` field is `map[string][]byte` - you need to copy it
- Set `Namespace` in `ObjectMeta` to the target namespace
- Remove any source-specific metadata (like UID, ResourceVersion)

**Example structure:**
```go
newSecret := &corev1.Secret{
    ObjectMeta: metav1.ObjectMeta{
        Name:      sourceSecret.Name,  // Same name
        Namespace: targetNamespace,    // Different namespace!
    },
    Data: make(map[string][]byte),
    Type: sourceSecret.Type,
}

// Copy the data
for k, v := range sourceSecret.Data {
    newSecret.Data[k] = v
}

// Create it
createdSecret, err := clientset.CoreV1().Secrets(targetNamespace).Create(
    context.TODO(),
    newSecret,
    metav1.CreateOptions{},
)
```

---

### Step 4: Complete the Handler ✅ (Your Task)

**Function:** `handleNamespaceCreated()`

**What you need to do:**
1. Uncomment the TODO sections
2. Call the functions you implemented
3. Handle errors gracefully

**Go concepts you'll learn:**
- Function composition
- Error handling patterns
- Control flow

---

## Key Go Concepts You'll Learn

### 1. Maps (Dictionaries)
```go
labels := map[string]string{
    "key1": "value1",
    "key2": "value2",
}

// Check if key exists
value, exists := labels["key1"]
if exists {
    // Use value
}
```

### 2. Multiple Return Values
```go
func parseLabel(labels map[string]string) (string, string, bool) {
    return "namespace", "secret", true
}

// Usage
ns, secret, found := parseLabel(labels)
```

### 3. Error Handling
```go
secret, err := getSecret()
if err != nil {
    // Handle error - don't ignore it!
    fmt.Printf("Error: %v\n", err)
    return
}
// Use secret
```

### 4. Pointers
```go
// *corev1.Secret is a pointer to a Secret object
func createSecret(secret *corev1.Secret) {
    // secret is a pointer, modify it carefully
}

// Create a new secret
newSecret := &corev1.Secret{
    // ... fields
}
```

### 5. Struct Initialization
```go
secret := &corev1.Secret{
    ObjectMeta: metav1.ObjectMeta{
        Name: "my-secret",
    },
    Data: make(map[string][]byte),
}
```

---

## Testing Your Controller

### 1. Create a source secret:
```bash
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123 \
  -n default
```

### 2. Create a namespace with the annotation:
```bash
kubectl create namespace test-namespace
kubectl annotate namespace test-namespace replicate-secret="default/my-secret"
```

Or create a YAML file:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace
  annotations:
    replicate-secret: "default/my-secret"
```

### 3. Run your controller:
```bash
go run main.go
```

### 4. Apply the namespace:
```bash
kubectl apply -f namespace.yaml
```

### 5. Verify the secret was replicated:
```bash
kubectl get secret my-secret -n test-namespace
```

---

## Common Pitfalls

1. **Not copying the secret data** - You must create a new object, not reuse the source
2. **Forgetting to set the namespace** - The secret must be created in the target namespace
3. **Ignoring errors** - Always check and handle errors
4. **Not validating annotation format** - Check that the annotation value has the correct format

---

## Next Steps (Advanced)

Once you complete the basic implementation:

1. **Watch for secret updates** - If the source secret changes, update all replicated secrets
2. **Handle namespace deletion** - Clean up replicated secrets when namespace is deleted
3. **Add label selector** - Only replicate to namespaces with specific labels
4. **Add logging** - Use a proper logging library instead of `fmt.Printf`
5. **Add metrics** - Track how many secrets have been replicated

---

## Resources

- [Kubernetes Go Client Documentation](https://pkg.go.dev/k8s.io/client-go)
- [Go by Example](https://gobyexample.com/)
- [Effective Go](https://go.dev/doc/effective_go)

---

## Questions to Think About

1. What happens if the source secret doesn't exist?
2. What if the secret already exists in the target namespace?
3. Should you update existing secrets or skip them?
4. How would you handle multiple secrets to replicate?

Good luck! 🚀
