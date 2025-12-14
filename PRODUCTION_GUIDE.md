# Production Deployment Guide

This guide outlines the steps to transition your Gym Registration application from a local development setup to a robust, scalable production environment.

## 1. Ingress & Networking (Domains & SSL)
To serve your application on a real domain (e.g., `gym.example.com`) with HTTPS, you need an **Ingress Controller** and **Cert-Manager**.

### A. Install NGINX Ingress Controller
The Ingress Controller sits at the edge of your cluster and routes traffic to your services.
**Important:** Keep your backend/frontend services as `ClusterIP`. The Ingress Controller itself will be of type `LoadBalancer` and will handle external traffic, routing it internally to your ClusterIP services. This saves costs (one LoadBalancer vs many).

```bash
# For most cloud providers (AWS, GKE, Azure)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
```
*This will create a LoadBalancer service with a public IP.*

### B. Configure DNS
Point your domain's DNS records to the External IP of the Ingress Controller.
- `api.example.com` -> Ingress LoadBalancer IP
- `admin.example.com` -> Ingress LoadBalancer IP
- `app.example.com` -> Ingress LoadBalancer IP

### C. Install Cert-Manager (For SSL)
Cert-Manager automates the issuance of Let's Encrypt certificates.
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
```

### D. Create an Ingress Resource
Create a file `production/ingress.yaml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gym-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.example.com
    - api.example.com
    - admin.example.com
    secretName: gym-tls-secret
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 3000
  - host: admin.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-panel
            port:
              number: 3001
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backend-main
            port:
              number: 9084

### E. FAQ: Why Ingress instead of LoadBalancer?
**Q: Can I just set `type: LoadBalancer` for my services?**
A: Yes, but it is **not recommended** for this setup.
*   **LoadBalancer:** Creates a separate Cloud Load Balancer (and bill) for *each* service. You would have 3 LBs, 3 IPs, and have to manage SSL for each.
*   **Ingress:** Creates **one** Cloud Load Balancer that routes to all your services. Cheaper, easier SSL management, and cleaner DNS.

### F. Accessing the App (Production vs Local)
**Q: Do I need `kubectl port-forward` in production?**
A: **NO.**
*   **Local (Kind/Minikube):** Yes, you use `port-forward` because your local cluster doesn't have a real public IP.
*   **Production (Cloud):** No. The Ingress Controller provides a **Public IP**. You map your domain (e.g., `gym.com`) to this IP. Users access the website directly via the domain. `port-forward` is only used for debugging.

### G. Do Services need Port-Forward to talk to each other?
**Q: Does Frontend need port-forward to talk to Backend?**
A: **NO.**
*   **Inside the Cluster:** Services talk to each other using their Service Names (DNS).
    *   Frontend calls `http://backend-main:9084` (Internal DNS).
    *   **No port-forward needed.**
*   **Outside the Cluster (You):** Only **YOU** need port-forward (or Ingress) to see the app from your browser.
```

## 2. Storage & Databases
**CRITICAL:** Do NOT use `hostPath` (local storage) in production. If the node dies, your data is lost.

### A. Managed Database (Recommended)
Use a managed service like **AWS RDS**, **Google Cloud SQL**, or **Azure SQL**.
- **Why?** Automated backups, high availability, patching.
- **How?** Update `backend/config.yaml` with the managed DB host/credentials.

### B. Persistent Volumes (If self-hosting)
If you must run MySQL/Redis in the cluster, use a **StorageClass** provided by your cloud provider (e.g., `gp2` on AWS, `standard` on GKE).
Update your PVCs (`mysql-pvc.yaml`):
```yaml
spec:
  storageClassName: gp2 # or standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

## 3. Scaling & Reliability

### A. Horizontal Pod Autoscaler (HPA)
Automatically adds more pods when CPU/Memory usage is high.
1. **Install Metrics Server:** (Required for HPA to work)
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```
2. **Define HPA:**
   ```yaml
   apiVersion: autoscaling/v2
   kind: HorizontalPodAutoscaler
   metadata:
     name: backend-main-hpa
   spec:
     scaleTargetRef:
       apiVersion: apps/v1
       kind: Deployment
       name: backend-main
     minReplicas: 2
     maxReplicas: 10
     metrics:
     - type: Resource
       resource:
         name: cpu
         target:
           type: Utilization
           averageUtilization: 70
   ```

### B. Resource Requests & Limits
Ensure EVERY container has requests and limits set. This allows the Kubernetes scheduler to make intelligent decisions.
- **Requests:** Guaranteed resources.
- **Limits:** Maximum burst allowed.

## 4. Security

### A. Secrets Management
Don't commit `secret.yaml` to Git!
- **Option 1:** Use **Sealed Secrets** to encrypt secrets in Git.
- **Option 2:** Use **External Secrets Operator** to fetch secrets from AWS Secrets Manager / HashiCorp Vault.

### B. Network Policies
Restrict traffic so only the frontend can talk to the backend, and only the backend can talk to the DB.

## 5. CI/CD Pipeline
Automate your deployment using GitHub Actions or GitLab CI.
1. **Build** Docker images on push.
2. **Push** to a container registry (ECR, GCR, Docker Hub).
3. **Update** the Kubernetes deployment image tag.
   ```bash
   kubectl set image deployment/backend-main backend-main=myrepo/backend:sha-12345
   ```
