# Cloud Production Deployment

This directory contains the configurations needed to expose your application to the internet with SSL and autoscaling.

## 🚀 Deployment Order

After you have deployed the base application (Frontend, Backend, Admin, DBs), follow these steps:

### 1. Install Prerequisites (One-time setup)

**A. Ingress Controller (NGINX)**
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
```

**B. Cert-Manager (For SSL)**
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
```

### 2. Configure SSL Issuer
Update `cluster-issuer.yaml` with your real email address, then apply it:
```bash
kubectl apply -f cloud-production/cluster-issuer.yaml
```

### 3. Deploy Ingress (Domain Routing)
Update `ingress.yaml` with your **real domains** (replace `example.com`), then apply it:
```bash
kubectl apply -f cloud-production/ingress.yaml
```

### 4. Enable Autoscaling (HPA)
Install the Metrics Server first:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Then apply the HPA configurations from the `autoscaler` directory:
```bash
kubectl apply -f autoscaler/backend-main-hpa.yaml
kubectl apply -f autoscaler/backend-stream-hpa.yaml
kubectl apply -f autoscaler/frontend-hpa.yaml
kubectl apply -f autoscaler/admin-panel-hpa.yaml
```

## 📝 Checklist
- [ ] Base App Deployed (Frontend, Backend, Admin, DBs)
- [ ] Ingress Controller Installed
- [ ] Cert-Manager Installed
- [ ] ClusterIssuer Applied (with correct email)
- [ ] Ingress Applied (with correct domains)
- [ ] DNS Records Pointed to Ingress IP
- [ ] Metrics Server Installed
- [ ] HPA Applied
