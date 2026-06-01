# Kubernetes Service types

A Kubernetes `Service` gives Pods a stable network identity.

Pods are temporary. A Deployment can delete and recreate them during scaling,
healing, or rolling updates. Each replacement Pod can get a new IP address. A
Service solves that problem by selecting the right Pods and giving clients one
stable place to send traffic.

## How a Service finds Pods

A Service usually uses `spec.selector` to match Pod labels:

```yaml
spec:
  selector:
    app: nginx
    component: web
```

This means the Service sends traffic to Pods that have both labels:

```yaml
metadata:
  labels:
    app: nginx
    component: web
```

Kubernetes watches for matching Pods and records their IPs behind the Service
using EndpointSlice objects. Clients do not need to know which exact Pod is
currently running.

Conceptually:

```text
Client
  |
  v
Service
  |
  +-- Pod app=nginx, component=web
  +-- Pod app=nginx, component=web
```

The examples for this topic live in
[`examples/services`](../examples/services).

Start with the shared workload:

```sh
kubectl apply -f examples/services/00-demo-app.yaml
```

That creates:

- a namespace named `service-types-demo`
- a Deployment named `nginx-web`
- two nginx Pods labeled `app=nginx` and `component=web`

## ClusterIP

`ClusterIP` is the default Service type.

It creates an internal-only virtual IP address that is reachable from inside the
Kubernetes cluster. It does not directly expose the application outside the
cluster.

Example:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-clusterip
spec:
  type: ClusterIP
  selector:
    app: nginx
    component: web
  ports:
    - port: 80
      targetPort: http
```

Apply the example:

```sh
kubectl apply -f examples/services/01-clusterip-service.yaml
```

Inspect it:

```sh
kubectl -n service-types-demo get service nginx-clusterip
kubectl -n service-types-demo get endpointslices -l kubernetes.io/service-name=nginx-clusterip
```

Access it locally with port-forwarding:

```sh
kubectl -n service-types-demo port-forward service/nginx-clusterip 8080:80
```

Then open:

```text
http://localhost:8080
```

Use ClusterIP when:

- one app inside the cluster needs to call another app inside the cluster
- you want a stable internal name for a Deployment
- external users do not need direct access

Common examples:

- frontend to backend traffic
- backend to database traffic
- internal APIs

Inside the cluster, other workloads can reach this Service with DNS:

```text
nginx-clusterip.service-types-demo.svc.cluster.local
```

## NodePort

`NodePort` exposes a Service on a port across every Kubernetes node.

It still creates a ClusterIP internally, but it also opens a static port on each
node. Traffic sent to any node on that port is forwarded to the selected Pods.

Example:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
spec:
  type: NodePort
  selector:
    app: nginx
    component: web
  ports:
    - port: 80
      targetPort: http
      nodePort: 30080
```

Apply the example:

```sh
kubectl apply -f examples/services/02-nodeport-service.yaml
```

Inspect it:

```sh
kubectl -n service-types-demo get service nginx-nodeport
```

Access it:

```text
http://<node-ip>:30080
```

On many local clusters, this may work with:

```text
http://localhost:30080
```

Use NodePort when:

- you are learning how external Service exposure works
- you need a simple local or lab-cluster access path
- another external load balancer will send traffic to node IPs and node ports

NodePort is usually not the best final user-facing option for production
applications because it exposes node-level ports directly and gives less control
than an Ingress or cloud LoadBalancer.

By default, Kubernetes assigns NodePorts from this range:

```text
30000-32767
```

In the example, the port is set explicitly to `30080` so it is easy to remember.
If you omit `nodePort`, Kubernetes chooses an available port from the configured
range.

## LoadBalancer

`LoadBalancer` asks the cluster's infrastructure provider to create an external
load balancer for the Service.

It also creates the lower-level Service behavior:

```text
LoadBalancer
  includes NodePort behavior
    includes ClusterIP behavior
```

Example:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-loadbalancer
spec:
  type: LoadBalancer
  selector:
    app: nginx
    component: web
  ports:
    - port: 80
      targetPort: http
```

Apply the example:

```sh
kubectl apply -f examples/services/03-loadbalancer-service.yaml
```

Watch for an external address:

```sh
kubectl -n service-types-demo get service nginx-loadbalancer --watch
```

On a cloud cluster, the `EXTERNAL-IP` field eventually receives the load
balancer address:

```text
NAME                 TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)
nginx-loadbalancer   LoadBalancer   10.43.10.101    203.0.113.10     80:31234/TCP
```

You can then open:

```text
http://203.0.113.10
```

On a local cluster, `EXTERNAL-IP` may stay `pending` unless your local
Kubernetes distribution includes load balancer support. Rancher Desktop with
k3s may provide local load balancer behavior depending on its configuration.
Other local options include MetalLB or a built-in service load balancer.

Use LoadBalancer when:

- you are on a cloud provider or local cluster with load balancer support
- you want a simple external IP or hostname for one Service
- you do not need path-based or hostname-based routing across many apps

For many HTTP applications, production setups use an Ingress or Gateway in front
of one or more ClusterIP Services. LoadBalancer is still common for exposing the
Ingress controller itself.

## Comparison

| Type | Reachable from | External access | Common use |
| --- | --- | --- | --- |
| `ClusterIP` | Inside the cluster | No direct external access | Internal app-to-app traffic |
| `NodePort` | Node IP plus static port | Yes, through every node | Local learning, labs, simple exposure |
| `LoadBalancer` | External load balancer address | Yes, through provider-managed load balancer | Cloud-facing services, ingress controllers |

## Traffic path examples

ClusterIP:

```text
Pod or port-forward
  -> Service ClusterIP
  -> matching nginx Pod
```

NodePort:

```text
Browser
  -> node-ip:30080
  -> NodePort Service
  -> matching nginx Pod
```

LoadBalancer:

```text
Browser
  -> external load balancer IP
  -> LoadBalancer Service
  -> matching nginx Pod
```

## Cleanup

Delete the example Services and workload:

```sh
kubectl delete -f examples/services/03-loadbalancer-service.yaml --ignore-not-found=true
kubectl delete -f examples/services/02-nodeport-service.yaml --ignore-not-found=true
kubectl delete -f examples/services/01-clusterip-service.yaml --ignore-not-found=true
kubectl delete -f examples/services/00-demo-app.yaml --ignore-not-found=true
```
