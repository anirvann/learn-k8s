# ConfigMaps and manifest structure

This document explains the purpose of the `ConfigMap` in the nginx application
example and why the repo includes both a standalone Deployment manifest and an
application manifest that also contains a Deployment.

## What is a ConfigMap?

A Kubernetes `ConfigMap` stores non-secret configuration data as key-value
pairs. The data can be consumed by Pods without baking it into a container
image.

In `examples/nginx/03-application.yaml`, the ConfigMap is:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-homepage
  namespace: learn-nginx
data:
  index.html: |
    <!doctype html>
    ...
```

The key is `index.html`, and the value is the HTML content that nginx serves.

## Why use a ConfigMap here?

The nginx container image already contains nginx, but we want to customize what
nginx serves without building a custom Docker image. The ConfigMap lets us keep
the application content in Kubernetes configuration.

That creates a useful separation:

```text
Container image: nginx runtime
ConfigMap: homepage content/configuration
Deployment: how to run nginx Pods
Service: how to reach nginx Pods
```

This is useful because configuration and application content often change more
frequently than the base runtime image.

## How the Deployment uses the ConfigMap

The application Deployment mounts the ConfigMap into each nginx Pod:

```yaml
volumeMounts:
  - name: homepage
    mountPath: /usr/share/nginx/html/index.html
    subPath: index.html
volumes:
  - name: homepage
    configMap:
      name: nginx-homepage
```

This means:

1. Kubernetes reads the `nginx-homepage` ConfigMap.
2. It exposes the `index.html` key as a file.
3. That file is mounted into the nginx container at
   `/usr/share/nginx/html/index.html`.
4. nginx serves that file when you visit the site.

In this example, the ConfigMap is mounted with `subPath` so only the single
`index.html` file is placed at the exact nginx homepage path.

Important detail: ConfigMap volume updates are usually projected into running
Pods eventually, but `subPath` mounts do not receive live ConfigMap updates. If
you change this ConfigMap, restart the Deployment to make nginx Pods pick up the
new homepage:

```sh
kubectl -n learn-nginx rollout restart deployment/nginx-app
```

## Other ways Pods can use ConfigMaps

ConfigMaps can be consumed in several common ways:

### 1. Mounted as files

This example uses the file-mount approach. It is a good fit for config files,
HTML files, nginx config snippets, and similar data.

### 2. Environment variables

Pods can read ConfigMap keys as environment variables:

```yaml
env:
  - name: APP_MODE
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: mode
```

### 3. Command-line arguments

A container command can reference environment variables that came from a
ConfigMap.

## What ConfigMaps should not store

ConfigMaps are not encrypted secrets. Do not put passwords, API tokens, private
keys, or credentials in a ConfigMap.

Use a Kubernetes `Secret` for sensitive data.

Also keep ConfigMaps reasonably small. They are intended for configuration, not
large application assets or databases.

## Did we need `02-deployment.yaml` if `03-application.yaml` has a Deployment?

For the final runnable nginx application, no. If your only goal is to run the
complete application, `03-application.yaml` is enough because it already defines
its own Deployment named `nginx-app`.

The separate `02-deployment.yaml` exists for learning. It isolates one concept:
how a Deployment manages Pods.

The three files have different teaching purposes:

| File | Purpose |
| --- | --- |
| `01-pod.yaml` | Shows the smallest runnable Kubernetes workload. |
| `02-deployment.yaml` | Shows how Kubernetes manages replicated Pods with a controller. |
| `03-application.yaml` | Shows how multiple resources combine into an application. |

When applied sequentially, `02-deployment.yaml` and `03-application.yaml` create
different Deployments:

```text
default namespace
+-- Deployment nginx-deployment

learn-nginx namespace
+-- Deployment nginx-app
```

They do not conflict because they have different names and live in different
resource scopes.

## When would you keep separate files?

Separate files are helpful when you want to teach, test, or apply pieces
individually:

```text
01-pod.yaml
02-deployment.yaml
03-application.yaml
```

They make the progression clear.

## When would you combine files?

Combining related resources into one manifest is convenient when the resources
are usually applied together:

```text
Namespace + ConfigMap + Deployment + Service
```

That is what `03-application.yaml` does.

In real projects, teams often choose one of these layouts:

```text
manifests/
+-- namespace.yaml
+-- configmap.yaml
+-- deployment.yaml
+-- service.yaml
```

or:

```text
manifests/
+-- application.yaml
```

Both are valid. The best choice depends on whether you want independent files
for clarity and reuse, or one file for a small application that is applied as a
unit.
