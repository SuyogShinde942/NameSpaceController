package main

import (
	"context"
	"fmt"
	"path/filepath"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"
)

func createClient(kubeconfigPath string) (kubernetes.Interface, error) {
	var kubeconfig *rest.Config

	if kubeconfigPath != "" {
		config, err := clientcmd.BuildConfigFromFlags("", kubeconfigPath)
		if err != nil {
			return nil, fmt.Errorf("unable to load kubeconfig from %s: %v", kubeconfigPath, err)
		}
		kubeconfig = config
	} else {
		config, err := rest.InClusterConfig()
		if err != nil {
			return nil, fmt.Errorf("unable to load in-cluster config: %v", err)
		}
		kubeconfig = config
	}
	// I am returning the config now
	client, err := kubernetes.NewForConfig(kubeconfig)
	if err != nil {
		return nil, fmt.Errorf("unable to create a client: %v", err)
	}

	return client, nil
}

func main() {
	home := homedir.HomeDir()

	kubeconfigPath := filepath.Join(home, ".kube", "config")
	// Creating the client set using the funciton createClient
	clientset, err := createClient(kubeconfigPath)
	if err != nil {
		panic(err)
	}
	deploymentList, err := clientset.AppsV1().Deployments("default").List(context.TODO(), metav1.ListOptions{})
	if err != nil {
		panic(err)
	}

	fmt.Println("---- Deployments ----")
	for i, d := range deploymentList.Items {
		fmt.Printf("Index: %d | Deployment: %s\n", i, d.Name)
	}

	podList, err := clientset.CoreV1().Pods("default").List(context.TODO(), metav1.ListOptions{})
	if err != nil {
		panic(err)
	}

	fmt.Println("---- Pods ----")
	for i, p := range podList.Items {
		fmt.Printf("Index: %d | Pod: %s | Phase: %s\n", i, p.Name, p.Status.Phase)
	}
}
