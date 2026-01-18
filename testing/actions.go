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
		// For out of the cluster
		config, err := clientcmd.BuildConfigFromFlags("", kubeconfigPath)
		if err != nil {
			return nil, fmt.Errorf("unable to load kubeconfig from %s: %v", kubeconfigPath, err)
		}
		kubeconfig = config
	} else {
		// For incluster congig value.
		config, err := rest.InClusterConfig()
		if err == nil {
			return config, nil
		}
		fmt.Println("got the config")
		if err != nil {
			return nil, fmt.Errorf("unable to load in-cluster config: %s", err)
		}
		kubeconfig = config
	}

	// Return the config
	client, err := kubernetes.NewForConfig(kubeconfig)
	if err != nil {
		return nil, fmt.Errorf("unable to create a client: %s", err)
	}

	return client, nil
}

func main() {
	// Binary program outside the k8s cluster, access the cluster using the kubeconfig file.
	home := homedir.HomeDir()

	kubeconfigPath := filepath.Join(home, ".kube", "config")
	fmt.Printf(kubeconfigPath)

	// Creating the client set using the funciton createClient
	clientset, err := createClient(kubeconfigPath)
	if err != nil {
		fmt.Errorf("error %s, getting error in clientset creation.", err)
	}

	// example: use clientset to list all the pods in namespace
	ns := "kube-system"
	ctx := context.Background()
	// ctx := context.TODO()

	pods, err := clientset.CoreV1().Pods(ns).List(ctx, metav1.ListOptions{})
	if err != nil {
		panic(err)
	}
	fmt.Println("Pods:- ")
	for _, pod := range pods.Items {
		fmt.Printf("%s \n", pod.Name)
	}
	// example: list all the deployments
	deployments, _ := clientset.AppsV1().Deployments(ns).List(ctx, metav1.ListOptions{})
	if err != nil {
		panic(err)
	}
	fmt.Println("Deployments:- ")
	for _, d := range deployments.Items {
		fmt.Printf("%s \n", d.Name)
	}

}
