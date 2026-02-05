package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"namespacecontroller/pkg/client"
	"namespacecontroller/pkg/controller"
)

func main() {
	var kubeconfigPath string

	// Check if we're running inside Kubernetes (in-cluster)
	// If KUBERNETES_SERVICE_HOST is set, we're in-cluster
	if os.Getenv("KUBERNETES_SERVICE_HOST") == "" {
		// Running locally, use kubeconfig
		kubeconfigPath = client.GetKubeconfigPath()
		fmt.Println("Running in local mode, using kubeconfig:", kubeconfigPath)
	} else {
		// Running in-cluster, use empty string to trigger in-cluster config
		kubeconfigPath = ""
		fmt.Println("Running in-cluster mode")
	}

	// Create the Kubernetes client
	clientset, err := client.CreateClient(kubeconfigPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating client: %v\n", err)
		os.Exit(1)
	}

	// Create the controller
	ctrl := controller.NewController(clientset)

	fmt.Println("Controller started successfully!")
	fmt.Println("Waiting for namespaces with 'replicate-secret' annotation...")
	fmt.Printf("Annotation format: %s: source-namespace/secret-name\n", controller.ReplicationAnnotationKey)
	fmt.Println()

	// Set up signal handling for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	// Start controller in a goroutine
	errChan := make(chan error, 1)
	go func() {
		errChan <- ctrl.Start(ctx)
	}()

	// Wait for signal or error
	select {
	case sig := <-sigChan:
		fmt.Printf("\nReceived signal: %v, shutting down gracefully...\n", sig)
		cancel()
		<-errChan // Wait for controller to stop
	case err := <-errChan:
		if err != nil {
			fmt.Fprintf(os.Stderr, "Controller error: %v\n", err)
			os.Exit(1)
		}
	}

	fmt.Println("Controller stopped")
}
