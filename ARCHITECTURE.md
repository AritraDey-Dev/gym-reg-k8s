# Gym Registration System Architecture

## System Architecture with Istio Service Mesh

```
┌─────────────────────────────────────────────────────────────────────┐
│                         External Users                               │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ HTTP/HTTPS
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Istio Ingress Gateway                             │
│                   (Port 80/443 - TLS Termination)                    │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             │ Intelligent Routing
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│   Frontend    │   │  Admin Panel  │   │    Backend    │
│  VirtualSvc   │   │  VirtualSvc   │   │  VirtualSvc   │
│   Path: /     │   │ Path: /admin  │   │ Path: /api/*  │
└───────┬───────┘   └───────┬───────┘   └───────┬───────┘
        │                    │                    │
        │                    │           ┌────────┴────────┐
        │                    │           │                 │
        ▼                    ▼           ▼                 ▼
┌───────────────┐   ┌───────────────┐   ┌───────────┐   ┌───────────┐
│               │   │               │   │ Backend   │   │ Backend   │
│   Frontend    │   │  Admin Panel  │   │   Main    │   │  Stream   │
│   Service     │   │   Service     │   │  Service  │   │  Service  │
│  (Port 3000)  │   │  (Port 3001)  │   │(9084/9083)│   │(9085/9086)│
└───────┬───────┘   └───────┬───────┘   └─────┬─────┘   └─────┬─────┘
        │                    │                 │               │
        │                    │                 │               │
        │  Istio Sidecar (Envoy Proxy)        │               │
        │  - mTLS Encryption                   │               │
        │  - Load Balancing                    │               │
        │  - Circuit Breaking                  │               │
        │  - Metrics & Tracing                 │               │
        │                    │                 │               │
        └────────────────────┼─────────────────┴───────────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
                    ▼                 ▼
            ┌───────────────┐  ┌───────────────┐
            │     MySQL     │  │     Redis     │
            │   Database    │  │     Cache     │
            │  (Port 3306)  │  │  (Port 6379)  │
            └───────────────┘  └───────────────┘
                    │                 │
                    └─────────────────┘
                             │
                    Persistent Storage
                    (PV/PVC)
```

## Component Details

### Istio Components

#### 1. Istio Ingress Gateway
- **Purpose**: Single entry point for all external traffic
- **Features**:
  - TLS/SSL termination
  - Load balancing across services
  - Rate limiting capabilities
  - Request authentication
- **Ports**:
  - 80 (HTTP)
  - 443 (HTTPS)

#### 2. Virtual Services
Define routing rules for traffic:

| Service | Path | Target | Port |
|---------|------|--------|------|
| Frontend | `/` | frontend | 3000 |
| Admin Panel | `/admin` | admin-panel | 3001 |
| Backend Main | `/api/main/*` | backend-main | 9084 |
| Backend Stream | `/api/stream/*` | backend-stream | 9085 |

#### 3. Destination Rules
Configure traffic policies:

| Service | Load Balancer | Max Connections | Circuit Breaker |
|---------|---------------|-----------------|-----------------|
| Frontend | LEAST_REQUEST | 100 | 5 errors/30s |
| Admin Panel | LEAST_REQUEST | 100 | 5 errors/30s |
| Backend Main | LEAST_REQUEST | 200 | 5 errors/30s |
| Backend Stream | LEAST_REQUEST | 200 | 5 errors/30s |
| MySQL | ROUND_ROBIN | 50 | N/A |
| Redis | ROUND_ROBIN | 100 | N/A |

#### 4. Sidecar Proxy (Envoy)
Automatically injected into each pod:
- **Traffic Management**: Intercepts all inbound/outbound traffic
- **Security**: Enforces mTLS, authorization policies
- **Observability**: Collects metrics, traces, logs

### Application Services

#### Frontend (Next.js)
- **Purpose**: User-facing web application
- **Port**: 3000
- **Features**:
  - User registration
  - Class booking
  - Profile management
- **Dependencies**: Backend Main, Backend Stream

#### Admin Panel (Next.js)
- **Purpose**: Administrative interface
- **Port**: 3001
- **Features**:
  - User management
  - Class scheduling
  - Analytics dashboard
- **Dependencies**: Backend Main

#### Backend Main (Go/Node.js)
- **Purpose**: Primary API service
- **Ports**:
  - 9084 (HTTP REST API)
  - 9083 (gRPC/gRPC-Web)
- **Features**:
  - User authentication
  - CRUD operations
  - Business logic
- **Dependencies**: MySQL, Redis

#### Backend Stream (Go/Node.js)
- **Purpose**: Real-time streaming service
- **Ports**:
  - 9085 (HTTP REST API)
  - 9086 (gRPC/gRPC-Web)
- **Features**:
  - Real-time notifications
  - Live updates
  - Event streaming
- **Dependencies**: MySQL, Redis

### Infrastructure Services

#### MySQL
- **Purpose**: Primary relational database
- **Port**: 3306
- **Storage**: PersistentVolume (10Gi)
- **Features**:
  - User data
  - Class schedules
  - Bookings

#### Redis
- **Purpose**: In-memory cache
- **Port**: 6379
- **Storage**: PersistentVolume (5Gi)
- **Features**:
  - Session management
  - Caching
  - Pub/Sub messaging

## Traffic Flow

### User Request Flow

```
1. User → Istio Ingress Gateway
   - TLS termination
   - Authentication (optional)
   
2. Istio Ingress Gateway → Virtual Service
   - Route based on path
   - Apply request matching
   
3. Virtual Service → Destination Rule
   - Select backend pod
   - Apply load balancing
   
4. Destination Rule → Service
   - Health check
   - Circuit breaker evaluation
   
5. Service → Pod (Application + Sidecar)
   - mTLS encryption
   - Authorization check
   - Request logging
   
6. Application → Database/Cache
   - Through sidecar proxy
   - Connection pooling
   - Metrics collection
```

### Service-to-Service Communication

```
Service A → Envoy Sidecar A
         → mTLS encryption
         → Envoy Sidecar B
         → Service B
         
All traffic:
- Encrypted with mTLS
- Authorized by policy
- Traced end-to-end
- Monitored with metrics
```

## Security Architecture

### Multi-Layer Security

```
┌─────────────────────────────────────────────┐
│         Layer 1: Gateway Security            │
│  - TLS/SSL encryption                        │
│  - External authentication                   │
│  - Rate limiting                             │
└─────────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────────┐
│         Layer 2: mTLS (Mutual TLS)          │
│  - Service identity verification            │
│  - Encrypted communication                   │
│  - Automatic cert rotation                   │
└─────────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────────┐
│      Layer 3: Authorization Policies         │
│  - Service-level access control              │
│  - Namespace isolation                       │
│  - HTTP method restrictions                  │
└─────────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────────┐
│       Layer 4: Network Policies              │
│  - Pod-to-pod restrictions                   │
│  - Egress control                            │
└─────────────────────────────────────────────┘
```

### mTLS Configuration

| Service Type | mTLS Mode | Reason |
|-------------|-----------|---------|
| Frontend | STRICT | Full security for external-facing service |
| Admin Panel | STRICT | Protect sensitive admin operations |
| Backend Main | STRICT | Secure API endpoints |
| Backend Stream | STRICT | Protect streaming connections |
| MySQL | PERMISSIVE | Legacy compatibility, gradual migration |
| Redis | PERMISSIVE | Legacy compatibility, gradual migration |

## Observability Architecture

### Metrics Collection

```
┌─────────────────────────────────────────────┐
│              Applications                    │
│  (with Envoy Sidecar Proxies)              │
└──────────────┬──────────────────────────────┘
               │ Metrics Export
               ▼
┌─────────────────────────────────────────────┐
│            Prometheus                        │
│  - Scrapes metrics from sidecars            │
│  - Stores time-series data                  │
│  - Provides query interface                 │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│             Grafana                          │
│  - Visualizes metrics                       │
│  - Pre-built Istio dashboards               │
│  - Custom dashboards                        │
└─────────────────────────────────────────────┘
```

### Distributed Tracing

```
┌─────────────────────────────────────────────┐
│           Request Enters System              │
└──────────────┬──────────────────────────────┘
               │ Trace ID generated
               ▼
┌─────────────────────────────────────────────┐
│      Each Service Records Span               │
│  - Service name                             │
│  - Start/end time                           │
│  - Tags and logs                            │
└──────────────┬──────────────────────────────┘
               │ Send to Zipkin/Jaeger
               ▼
┌─────────────────────────────────────────────┐
│          Tracing Backend                     │
│  - Aggregates spans                         │
│  - Builds complete trace                    │
│  - Provides visualization                   │
└─────────────────────────────────────────────┘
```

### Key Metrics Tracked

1. **Request Metrics**
   - Request rate (requests/second)
   - Request duration (latency)
   - Request size

2. **Response Metrics**
   - Response codes (2xx, 4xx, 5xx)
   - Response size
   - Error rate

3. **Service Metrics**
   - Active connections
   - Queue depth
   - Circuit breaker status

4. **Infrastructure Metrics**
   - CPU usage
   - Memory usage
   - Network I/O

## Resilience Patterns

### Circuit Breaking

```
Normal State → Detecting Failures → Open Circuit
     ↑                                    │
     │                                    │
     └────────── Half-Open ←──────────────┘
                (After timeout)
```

**Configuration:**
- Consecutive errors: 5
- Check interval: 30s
- Ejection time: 30s
- Max ejection: 50%

### Retry Policy

- Automatic retry on failure
- Exponential backoff
- Max retries: 3
- Per-try timeout: 2s

### Timeout Policy

| Service | Timeout |
|---------|---------|
| Frontend | 30s |
| Admin Panel | 30s |
| Backend Main | 15s |
| Backend Stream | 60s (long-polling) |
| MySQL | 30s |
| Redis | 5s |

## Scaling Strategy

### Horizontal Pod Autoscaling (HPA)

```
┌─────────────────────────────────────────────┐
│         Metrics Server                       │
│  - Collects resource metrics                │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│    HPA Controller                            │
│  - Monitors CPU/Memory                       │
│  - Scales replicas up/down                  │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│         Deployments                          │
│  - Frontend: 1-10 replicas                  │
│  - Backend Main: 1-10 replicas              │
│  - Backend Stream: 1-10 replicas            │
└─────────────────────────────────────────────┘
```

### Vertical Pod Autoscaling (VPA)

- Automatically adjusts resource requests/limits
- Based on actual usage patterns
- Prevents over/under-provisioning

## Deployment Strategies

### Blue-Green Deployment

```
┌─────────────────┐       ┌─────────────────┐
│   Blue (v1)     │       │   Green (v2)    │
│   Running       │       │   Deployed      │
└────────┬────────┘       └────────┬────────┘
         │                         │
         │   Switch Traffic        │
         └──────────►◄─────────────┘
```

### Canary Deployment

```
┌─────────────────────────────────────────────┐
│            All Traffic (100%)                │
└──────────────┬──────────────────────────────┘
               │
        ┌──────┴──────┐
        │             │
  95% (v1)      5% (v2)
    Stable      Canary
        │             │
        └──── Monitor ───┘
              │
        Gradual shift to v2
```

## Network Policies

### Ingress Rules

```
External → Gateway → Frontend/Admin/Backend
                     (Allowed)

External ✗→ MySQL/Redis
            (Denied)
```

### Egress Rules

```
Applications → External APIs
              (Controlled via ServiceEntry)

Applications → Internet
              (Restricted)
```

## Best Practices Implemented

1. **Security**
   - ✅ mTLS for all service communication
   - ✅ Authorization policies per service
   - ✅ Secret management
   - ✅ Network isolation

2. **Reliability**
   - ✅ Circuit breakers
   - ✅ Retry policies
   - ✅ Timeouts
   - ✅ Health checks

3. **Observability**
   - ✅ Distributed tracing (100% sampling)
   - ✅ Metrics collection
   - ✅ Access logging
   - ✅ Service mesh visualization

4. **Performance**
   - ✅ Connection pooling
   - ✅ Load balancing
   - ✅ Resource limits
   - ✅ Caching strategy

5. **Scalability**
   - ✅ Horizontal pod autoscaling
   - ✅ Vertical pod autoscaling
   - ✅ Persistent storage
   - ✅ Stateless design

## Future Enhancements

- [ ] Multi-cluster deployment
- [ ] Advanced traffic splitting (A/B testing)
- [ ] Service Level Objectives (SLOs)
- [ ] Chaos engineering with Istio
- [ ] Advanced security policies (RBAC)
- [ ] Custom metrics and alerts
- [ ] GitOps with Argo CD/Flux
