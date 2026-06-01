# Nginx Kubernetes workflow

This walkthrough explains what happens when the nginx manifests are applied in
order:

1. `examples/nginx/01-pod.yaml`
2. `examples/nginx/02-deployment.yaml`
3. `examples/nginx/03-application.yaml`

## Step 1: apply the standalone Pod

Command:

```sh
make nginx-pod
```

This applies `01-pod.yaml`, which creates one Kubernetes `Pod` named
`nginx-pod` in the default namespace.

Conceptually:

```text
Pod nginx-pod
+-- nginx container
```

The Pod directly runs one nginx container from the `nginx:1.27-alpine` image.
This is the smallest useful unit in Kubernetes, but it is not self-healing in
the same way a Deployment is. If this standalone Pod is deleted, Kubernetes does
not create a replacement because no higher-level controller owns it.

Use this step to learn:

- A Pod wraps one or more containers.
- A Pod has labels, container ports, and health probes.
- A standalone Pod is useful for learning, debugging, and one-off work, but it
  is usually not how applications are run in production.

## Step 2: apply the Deployment

Command:

```sh
make nginx-deployment
```

This applies `02-deployment.yaml`, which creates a Kubernetes `Deployment`
named `nginx-deployment` in the default namespace.

Conceptually:

```text
Deployment nginx-deployment
+-- ReplicaSet
    +-- nginx Pod
    +-- nginx Pod
```

The Deployment does not reuse or take over the standalone `nginx-pod` from the
first step. Instead, it creates its own ReplicaSet, and the ReplicaSet creates
two Pods because `replicas: 2` is configured.

The Deployment adds important behavior:

- It keeps the desired number of Pods running.
- It replaces Pods that fail or are deleted.
- It supports scaling up and down.
- It supports rolling updates when the Pod template changes.

Use this step to learn that a Deployment is a controller. You describe the
desired state, and Kubernetes continuously works to keep the actual state
matching it.

## Step 3: apply the application manifest

Command:

```sh
make nginx-app
```

This applies `03-application.yaml`, which creates several resources:

```text
Namespace learn-nginx
ConfigMap nginx-homepage
Deployment nginx-app
Service nginx-app
```

These resources are grouped in one YAML file because they work together as a
small application.

Conceptually:

```text
Namespace learn-nginx
+-- ConfigMap nginx-homepage
+-- Deployment nginx-app
|   +-- ReplicaSet
|       +-- nginx Pod
|       +-- nginx Pod
+-- Service nginx-app
    +-- forwards traffic to the nginx Pods
```

The namespace keeps this fuller application separate from the earlier default
namespace examples.

The ConfigMap stores a custom `index.html` page. The Deployment mounts that page
into each nginx container. The Service provides a stable network endpoint for
the Pods created by the Deployment.

Use this step to learn that an "application" in Kubernetes is usually a group of
resources, not a single built-in object.

## Final state after all three steps

If you apply all three manifests without cleaning up between steps, you have
resources in two namespaces:

```text
default namespace
+-- Pod nginx-pod
+-- Deployment nginx-deployment
    +-- 2 nginx Pods

learn-nginx namespace
+-- ConfigMap nginx-homepage
+-- Deployment nginx-app
|   +-- 2 nginx Pods
+-- Service nginx-app
```

The learning progression is:

```text
Pod -> Deployment -> Application
```

- Pod: runs the container.
- Deployment: manages and heals Pods.
- Application: combines workload, configuration, namespace isolation, and
  stable networking.

## Accessing the application

After applying `03-application.yaml`, run:

```sh
make nginx-port-forward
```

Then open:

```text
http://localhost:8080
```

The request goes from your browser to the local port-forward, then to the
`nginx-app` Service, then to one of the nginx Pods.

## Cleaning up

Run:

```sh
make nginx-clean
```

This deletes the resources from all three learning steps.
