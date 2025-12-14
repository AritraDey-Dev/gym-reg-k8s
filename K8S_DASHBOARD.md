# Kubernetes Dashboard Guide

This guide explains how to install and access the Kubernetes Dashboard securely in both **Local (Kind)** and **Production** environments.

## 1. Installation
Run this command to install the official Kubernetes Dashboard:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

## 2. Create Admin User
To log in, you need a Service Account with admin privileges. We have provided a file `dashboard-admin.yaml` for this.

```bash
kubectl apply -f dashboard-admin.yaml
```

## 3. Accessing the Dashboard (Local & Production)
The safest way to access the dashboard is using `kubectl proxy`. This works for **both** local and production clusters without exposing the dashboard to the public internet.

### Step A: Start Proxy
Run this command in a separate terminal:
```bash
kubectl proxy
```

### Step B: Open in Browser
Click this link:
[http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/)

### Step C: Get Login Token
Run this command to generate a token for the `admin-user` we created:

```bash
kubectl -n kubernetes-dashboard create token admin-user
```

Copy the long token string and paste it into the Dashboard login screen.

## ⚠️ Security Warning for Production
**Do NOT** expose the Kubernetes Dashboard via Ingress (public domain) unless you really know what you are doing. It gives full administrative control over your cluster. Using `kubectl proxy` creates a secure, encrypted tunnel from your machine to the cluster, which is much safer.
