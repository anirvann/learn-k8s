# Service type examples

These examples use one shared nginx Deployment and three different Kubernetes
Service types.

## Apply the demo workload

```sh
kubectl apply -f examples/services/00-demo-app.yaml
```

## Try ClusterIP

```sh
kubectl apply -f examples/services/01-clusterip-service.yaml
kubectl -n service-types-demo get service nginx-clusterip
kubectl -n service-types-demo port-forward service/nginx-clusterip 8080:80
```

Open <http://localhost:8080>.

## Try NodePort

```sh
kubectl apply -f examples/services/02-nodeport-service.yaml
kubectl -n service-types-demo get service nginx-nodeport
```

On a local cluster, try <http://localhost:30080>. On a remote cluster, use the
IP address of one of the Kubernetes nodes:

```text
http://<node-ip>:30080
```

## Try LoadBalancer

```sh
kubectl apply -f examples/services/03-loadbalancer-service.yaml
kubectl -n service-types-demo get service nginx-loadbalancer --watch
```

On a cloud cluster, Kubernetes asks the cloud provider to create an external
load balancer. On some local clusters, the `EXTERNAL-IP` may stay `pending`
unless the local Kubernetes distribution provides load balancer support.

## Cleanup

```sh
kubectl delete -f examples/services/03-loadbalancer-service.yaml --ignore-not-found=true
kubectl delete -f examples/services/02-nodeport-service.yaml --ignore-not-found=true
kubectl delete -f examples/services/01-clusterip-service.yaml --ignore-not-found=true
kubectl delete -f examples/services/00-demo-app.yaml --ignore-not-found=true
```
