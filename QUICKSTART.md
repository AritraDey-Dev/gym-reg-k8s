# Quick Start Guide

Get the Gym Registration System running with Istio in minutes!

## Prerequisites

- Docker Desktop / Minikube / Kind (for local development)
- kubectl installed
- 8GB+ RAM available
- 20GB+ disk space

## Step 1: Create Local Kubernetes Cluster

### Using Kind (Recommended)

```bash
# Install Kind if not already installed
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create cluster with port mappings
kind create cluster --config=cluster/cluster.yaml
```

### Using Minikube

```bash
# Start Minikube with sufficient resources
minikube start --memory=8192 --cpus=4
```

### Using Docker Desktop

Enable Kubernetes in Docker Desktop settings.

## Step 2: Install Istio

```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -

# Add istioctl to PATH
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio with demo profile (includes all addons)
istioctl install --set profile=demo -y

# Verify installation
kubectl get pods -n istio-system
```

Wait until all Istio pods are running (may take 2-3 minutes).

## Step 3: Deploy the Application

```bash
# Clone the repository (if not already done)
git clone https://github.com/AritraDey-Dev/gym-reg-k8s.git
cd gym-reg-k8s

# Make the deploy script executable
chmod +x istio/deploy-all.sh

# Deploy everything
cd istio
./deploy-all.sh
```

This will:
- Create the namespace with Istio injection
- Deploy MySQL and Redis
- Deploy backend services
- Deploy frontend and admin panel
- Configure Istio gateway and routing
- Apply security policies
- Enable observability

## Step 4: Verify Deployment

```bash
# Check all pods are running (each should show 2/2 containers)
kubectl get pods -n gym-reg

# Expected output:
# NAME                              READY   STATUS    RESTARTS   AGE
# admin-panel-xxx                   2/2     Running   0          2m
# backend-main-xxx                  2/2     Running   0          2m
# backend-stream-xxx                2/2     Running   0          2m
# frontend-xxx                      2/2     Running   0          2m
# mysql-xxx                         2/2     Running   0          2m
# redis-xxx                         2/2     Running   0          2m
```

## Step 5: Access the Application

### Option A: Using Port Forward (Easiest for local testing)

```bash
# Forward port 8080 to Istio Gateway
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
```

Open in browser:
- Frontend: http://localhost:8080
- Admin Panel: http://localhost:8080/admin
- Backend Main: http://localhost:8080/api/main
- Backend Stream: http://localhost:8080/api/stream

### Option B: Using LoadBalancer IP (Cloud environments)

```bash
# Get the external IP
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Access the app at: http://$INGRESS_HOST"
```

## Step 6: Access Observability Tools

Open these in separate terminal windows:

### Kiali (Service Mesh Dashboard)
```bash
istioctl dashboard kiali
```
Browse to: http://localhost:20001

Features:
- Service topology graph
- Traffic flow visualization
- Configuration validation
- Health monitoring

### Grafana (Metrics Dashboard)
```bash
istioctl dashboard grafana
```
Browse to: http://localhost:3000

Pre-configured dashboards:
- Istio Service Dashboard
- Istio Workload Dashboard
- Istio Performance Dashboard

### Prometheus (Metrics)
```bash
istioctl dashboard prometheus
```
Browse to: http://localhost:9090

### Jaeger (Distributed Tracing)
```bash
istioctl dashboard jaeger
```
Browse to: http://localhost:16686

## Testing the Application

### 1. Test Frontend Access

```bash
curl http://localhost:8080/
```

### 2. Test Admin Panel

```bash
curl http://localhost:8080/admin
```

### 3. Test Backend API

```bash
# Health check
curl http://localhost:8080/api/main/health

# Example API call
curl http://localhost:8080/api/main/users
```

### 4. Generate Load for Testing

```bash
# Install hey (HTTP load generator)
go install github.com/rakyll/hey@latest

# Generate 1000 requests with 10 concurrent connections
hey -n 1000 -c 10 http://localhost:8080/
```

Watch the traffic in Kiali dashboard!

## Common Issues and Solutions

### Issue: Pods stuck in "Pending"

**Solution**: Check if cluster has enough resources

```bash
kubectl describe pod <pod-name> -n gym-reg
```

Increase cluster resources or reduce replica counts.

### Issue: Pods show 1/2 containers ready

**Cause**: Istio sidecar not injected

**Solution**: Verify namespace has istio-injection label

```bash
kubectl get namespace gym-reg --show-labels
```

If missing, apply:
```bash
kubectl label namespace gym-reg istio-injection=enabled
kubectl rollout restart deployment -n gym-reg
```

### Issue: Cannot access application

**Solution 1**: Check port-forward is running

```bash
# Re-run port-forward in a separate terminal
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
```

**Solution 2**: Check Istio gateway status

```bash
kubectl get gateway -n gym-reg
kubectl describe gateway gym-reg-gateway -n gym-reg
```

### Issue: Services cannot communicate

**Solution**: Check mTLS and authorization policies

```bash
# Analyze configuration
istioctl analyze -n gym-reg

# Check authorization policies
kubectl get authorizationpolicies -n gym-reg

# View sidecar logs
kubectl logs <pod-name> -n gym-reg -c istio-proxy
```

### Issue: High memory usage

**Solution**: Reduce replica counts for local development

```bash
kubectl scale deployment frontend --replicas=1 -n gym-reg
kubectl scale deployment backend-main --replicas=1 -n gym-reg
kubectl scale deployment backend-stream --replicas=1 -n gym-reg
```

## Development Workflow

### 1. Make Code Changes

Update your application code locally.

### 2. Build and Push Image

```bash
docker build -t yourusername/your-app:v2 .
docker push yourusername/your-app:v2
```

### 3. Update Deployment

```bash
# Edit deployment file
kubectl edit deployment <deployment-name> -n gym-reg

# Or use kubectl set image
kubectl set image deployment/frontend frontend=yourusername/your-app:v2 -n gym-reg
```

### 4. Watch Rollout

```bash
kubectl rollout status deployment/frontend -n gym-reg
```

### 5. Verify Changes

```bash
# Check new pods
kubectl get pods -n gym-reg

# Test application
curl http://localhost:8080/
```

## Monitoring Best Practices

### 1. Check Service Health

```bash
# In Kiali dashboard
# Navigate to: Graph → Namespace: gym-reg → Display: Traffic Animation
```

### 2. Monitor Request Rates

```bash
# In Grafana dashboard
# Open: Istio Service Dashboard
# Select service: frontend.gym-reg.svc.cluster.local
```

### 3. Trace Requests

```bash
# In Jaeger dashboard
# Select Service: frontend.gym-reg
# Click "Find Traces"
```

### 4. Query Metrics

```bash
# In Prometheus dashboard
# Query: istio_requests_total{destination_service="frontend.gym-reg.svc.cluster.local"}
```

## Cleanup

### Remove Application Only

```bash
cd istio
./cleanup.sh
```

### Remove Everything (Including Istio)

```bash
# Delete namespace
kubectl delete namespace gym-reg

# Uninstall Istio
istioctl uninstall --purge -y

# Delete Istio namespace
kubectl delete namespace istio-system

# Delete cluster (if using Kind)
kind delete cluster --name gym-reg
```

## Next Steps

1. **Explore the Architecture**: Read [ARCHITECTURE.md](ARCHITECTURE.md)
2. **Configure Security**: Update secrets and enable HTTPS
3. **Set Up CI/CD**: Integrate with GitHub Actions
4. **Add Monitoring Alerts**: Configure Prometheus AlertManager
5. **Implement Canary Deployments**: Use Istio traffic splitting
6. **Scale the Application**: Enable HPA and test load

## Useful Commands Cheat Sheet

```bash
# View all resources
kubectl get all -n gym-reg

# Describe a resource
kubectl describe <resource-type> <resource-name> -n gym-reg

# View logs
kubectl logs <pod-name> -n gym-reg
kubectl logs <pod-name> -n gym-reg -c istio-proxy

# Exec into pod
kubectl exec -it <pod-name> -n gym-reg -- /bin/bash

# Port forward to a service
kubectl port-forward svc/<service-name> 8080:80 -n gym-reg

# Check Istio configuration
istioctl analyze -n gym-reg
istioctl proxy-status

# View virtual services
kubectl get virtualservices -n gym-reg
kubectl describe virtualservice <name> -n gym-reg

# View destination rules
kubectl get destinationrules -n gym-reg

# View authorization policies
kubectl get authorizationpolicies -n gym-reg

# Restart a deployment
kubectl rollout restart deployment/<name> -n gym-reg

# Scale a deployment
kubectl scale deployment/<name> --replicas=3 -n gym-reg

# View resource usage
kubectl top pods -n gym-reg
kubectl top nodes
```

## Getting Help

- **Documentation**: Check [README.md](README.md) for detailed information
- **Istio Docs**: https://istio.io/latest/docs/
- **Kubernetes Docs**: https://kubernetes.io/docs/
- **Issues**: Create an issue in the GitHub repository

## Tips for Success

1. **Start Small**: Begin with 1 replica per service for development
2. **Use Observability**: Always check Kiali and logs when debugging
3. **Incremental Changes**: Test each change before moving to the next
4. **Resource Monitoring**: Keep an eye on CPU/memory usage
5. **Save Your Work**: Commit configuration changes to version control

Happy Deploying! 🚀
