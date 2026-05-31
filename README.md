# learn-k8s

Small Kubernetes examples for learning how workloads move from a single Pod to
a managed Deployment and then to an application that can be reached through a
Service.

## Prerequisites

Install the local tooling:

```sh
make install
make verify
```

Start Rancher Desktop with Kubernetes enabled before applying manifests.

## Nginx learning path

The nginx example lives in [`examples/nginx`](examples/nginx):

| Step | Manifest | What it teaches |
| --- | --- | --- |
| Pod | `01-pod.yaml` | A single nginx container running directly as a Pod. |
| Deployment | `02-deployment.yaml` | A controller that keeps nginx replicas running and replaces failed Pods. |
| Application | `03-application.yaml` | A namespace, custom homepage, Deployment, and Service working together. |

Apply each step:

```sh
make nginx-pod
kubectl get pod nginx-pod

make nginx-deployment
kubectl get deployment nginx-deployment
kubectl get pods -l app=nginx

make nginx-app
kubectl get all -n learn-nginx
```

Open the full application locally:

```sh
make nginx-port-forward
```

Then visit <http://localhost:8080>.

Clean everything up:

```sh
make nginx-clean
```

The "Application" step is not a special Kubernetes resource in this example.
It is the practical unit users interact with: a Deployment for running Pods plus
a Service for stable network access.
