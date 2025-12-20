# Monitoring Setup & Troubleshooting Guide

## Quick Setup Guide

Run these commands from the root of the repository to deploy the entire monitoring stack.

### 1. Prerequisites
```bash
kubectl create namespace monitoring
```

### 2. Deploy Prometheus & Node Exporter
```bash
kubectl apply -f gym-reg-k8s/monitoring/node-exporter.yaml
kubectl apply -f gym-reg-k8s/monitoring/prometheus.yaml
```

### 3. Deploy Grafana (with Dashboards & Datasources)
```bash
# Apply Provisioning Configs
kubectl apply -f gym-reg-k8s/monitoring/grafana-datasources.yaml
kubectl apply -f gym-reg-k8s/monitoring/grafana-provisioning.yaml

# Apply Dashboards (Use replace --force to handle large file size)
kubectl create configmap grafana-dashboards --from-file=gym-reg-k8s/monitoring/grafana-dashboards.yaml -n monitoring --dry-run=client -o yaml | kubectl replace --force -f -

# Deploy Grafana
kubectl apply -f gym-reg-k8s/monitoring/grafana.yaml
```

### 4. Deploy Ingress Rules
```bash
kubectl apply -f gym-reg-k8s/monitoring/grafana-ingress.yaml
kubectl apply -f gym-reg-k8s/monitoring/hubble-ingress.yaml
kubectl apply -f gym-reg-k8s/monitoring/dashboard-ingress.yaml
```

### 5. Setup Hubble UI
```bash
# Enable Hubble UI
cilium hubble enable --ui

# Patch Nginx for subpath support
kubectl patch configmap hubble-ui-nginx -n kube-system --patch-file gym-reg-k8s/monitoring/hubble-nginx-patch.yaml

# Restart to apply patch
kubectl rollout restart deployment hubble-ui -n kube-system
```

### 6. Setup Kubernetes Dashboard
```bash
# Install Dashboard (if not installed)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create Admin User
kubectl apply -f gym-reg-k8s/monitoring/dashboard-admin.yaml

# Get Login Token
kubectl -n kubernetes-dashboard create token admin-user
```

---

This directory contains the configuration for the monitoring stack: **Prometheus**, **Grafana**, **Hubble UI**, and **Kubernetes Dashboard**.

## 1. Grafana & Prometheus

### Deployment
-   **Files**: `grafana.yaml`, `prometheus.yaml`, `node-exporter.yaml`
-   **Namespace**: `monitoring`
-   **Access**: `http://<LOADBALANCER_IP>/grafana`

### Key Configurations & Fixes

#### 1. Subpath Routing (`/grafana`)
**Issue**: Accessing Grafana at `/grafana` resulted in 404s or broken assets because it expected to be at the root `/`.
**Fix**: Added environment variables to `grafana.yaml`:
```yaml
env:
  - name: GF_SERVER_ROOT_URL
    value: "%(protocol)s://%(domain)s/grafana/"
  - name: GF_SERVER_SERVE_FROM_SUB_PATH
    value: "true"
```

#### 2. Missing Metrics (Empty Charts)
**Issue**: Dashboards showed "No Data".
**Cause**:
1.  **Node Exporter** was missing (it collects hardware metrics).
2.  **Prometheus** wasn't configured to scrape it.
**Fix**:
1.  Deployed `node-exporter.yaml` (DaemonSet).
2.  Updated `prometheus.yaml` scrape config:
    ```yaml
    - job_name: 'node-exporter'
      static_configs:
        - targets: ['node-exporter:9100']
    ```

#### 3. Automated Dashboards & Datasources
**Issue**: Dashboards and Prometheus datasource had to be added manually after every restart.
**Fix**: Used **Grafana Provisioning**.
1.  **Datasource**: Created `grafana-datasources.yaml` ConfigMap to auto-add Prometheus.
2.  **Dashboards**: Created `grafana-dashboards.yaml` ConfigMap containing the JSON model.
3.  **Provisioning Config**: Created `grafana-provisioning.yaml` to tell Grafana where to look.
4.  **Mounts**: Updated `grafana.yaml` to mount these ConfigMaps into `/etc/grafana/provisioning/...` and `/var/lib/grafana/dashboards`.

**Debugging**:
-   If dashboards are missing, check volume mounts:
    ```bash
    kubectl get pod -n monitoring -l app=grafana -o yaml | grep volumeMounts -A 20
    ```
-   If "Datasource not found" error appears, check `grafana-datasources.yaml`.

---

## 2. Hubble UI (Cilium)

### Deployment
-   **Enabled via CLI**: `cilium hubble enable --ui`
-   **Ingress**: `hubble-ingress.yaml`
-   **Access**: `http://<LOADBALANCER_IP>/hubble`

### Key Configurations & Fixes

#### 1. Subpath Routing (`/hubble`)
**Issue**: Hubble UI is a static React app. When accessed at `/hubble`, it tried to load assets from `/` (e.g., `/index.js`), causing 404s.
**Fix**: Patched the Nginx configuration inside the Hubble UI pod using `hubble-nginx-patch.yaml`.
-   We used `sub_filter` to rewrite HTML content on the fly:
    ```nginx
    sub_filter 'href="/' 'href="/hubble/';
    sub_filter 'src="/' 'src="/hubble/';
    ```
-   **To Apply**: `kubectl patch configmap hubble-ui-nginx -n kube-system --patch-file hubble-nginx-patch.yaml` then restart the pod.

---

## 3. Kubernetes Dashboard

### Deployment
-   **Manifest**: Standard upstream deployment.
-   **Ingress**: `dashboard-ingress.yaml`
-   **Access**: **Use `kubectl proxy`** (Subpath access via Ingress is unstable).

### Known Issues

#### 1. Subpath Crash (`/dashboard`)
**Issue**: We attempted to serve it at `/dashboard` by adding the `--base-path=/dashboard` argument.
**Result**: The pod **crashed**. The current version of Kubernetes Dashboard has issues with subpath configuration.
**Resolution**: Reverted the change.

#### 2. Recommended Access Method
Do not use the Ingress path. Instead:
1.  Create an admin token:
    ```bash
    kubectl apply -f dashboard-admin.yaml
    kubectl -n kubernetes-dashboard create token admin-user
    ```
2.  Start proxy:
    ```bash
    kubectl proxy
    ```
3.  Open in browser:
    `http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/`

---

## General Debugging Commands

**Check Logs**:
```bash
kubectl logs -n monitoring -l app=grafana
kubectl logs -n monitoring -l app=prometheus
kubectl logs -n kube-system -l k8s-app=hubble-ui
```

**Restart Pods (to pick up config changes)**:
```bash
kubectl rollout restart deployment grafana -n monitoring
kubectl rollout restart deployment prometheus -n monitoring
```
