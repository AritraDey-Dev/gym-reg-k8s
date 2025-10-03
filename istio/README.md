# Istio Configuration for Gym Registration System

This directory contains Istio service mesh configurations for the entire Kubernetes architecture.

## Architecture Overview

The Gym Registration System consists of:
- **Frontend** - User-facing web application (port 3000)
- **Admin Panel** - Administrative interface (port 3001)
- **Backend Main** - Main API service (HTTP: 9084, gRPC: 9083)
- **Backend Stream** - Streaming API service (HTTP: 9085, gRPC: 9086)
- **MySQL** - Database (port 3306)
- **Redis** - Cache (port 6379)

## Prerequisites

1. Install Istio on your Kubernetes cluster:
```bash
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH
istioctl install --set profile=default -y
```

2. Verify Istio installation:
```bash
kubectl get pods -n istio-system
```

## Deployment Order

Apply the Istio configurations in the following order:

### 1. Create Namespace with Istio Injection
```bash
kubectl apply -f istio/namespace.yaml
```

### 2. Deploy Application Resources
Deploy all application resources (deployments, services, configmaps, secrets) to the `gym-reg` namespace:
```bash
# MySQL
kubectl apply -f mysql/ -n gym-reg

# Redis
kubectl apply -f redis/ -n gym-reg

# Backend
kubectl apply -f backend/ -n gym-reg

# Frontend
kubectl apply -f frontend/ -n gym-reg

# Admin Panel
kubectl apply -f admin-panel/ -n gym-reg

# Autoscaler (if applicable)
kubectl apply -f autoscaler/ -n gym-reg
```

### 3. Apply Istio Gateway
```bash
kubectl apply -f istio/gateway.yaml
```

### 4. Apply Virtual Services
```bash
kubectl apply -f istio/virtualservice-frontend.yaml
kubectl apply -f istio/virtualservice-admin.yaml
kubectl apply -f istio/virtualservice-backend.yaml
```

### 5. Apply Destination Rules
```bash
kubectl apply -f istio/destinationrule-frontend.yaml
kubectl apply -f istio/destinationrule-admin.yaml
kubectl apply -f istio/destinationrule-backend.yaml
kubectl apply -f istio/destinationrule-databases.yaml
```

### 6. Apply Security Policies
```bash
kubectl apply -f istio/peer-authentication.yaml
kubectl apply -f istio/authorization-policy.yaml
```

### 7. Apply Additional Configurations
```bash
kubectl apply -f istio/sidecar.yaml
kubectl apply -f istio/service-entry.yaml
kubectl apply -f istio/telemetry.yaml
```

## Quick Deploy All

To deploy everything at once:
```bash
# Create namespace
kubectl apply -f istio/namespace.yaml

# Deploy applications
kubectl apply -f mysql/ -n gym-reg
kubectl apply -f redis/ -n gym-reg
kubectl apply -f backend/ -n gym-reg
kubectl apply -f frontend/ -n gym-reg
kubectl apply -f admin-panel/ -n gym-reg

# Deploy Istio configurations
kubectl apply -f istio/
```

## Features

### 1. Traffic Management
- **Gateway**: Exposes services through Istio ingress gateway on ports 80 (HTTP) and 443 (HTTPS)
- **Virtual Services**: Routes traffic based on URI patterns:
  - `/` → Frontend
  - `/admin` → Admin Panel
  - `/api/main/*` → Backend Main
  - `/api/stream/*` → Backend Stream
- **Destination Rules**: Configure load balancing, connection pooling, and circuit breaking

### 2. Security
- **mTLS**: Strict mutual TLS for service-to-service communication
- **Authorization Policies**: Fine-grained access control for each service
- **Peer Authentication**: PERMISSIVE mode for databases to allow gradual migration

### 3. Observability
- **Metrics**: Prometheus integration for metrics collection
- **Tracing**: Distributed tracing with Zipkin (100% sampling)
- **Access Logging**: Envoy access logs enabled

### 4. Resilience
- **Circuit Breaking**: Automatic failover when services are unhealthy
- **Connection Pooling**: Limits concurrent connections
- **Outlier Detection**: Removes unhealthy instances from load balancing

## Access the Application

### Get Ingress Gateway External IP
```bash
kubectl get svc istio-ingressgateway -n istio-system
```

### Access Services
- Frontend: `http://<EXTERNAL-IP>/`
- Admin Panel: `http://<EXTERNAL-IP>/admin`
- Backend Main API: `http://<EXTERNAL-IP>/api/main`
- Backend Stream API: `http://<EXTERNAL-IP>/api/stream`

## Monitoring and Observability

### Kiali Dashboard
```bash
istioctl dashboard kiali
```

### Prometheus Metrics
```bash
istioctl dashboard prometheus
```

### Grafana Dashboards
```bash
istioctl dashboard grafana
```

### Jaeger Tracing
```bash
istioctl dashboard jaeger
```

## Verify Istio Injection

Check if sidecars are injected:
```bash
kubectl get pods -n gym-reg
```

Each pod should show 2/2 containers (application + Envoy sidecar).

## Troubleshooting

### Check Istio Configuration
```bash
istioctl analyze -n gym-reg
```

### View Sidecar Logs
```bash
kubectl logs <pod-name> -n gym-reg -c istio-proxy
```

### Check Virtual Service Status
```bash
kubectl get virtualservices -n gym-reg
kubectl describe virtualservice <name> -n gym-reg
```

### Check Gateway Status
```bash
kubectl get gateway -n gym-reg
kubectl describe gateway gym-reg-gateway -n gym-reg
```

## TLS/HTTPS Configuration

To enable HTTPS, create a TLS secret:
```bash
kubectl create secret tls gym-reg-tls-cert \
  --key=path/to/key.pem \
  --cert=path/to/cert.pem \
  -n istio-system
```

## Customization

### Adjusting Traffic Policies
Edit the DestinationRule files to modify:
- Connection pool sizes
- Load balancing algorithms
- Circuit breaker thresholds

### Modifying Routes
Edit VirtualService files to change:
- URI matching patterns
- Traffic splitting ratios
- Request/response transformations

### Security Policies
Edit AuthorizationPolicy files to:
- Add/remove allowed principals
- Restrict HTTP methods
- Add custom authorization rules

## Clean Up

To remove Istio configurations:
```bash
kubectl delete namespace gym-reg
kubectl delete -f istio/
```

To uninstall Istio:
```bash
istioctl uninstall --purge -y
kubectl delete namespace istio-system
```
