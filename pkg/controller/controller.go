package controller

import (
	"context"
	"fmt"
	"strings"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/watch"
	"k8s.io/client-go/kubernetes"
)

const (
	// ReplicationAnnotationKey is the annotation key used to trigger secret replication (annotations allow "/" in values)
	ReplicationAnnotationKey = "replicate-secret"
)

// Controller handles namespace watching and secret replication
type Controller struct {
	clientset kubernetes.Interface
}

// NewController creates a new controller instance
func NewController(clientset kubernetes.Interface) *Controller {
	return &Controller{
		clientset: clientset,
	}
}

// Start begins watching namespaces and processing events
func (c *Controller) Start(ctx context.Context) error {
	watcher, err := c.clientset.CoreV1().Namespaces().Watch(ctx, metav1.ListOptions{})
	if err != nil {
		return fmt.Errorf("failed to create namespace watcher: %v", err)
	}
	defer watcher.Stop()

	fmt.Println("Watching for namespace events...")
	for {
		select {
		case <-ctx.Done():
			fmt.Println("Context cancelled, stopping watcher...")
			return nil
		case event, ok := <-watcher.ResultChan():
			if !ok {
				return fmt.Errorf("watcher channel closed")
			}

			if event.Type == watch.Added {
				namespace, ok := event.Object.(*corev1.Namespace)
				if !ok {
					fmt.Printf("Error: could not convert to Namespace type\n")
					continue
				}

				c.handleNamespaceCreated(namespace)
			}
		}
	}
}

// handleNamespaceCreated processes namespace creation events and replicates secrets if needed
func (c *Controller) handleNamespaceCreated(namespace *corev1.Namespace) {
	fmt.Printf("New namespace created: %s\n", namespace.Name)

	// Parse the replication annotation (format: "source-namespace/secret-name"; annotations allow "/")
	sourceNS, secretName, found := parseReplicationAnnotation(namespace.Annotations)
	if !found {
		fmt.Printf("  No replication annotation found, skipping...\n")
		return
	}

	fmt.Printf("  Found replication annotation: source=%s, secret=%s\n", sourceNS, secretName)

	// Get the source secret
	sourceSecret, err := c.getSourceSecret(sourceNS, secretName)
	if err != nil {
		fmt.Printf("  Error getting source secret: %v\n", err)
		return
	}

	// Create secret in target namespace
	newSecret, err := c.createSecretInNamespace(namespace.Name, sourceSecret)
	if err != nil {
		// Check if secret already exists (this is okay, we can skip)
		if strings.Contains(err.Error(), "already exists") {
			fmt.Printf("  Secret %s already exists in namespace %s, skipping...\n", secretName, namespace.Name)
			return
		}
		fmt.Printf("  Error creating secret: %v\n", err)
		return
	}

	fmt.Printf("  Successfully replicated secret %s to namespace %s\n", newSecret.Name, namespace.Name)
}

// parseReplicationAnnotation extracts source namespace and secret name from the annotation
// Annotation format: replicate-secret: "source-namespace/secret-name" (annotations allow "/" in values)
// Example: replicate-secret: "default/my-secret"
func parseReplicationAnnotation(annotations map[string]string) (sourceNamespace, secretName string, found bool) {
	value, exists := annotations[ReplicationAnnotationKey]
	if !exists {
		return "", "", false
	}

	parts := strings.Split(value, "/")
	if len(parts) != 2 {
		return "", "", false
	}

	return strings.TrimSpace(parts[0]), strings.TrimSpace(parts[1]), true
}

// getSourceSecret retrieves the secret from the source namespace
func (c *Controller) getSourceSecret(sourceNamespace, secretName string) (*corev1.Secret, error) {
	secret, err := c.clientset.CoreV1().Secrets(sourceNamespace).Get(context.TODO(), secretName, metav1.GetOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to get secret %s from namespace %s: %v", secretName, sourceNamespace, err)
	}
	return secret, nil
}

// createSecretInNamespace creates a copy of the source secret in the target namespace
func (c *Controller) createSecretInNamespace(targetNamespace string, sourceSecret *corev1.Secret) (*corev1.Secret, error) {
	// Create a new Secret object - we must create a copy, not reuse the source
	newSecret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      sourceSecret.Name,
			Namespace: targetNamespace,
			Labels:    sourceSecret.Labels,
		},
		Type: sourceSecret.Type,
		Data: make(map[string][]byte),
	}

	// Copy the secret data
	for k, v := range sourceSecret.Data {
		// Create a copy of the byte slice to avoid reference issues
		dataCopy := make([]byte, len(v))
		copy(dataCopy, v)
		newSecret.Data[k] = dataCopy
	}

	// Copy string data if present
	if sourceSecret.StringData != nil {
		newSecret.StringData = make(map[string]string)
		for k, v := range sourceSecret.StringData {
			newSecret.StringData[k] = v
		}
	}

	// Create the secret in the target namespace
	createdSecret, err := c.clientset.CoreV1().Secrets(targetNamespace).Create(context.TODO(), newSecret, metav1.CreateOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to create secret %s in namespace %s: %v", sourceSecret.Name, targetNamespace, err)
	}

	return createdSecret, nil
}
