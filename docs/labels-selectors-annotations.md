# Labels, selectors, and annotations

Kubernetes objects have metadata. The most common metadata fields you will use
are `labels` and `annotations`.

They look similar because both are key-value maps:

```yaml
metadata:
  labels:
    app: nginx
    component: web
  annotations:
    description: "Demo nginx workload"
```

But they have different jobs.

## Short version

| Metadata | Main purpose | Used for selection? | Example |
| --- | --- | --- | --- |
| Labels | Identify and group objects | Yes | `app: nginx` |
| Selectors | Query or connect objects by label | N/A | `app=nginx,component=web` |
| Annotations | Store extra metadata for tools and humans | No | `prometheus.io/scrape: "true"` |

Use labels when Kubernetes or a human needs to find a group of objects.

Use annotations when you need to attach extra information that should not be
used to select objects.

## Labels

Labels are key-value pairs used to identify Kubernetes objects.

Example Pod labels:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
    component: web
    environment: dev
spec:
  containers:
    - name: nginx
      image: nginx:1.27-alpine
```

These labels answer questions like:

- Which app does this object belong to?
- Which component is this object?
- Which environment is this object running in?

Common label keys:

```yaml
app: nginx
component: web
environment: dev
tier: frontend
version: v1
```

Labels should be small, stable, and meaningful for grouping.

## Selectors

Selectors use labels to find matching objects.

For example:

```sh
kubectl get pods -l app=nginx
kubectl get pods -l app=nginx,component=web
kubectl get pods -l 'environment in (dev,staging)'
```

Selectors are how many Kubernetes resources connect to other resources.

## Example: Deployment selectors

A Deployment uses `spec.selector.matchLabels` to decide which Pods it manages.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
      component: web
  template:
    metadata:
      labels:
        app: nginx
        component: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
```

Important relationship:

```text
Deployment selector:
  app=nginx, component=web

Pod template labels:
  app=nginx, component=web
```

Those must match. The Deployment creates and manages Pods with those labels.

## Example: Service selectors

A Service uses `spec.selector` to decide which Pods should receive traffic.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-web
spec:
  selector:
    app: nginx
    component: web
  ports:
    - port: 80
      targetPort: 80
```

This Service sends traffic to Pods that have both labels:

```yaml
app: nginx
component: web
```

Conceptually:

```text
Service selector app=nginx,component=web
  |
  +-- Pod labels app=nginx,component=web
  +-- Pod labels app=nginx,component=web
```

If another Pod has only `app: nginx` but not `component: web`, this Service will
not route traffic to it.

## Annotations

Annotations are key-value pairs for extra metadata.

They are not meant for selecting objects. Instead, they are commonly read by
tools, controllers, automation, dashboards, and humans.

Example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-web
  labels:
    app: nginx
    component: web
  annotations:
    description: "Serves the public nginx homepage"
    owner: "platform-learning"
    docs.example.com/runbook: "https://example.com/runbooks/nginx-web"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
      component: web
  template:
    metadata:
      labels:
        app: nginx
        component: web
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "80"
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
```

In this example:

- labels identify the Deployment and Pods as `app=nginx,component=web`
- annotations add descriptive and tool-specific metadata
- Prometheus-style annotations tell a monitoring tool that the Pods can be
  scraped on port `80`

## Why use annotations?

Use annotations when metadata is useful but should not define object identity.

Annotations can store:

- descriptions
- links to documentation or runbooks
- contact or ownership information
- build information
- Git commit SHAs
- config checksums
- monitoring hints
- ingress controller settings
- service mesh settings
- deployment automation metadata

Example:

```yaml
metadata:
  annotations:
    kubernetes.io/change-cause: "Update nginx image to nginx:1.27-alpine"
    app.example.com/git-sha: "abc1234"
    app.example.com/runbook-url: "https://example.com/runbooks/nginx"
```

This information is valuable, but it should not be used by a Service or
Deployment selector.

## What can annotations do that labels cannot?

### 1. Store larger, more descriptive values

Labels are designed for short identifying values. Annotations can hold longer
strings such as descriptions, URLs, JSON snippets, or generated metadata.

Good annotation:

```yaml
metadata:
  annotations:
    docs.example.com/summary: "Nginx frontend used for Kubernetes service demos"
```

Poor label:

```yaml
metadata:
  labels:
    summary: "Nginx frontend used for Kubernetes service demos"
```

Labels have stricter value rules and should stay short enough to be useful in
selectors.

### 2. Configure external controllers and tools

Many tools watch annotations to change behavior.

Example Ingress annotations:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-web
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  rules:
    - host: nginx.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-web
                port:
                  number: 80
```

Here, annotations are instructions to other controllers:

- the nginx Ingress controller reads `nginx.ingress.kubernetes.io/rewrite-target`
- cert-manager reads `cert-manager.io/cluster-issuer`

Labels cannot replace these because those tools specifically look for
annotations with known keys.

### 3. Track rollout triggers

A common pattern is to put a ConfigMap checksum in a Pod template annotation.
When the ConfigMap content changes, the checksum changes, which changes the Pod
template and triggers a Deployment rollout.

Example:

```yaml
spec:
  template:
    metadata:
      annotations:
        checksum/config: "d6f3b3f1"
```

This is metadata for rollout automation, not identity. A label would be the
wrong fit because Services and selectors should not care about config checksums.

### 4. Record history or change cause

Kubernetes supports the `kubernetes.io/change-cause` annotation:

```sh
kubectl annotate deployment/nginx-web \
  kubernetes.io/change-cause="Scale nginx-web to 3 replicas"
```

That type of historical note belongs in annotations, not labels.

## What labels can do that annotations cannot?

Labels can be selected.

This works:

```sh
kubectl get pods -l app=nginx
```

This does not work the same way for annotations:

```sh
# Kubernetes label selectors do not select by annotation.
kubectl get pods -l prometheus.io/scrape=true
```

That command looks for a label named `prometheus.io/scrape`, not an annotation.

Controllers such as Services, Deployments, Jobs, and NetworkPolicies use labels
and selectors to find objects. They do not use annotations for that built-in
selection behavior.

## Choosing between labels and annotations

Ask this question:

```text
Will Kubernetes or a person need to select a group of objects by this key?
```

If yes, use a label.

Examples:

```yaml
labels:
  app: nginx
  component: web
  environment: dev
```

If no, use an annotation.

Examples:

```yaml
annotations:
  description: "Demo nginx app"
  docs.example.com/runbook: "https://example.com/runbooks/nginx"
  prometheus.io/scrape: "true"
```

## Practical example using both

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-web
  labels:
    app: nginx
    component: web
    environment: dev
  annotations:
    description: "Nginx web Deployment for learning labels and annotations"
    app.example.com/owner: "platform-learning"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
      component: web
  template:
    metadata:
      labels:
        app: nginx
        component: web
        environment: dev
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "80"
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-web
  labels:
    app: nginx
    component: web
  annotations:
    description: "Stable network endpoint for the nginx web Pods"
spec:
  selector:
    app: nginx
    component: web
  ports:
    - name: http
      port: 80
      targetPort: http
```

In this example:

- the Deployment selector uses labels to manage matching Pods
- the Service selector uses labels to send traffic to matching Pods
- annotations describe ownership, monitoring behavior, and human context

## Common mistakes

### Mistake 1: putting selectable identity in annotations

Avoid:

```yaml
annotations:
  app: nginx
```

Use:

```yaml
labels:
  app: nginx
```

### Mistake 2: using too many labels for non-selectable data

Avoid:

```yaml
labels:
  git-sha: abc1234
  build-url: https://example.com/builds/1234
```

Prefer:

```yaml
annotations:
  app.example.com/git-sha: abc1234
  app.example.com/build-url: https://example.com/builds/1234
```

### Mistake 3: changing Deployment selectors casually

Deployment selectors are effectively part of the Deployment identity. Changing
them can orphan existing Pods or be rejected by Kubernetes.

Plan labels used by selectors carefully.

## Summary

- Labels identify and group objects.
- Selectors use labels to find objects.
- Services use selectors to route traffic to Pods.
- Deployments use selectors to manage Pods.
- Annotations store extra metadata for tools, automation, and humans.
- Use annotations for information that should not affect object selection.
