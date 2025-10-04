# Gym Registration System - Kubernetes Deployment with Istio

A complete Kubernetes deployment configuration for a Gym Registration System with Istio service mesh integration.

## Architecture

The system consists of the following microservices:

### Application Services
- **Frontend** - User-facing Next.js application (Port 3000)
- **Admin Panel** - Administrative interface (Port 3001)
- **Backend Main** - Primary API service (HTTP: 9084, gRPC: 9083)
- **Backend Stream** - Streaming API service (HTTP: 9085, gRPC: 9086)

### Infrastructure Services
- **MySQL** - Primary database (Port 3306)
- **Redis** - Caching layer (Port 6379)

## Istio Service Mesh

This deployment includes comprehensive Istio service mesh configuration providing:

### Traffic Management
- **Intelligent Routing**: Path-based routing through Istio Gateway
- **Load Balancing**: Least-request load balancing for optimal performance
- **Circuit Breaking**: Automatic failover for unhealthy services
- **Connection Pooling**: Managed connection limits

### Security
- **mTLS**: Mutual TLS for all service-to-service communication
- **Authorization Policies**: Fine-grained access control
- **Network Policies**: Restrict traffic flow between services

### Observability
- **Distributed Tracing**: Full request tracing with Zipkin
- **Metrics**: Prometheus integration for monitoring
- **Access Logs**: Comprehensive logging via Envoy

## Prerequisites

1. **Kubernetes Cluster**: A running Kubernetes cluster (v1.20+)
   - Local: Kind, Minikube, Docker Desktop
   - Cloud: GKE, EKS, AKS

2. **kubectl**: Kubernetes command-line tool
   ```bash
   # Install kubectl
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   chmod +x kubectl
   sudo mv kubectl /usr/local/bin/
   ```

3. **Istio**: Service mesh platform (v1.18+)
   ```bash
   # Download and install Istio
   curl -L https://istio.io/downloadIstio | sh -
   cd istio-*
   export PATH=$PWD/bin:$PATH
   
   # Install Istio
   istioctl install --set profile=default -y
   
   # Verify installation
   kubectl get pods -n istio-system
   ```

## Quick Start

### Option 1: Using the Deploy Script (Recommended)

```bash
cd istio
./deploy-all.sh
```

This script will:
1. Create the namespace with Istio injection enabled
2. Deploy all application services
3. Configure Istio gateway, virtual services, and destination rules
4. Set up security policies and observability

### Option 2: Manual Deployment

```bash
# 1. Create namespace with Istio injection
kubectl apply -f istio/namespace.yaml

# 2. Deploy infrastructure services
kubectl apply -f mysql/ -n gym-reg
kubectl apply -f redis/ -n gym-reg

# 3. Deploy application services
kubectl apply -f backend/ -n gym-reg
kubectl apply -f frontend/ -n gym-reg
kubectl apply -f admin-panel/ -n gym-reg

# 4. Deploy Istio configurations
kubectl apply -f istio/gateway.yaml
kubectl apply -f istio/virtualservice-*.yaml
kubectl apply -f istio/destinationrule-*.yaml
kubectl apply -f istio/peer-authentication.yaml
kubectl apply -f istio/authorization-policy.yaml
kubectl apply -f istio/sidecar.yaml
kubectl apply -f istio/service-entry.yaml
kubectl apply -f istio/telemetry.yaml
```

### Option 3: Using Kustomize

```bash
kubectl apply -k istio/
```

## Accessing the Application

### Get the Ingress Gateway Address

```bash
kubectl get svc istio-ingressgateway -n istio-system
```

### Access URLs

Replace `<EXTERNAL-IP>` with the external IP from the command above:

- **Frontend**: `http://<EXTERNAL-IP>/`
- **Admin Panel**: `http://<EXTERNAL-IP>/admin`
- **Backend Main API**: `http://<EXTERNAL-IP>/api/main`
- **Backend Stream API**: `http://<EXTERNAL-IP>/api/stream`

### For Local Development (Port Forward)

If you don't have a LoadBalancer:

```bash
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
```

Then access:
- Frontend: `http://localhost:8080/`
- Admin Panel: `http://localhost:8080/admin`

## Monitoring and Observability

### Kiali Dashboard (Service Mesh Visualization)
```bash
istioctl dashboard kiali
```

### Grafana (Metrics and Dashboards)
```bash
istioctl dashboard grafana
```

### Prometheus (Metrics)
```bash
istioctl dashboard prometheus
```

### Jaeger (Distributed Tracing)
```bash
istioctl dashboard jaeger
```

## Directory Structure

```
.
├── admin-panel/           # Admin panel Kubernetes manifests
│   ├── configmap.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── backend/               # Backend services manifests
│   ├── backend-main-deployment.yaml
│   ├── backend-main-service.yaml
│   ├── backend-stream-deployment.yaml
│   ├── backend-stream-service.yaml
│   ├── config.yaml
│   └── secret.yaml
├── frontend/              # Frontend application manifests
│   ├── configmap.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── mysql/                 # MySQL database manifests
│   ├── config.yaml
│   ├── deployment.yaml
│   ├── mysql-pv.yaml
│   ├── mysql-pvc.yaml
│   ├── secret.yaml
│   └── service.yaml
├── redis/                 # Redis cache manifests
│   ├── config.yaml
│   ├── deployment.yaml
│   ├── redis-pv.yaml
│   ├── redis-pvc.yaml
│   ├── secret.yaml
│   └── service.yaml
├── istio/                 # Istio service mesh configurations
│   ├── README.md
│   ├── namespace.yaml
│   ├── gateway.yaml
│   ├── virtualservice-*.yaml
│   ├── destinationrule-*.yaml
│   ├── peer-authentication.yaml
│   ├── authorization-policy.yaml
│   ├── sidecar.yaml
│   ├── service-entry.yaml
│   ├── telemetry.yaml
│   ├── kustomization.yaml
│   ├── deploy-all.sh
│   └── cleanup.sh
├── autoscaler/            # Auto-scaling configurations
│   ├── backend-main-hpa.yaml
│   ├── backend-main-vpa.yaml
│   ├── backend-stream-hpa.yaml
│   └── backend-stream-vpa.yaml
└── cluster/               # Cluster configuration
    └── cluster.yaml
```

## Istio Features

### 1. Traffic Management

#### Gateway
- Single entry point for external traffic
- HTTP (port 80) and HTTPS (port 443) support
- TLS termination ready

#### Virtual Services
- Path-based routing
- Request matching
- Traffic splitting capabilities

#### Destination Rules
- Load balancing strategies
- Connection pool management
- Circuit breaker configuration
- Health checks and outlier detection

### 2. Security

#### mTLS (Mutual TLS)
- STRICT mode for application services
- PERMISSIVE mode for databases (gradual migration)
- Automatic certificate rotation

#### Authorization Policies
- Service-level access control
- Namespace isolation
- HTTP method restrictions

### 3. Observability

#### Metrics
- Request rate, latency, error rate
- Custom metrics collection
- Prometheus integration

#### Tracing
- 100% request sampling
- End-to-end visibility
- Performance analysis

#### Logging
- Envoy access logs
- Structured logging format
- Log aggregation ready

## Configuration

### Customize Istio Settings

All Istio configurations are in the `istio/` directory. Key files:

- **gateway.yaml**: Configure ingress ports and TLS
- **virtualservice-*.yaml**: Modify routing rules
- **destinationrule-*.yaml**: Adjust traffic policies
- **peer-authentication.yaml**: Change mTLS settings
- **authorization-policy.yaml**: Update access control

### Environment Variables

Application environment variables are configured via:
- ConfigMaps: `*/configmap.yaml`
- Secrets: `*/secret.yaml`

### Resource Limits

Adjust resource requests/limits in deployment files:
- `*/deployment.yaml` - containers.resources section

## Scaling

### Horizontal Pod Autoscaler (HPA)

HPA configurations are available in `autoscaler/`:
```bash
kubectl apply -f autoscaler/ -n gym-reg
```

### Manual Scaling

```bash
kubectl scale deployment frontend --replicas=3 -n gym-reg
kubectl scale deployment backend-main --replicas=3 -n gym-reg
```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n gym-reg
kubectl describe pod <pod-name> -n gym-reg
```

### View Logs
```bash
# Application logs
kubectl logs <pod-name> -n gym-reg -c <container-name>

# Istio sidecar logs
kubectl logs <pod-name> -n gym-reg -c istio-proxy
```

### Istio Configuration Analysis
```bash
istioctl analyze -n gym-reg
```

### Check Virtual Service Configuration
```bash
kubectl get virtualservices -n gym-reg
kubectl describe virtualservice <name> -n gym-reg
```

### Verify mTLS Status
```bash
istioctl authn tls-check <pod-name>.<namespace>
```

## Cleanup

### Remove All Resources

```bash
cd istio
./cleanup.sh
```

### Manual Cleanup

```bash
# Delete namespace (removes all resources)
kubectl delete namespace gym-reg

# Delete Istio configurations
kubectl delete -f istio/
```

### Uninstall Istio

```bash
istioctl uninstall --purge -y
kubectl delete namespace istio-system
```

## Security Best Practices

1. **Update Secrets**: Change default passwords in secret files before deployment
2. **Enable TLS**: Configure proper TLS certificates for production
3. **Network Policies**: Apply strict network policies
4. **RBAC**: Implement proper role-based access control
5. **Image Scanning**: Scan container images for vulnerabilities
6. **Regular Updates**: Keep Istio and Kubernetes up to date

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License.

## Support

For issues and questions:
- Create an issue in the GitHub repository
- Check the Istio documentation: https://istio.io/docs
- Kubernetes documentation: https://kubernetes.io/docs

## Additional Resources

- [Istio Documentation](https://istio.io/latest/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Kiali Documentation](https://kiali.io/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
