# K8s Infra

![Kubernetes CI](https://github.com/AritraDey-Dev/gym-reg-k8s/actions/workflows/k8s-ci.yaml/badge.svg)
![Cilium Connectivity](https://github.com/AritraDey-Dev/gym-reg-k8s/actions/workflows/cilium-connectivity.yaml/badge.svg)

A complete Kubernetes deployment configuration for a gym registration system with backend services, frontend, admin panel, MySQL database, and Redis cache.

## 📋 Overview

This repository contains Kubernetes manifests for deploying a gym registration application stack that includes:

- **Backend Services**: Main API server and streaming server (Go-based)
- **Frontend**: Next.js web application
- **Admin Panel**: Administrative interface
- **MySQL**: Persistent database for user and registration data
- **Redis**: Caching layer for improved performance
- **Autoscaling**: HPA and VPA configurations for backend services

## 🏗️ Architecture

```
┌─────────────┐     ┌──────────────┐     ┌────────────┐
│  Frontend   │────▶│   Backend    │────▶│   MySQL    │
│  (Next.js)  │     │   (Main)     │     │ (Database) │
└─────────────┘     └──────────────┘     └────────────┘
                            │
                            ▼
                    ┌──────────────┐     ┌────────────┐
                    │   Backend    │────▶│   Redis    │
                    │  (Stream)    │     │  (Cache)   │
                    └──────────────┘     └────────────┘
                            │
                    ┌──────────────┐
                    │ Admin Panel  │
                    └──────────────┘
```

## 🚀 Prerequisites

Before setting up the project locally, ensure you have the following installed:

- [Docker](https://docs.docker.com/get-docker/) (v20.10 or later)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (v1.25 or later)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) (Kubernetes in Docker) (v0.20 or later)
- [Git](https://git-scm.com/downloads)

## 📦 Local Setup

### 1. Clone the Repository

```bash
git clone https://github.com/AritraDey-Dev/k8s-infra.git
cd gym-reg-k8s
```

### 2. Create a Kind Cluster

Create a local Kubernetes cluster using the provided configuration:

```bash
kind create cluster --config cluster/cluster.yaml
```

This creates a cluster named `gym-reg` with:
- Port 8080 mapped to container port 80
- Port 8443 mapped to container port 443

Verify the cluster is running:

```bash
kubectl cluster-info --context kind-gym-reg
kubectl get nodes
```

### 3. Deploy MySQL Database

Apply MySQL configurations in the following order:

```bash
# Create persistent volume and volume claim
kubectl apply -f mysql/mysql-pv.yaml
kubectl apply -f mysql/mysql-pvc.yaml

# Create configuration and secrets
kubectl apply -f mysql/config.yaml
kubectl apply -f mysql/secret.yaml

# Deploy MySQL
kubectl apply -f mysql/deployment.yaml
kubectl apply -f mysql/service.yaml
```

Wait for MySQL to be ready:

```bash
kubectl wait --for=condition=ready pod -l app=mysql --timeout=300s
```

### 4. Deploy Redis Cache

Apply Redis configurations:

```bash
# Create persistent volume and volume claim
kubectl apply -f redis/redis-pv.yaml
kubectl apply -f redis/redis-pvc.yaml

# Create configuration and secrets
kubectl apply -f redis/config.yaml
kubectl apply -f redis/secret.yaml

# Deploy Redis
kubectl apply -f redis/deployment.yaml
kubectl apply -f redis/service.yaml
```

Wait for Redis to be ready:

```bash
kubectl wait --for=condition=ready pod -l app=redis --timeout=300s
```

### 5. Deploy Backend Services

Apply backend configurations and deployments:

```bash
# Create shared configuration and secrets
kubectl apply -f backend/config.yaml
kubectl apply -f backend/secret.yaml

# Deploy main backend service
kubectl apply -f backend/backend-main-deployment.yaml
kubectl apply -f backend/backend-main-service.yaml

# Deploy streaming backend service
kubectl apply -f backend/backend-stream-deployment.yaml
kubectl apply -f backend/backend-stream-service.yaml
```

Wait for backend services to be ready:

```bash
kubectl wait --for=condition=ready pod -l app=backend-main --timeout=300s
kubectl wait --for=condition=ready pod -l app=backend-stream --timeout=300s
```

### 6. Deploy Frontend

Apply frontend configurations:

```bash
kubectl apply -f frontend/configmap.yaml
kubectl apply -f frontend/deployment.yaml
kubectl apply -f frontend/service.yaml
```

Wait for frontend to be ready:

```bash
kubectl wait --for=condition=ready pod -l app=frontend --timeout=300s
```

### 7. Deploy Admin Panel

Apply admin panel configurations:

```bash
kubectl apply -f admin-panel/configmap.yaml
kubectl apply -f admin-panel/next-config-map.yaml
kubectl apply -f admin-panel/deployment.yaml
kubectl apply -f admin-panel/service.yaml
```

Wait for admin panel to be ready:

```bash
kubectl wait --for=condition=ready pod -l app=admin-panel --timeout=300s
```

### 8. (Optional) Enable Autoscaling

To enable Horizontal Pod Autoscaler (HPA) and Vertical Pod Autoscaler (VPA):

```bash
# Apply HPA configurations
kubectl apply -f autoscaler/backend-main-hpa.yaml
kubectl apply -f autoscaler/backend-stream-hpa.yaml

# Apply VPA configurations (requires VPA to be installed in cluster)
kubectl apply -f autoscaler/backend-main-vpa.yaml
kubectl apply -f autoscaler/backend-stream-vpa.yaml
```

**Note**: VPA requires the Vertical Pod Autoscaler to be installed in your cluster. See [VPA Installation Guide](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler#installation).

## 🔍 Verify Deployment

Check that all pods are running:

```bash
kubectl get pods
```

Check all services:

```bash
kubectl get services
```

View logs for any service (example for backend-main):

```bash
kubectl logs -l app=backend-main -f
```

## 🌐 Accessing the Application

Once deployed, you can access the services:

- **Frontend**: Port-forward to access the frontend
  ```bash
  kubectl port-forward service/frontend 3000:3000
  ```
  Then visit: http://localhost:3000

- **Admin Panel**: Port-forward to access the admin panel
  ```bash
  kubectl port-forward service/admin-panel 3001:3000
  ```
  Then visit: http://localhost:3001

- **Backend Main API**: Port-forward to access the API
  ```bash
  kubectl port-forward service/backend-main 9084:9084
  ```
  Then visit: http://localhost:9084

- **Backend Stream API**: Port-forward to access the streaming API
  ```bash
  kubectl port-forward service/backend-stream 9085:9085
  ```
  Then visit: http://localhost:9085

## 🔧 Configuration

### Environment Variables

Key configurations can be modified in:

- **Backend**: `backend/config.yaml` and `backend/secret.yaml`
- **Frontend**: `frontend/configmap.yaml`
- **Admin Panel**: `admin-panel/configmap.yaml`
- **MySQL**: `mysql/config.yaml` and `mysql/secret.yaml`
- **Redis**: `redis/config.yaml` and `redis/secret.yaml`

### Database Connection

The backend services connect to MySQL using:
- **Host**: `mysql` (Kubernetes service name)
- **Port**: `3306`
- **Database**: `gym_reg`

Default credentials are in `backend/secret.yaml` (change for production).

### Redis Connection

The backend services connect to Redis using:
- **Host**: `redis` (Kubernetes service name)
- **Port**: `6379`

Default password is in `backend/secret.yaml` (change for production).

## 🛠️ Development

### Updating Docker Images

To use different Docker images, update the `image` field in deployment files:

- Backend Main: `backend/backend-main-deployment.yaml`
- Backend Stream: `backend/backend-stream-deployment.yaml`
- Frontend: `frontend/deployment.yaml`
- Admin Panel: `admin-panel/deployment.yaml`

### Resource Limits

Resource requests and limits can be adjusted in deployment files:

```yaml
resources:
  requests:
    cpu: 200m
    memory: 100Mi
  limits:
    cpu: 500m
    memory: 200Mi
```

### Scaling

Manually scale deployments:

```bash
kubectl scale deployment backend-main --replicas=3
kubectl scale deployment frontend --replicas=2
```

## 📊 Monitoring

View resource usage:

```bash
kubectl top pods
kubectl top nodes
```

Describe a specific resource:

```bash
kubectl describe pod <pod-name>
kubectl describe service <service-name>
```

## 🧹 Cleanup

To delete all resources:

```bash
# Delete all resources
kubectl delete -f autoscaler/
kubectl delete -f admin-panel/
kubectl delete -f frontend/
kubectl delete -f backend/
kubectl delete -f redis/
kubectl delete -f mysql/
```

To delete the entire Kind cluster:

```bash
kind delete cluster --name gym-reg
```

## 🐛 Troubleshooting

### Pods Not Starting

Check pod status and events:
```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Service Connection Issues

Verify services are running:
```bash
kubectl get services
kubectl get endpoints
```

### Persistent Volume Issues

Check PV and PVC status:
```bash
kubectl get pv
kubectl get pvc
```

### Database Connection Errors

Verify MySQL is running and accessible:
```bash
kubectl exec -it <mysql-pod-name> -- mysql -u user -p
```

## 📝 Notes

- This setup uses Kind for local development. For production, consider using a managed Kubernetes service (GKE, EKS, AKS).
- Default credentials in `secret.yaml` files should be changed for production use.
- The CA certificate in configurations is for the LCA service integration.
- Persistent volumes use `hostPath` which is suitable for single-node clusters. For multi-node clusters, use appropriate storage solutions.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

See [LICENSE](LICENSE) file for details.

## 🔗 Related Repositories

- Backend Application: [coderaritra/techno-gym-stream](https://hub.docker.com/r/coderaritra/techno-gym-stream)
- Frontend Application: [coderaritra/gym-reg-frontend](https://hub.docker.com/r/coderaritra/gym-reg-frontend)
