package main

/*
There are two ways to run a program,
1. Inside the K8s cluster : Create client inside K8s cluster. Need to dockerize the program/process.
2. Outside the K8s cluster : Get details of the cluster using kubeconfig file.

Outside the K8s cluster:
In this program, we are using the kubeconfig file to authenticate to the cluster while running the program. OR we can write code in such a way that it can try to figure out the kubeconfig file from the default kubeconfig path.
This process is happening or the program is running outside the cluster so the kubeconfig authentication method should work.
In case in which we want to run the program inside the K8s cluster, then the authentication method will be different.
*/

import (
	"context"
	"flag"
	"fmt"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

func main() {
	// Approach: Binary program outside the k8s cluster, access the cluster using the kubeconfig file.
	// login into the cluster
	// provide a flag to the program that gets the config file or the default is mentioned.
	kubeconfig := flag.String("kubeconfig", "/Users/rahul/.kube/config", "location to your kubeconfig file")
	config, _ := clientcmd.BuildConfigFromFlags("", *kubeconfig)
	// create clients for all api versions
	clientset, _ := kubernetes.NewForConfig(config)

	// example: use clientset to list all the pods in namespace
	ns := "kube-system"
	ctx := context.Background()
	pods, _ := clientset.CoreV1().Pods(ns).List(ctx, metav1.ListOptions{})
	for _, pod := range pods.Items {
		fmt.Printf("%s \n", pod.Name)
	}
	// example: list all the deployments
	deployments, _ := clientset.AppsV1().Deployments(ns).List(ctx, metav1.ListOptions{})
	for _, d := range deployments.Items {
		fmt.Printf("%s \n", d.Name)
	}

}
