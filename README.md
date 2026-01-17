# NameSpaceController

This repository contains a Kubernetes controller built using the official client-go library.
It automatically replicates a source secret into newly created namespaces.
Replication happens only for namespaces that match a specific label selector.
The controller continuously reconciles and ensures the secret stays consistent across namespaces.
Designed for secure, scalable secret distribution in multi-tenant Kubernetes clusters.
