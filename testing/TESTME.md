### Inside k8s authentication 

Run the program inside the k8s cluster.

Dockerize the application. 
Push to the container registery.
Deploy the image into the k8s cluster.
Now that the container/application program is deployed into the cluster we can say it's running inside the K8s cluster. 
 
#### Method to get configuration while running inside cluster. 
Get cluster configuration while the pod is running inside the cluster. 

rest.InClusterConfig()
- Looks for the path where service account gets mounted. Uses it to authenticate to our program against k8s cluster. Reads the details from the path where kubelet mounts the default service account.
```go
tokenFile = "/var/run/secrets/kubernetes.io/serviceaccount/token"
rootCAFile = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
```
- Whenever a pod gets created in K8s cluster, a default service account get mounted inside that pod, and that service account is going to be used to talk to the API server. 
- Because we have to specify the authentication details when we talk to the API server. 

- Application is using the default service account mounted to the pod so it wont be able to perform some actions. 

Create role, which will allow to list pod and deploy from default ns
Create a roleBinding to bind the role with the serviceaccount 
serviceaccount is namespace scoped, the service account is attached to the namespace?
now attach that service account to the pod. 

But we should create cluster role and cluster role binding and attach that to servce account which is namespace scoped!
- But we will only give list access, not delete to our controller namespace. 

next:
mount the service account!!


command:
-> Get deployment yaml 
```bash
k create deployment actions --image rahul079/actions:0.1.0 --dry-run=client -oyaml > actions.yaml

k create -f actions.yaml
```