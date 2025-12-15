# Cilium Setup & Usage Guide

This directory contains resources and documentation for managing Cilium CNI in the `gym-reg-k8s` cluster.

## 🚀 Installation

### Prerequisites
- Kubernetes cluster (Kind, Minikube, or Cloud Provider)
- `helm` installed
- `cilium` CLI installed (optional but recommended)

### Option 1: Install via Cilium CLI (Recommended)
The easiest way to install Cilium is using the CLI.

```bash
cilium install --version 1.16.1
```

To enable Hubble for observability:
```bash
cilium hubble enable --ui
```

### Option 2: Install via Helm
If you prefer Helm or need to customize values:

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium --version 1.16.1 \
   --namespace kube-system \
   --set hubble.relay.enabled=true \
   --set hubble.ui.enabled=true
```

## ✅ Verification

### Check Pod Status
Ensure all Cilium pods are running in the `kube-system` namespace:

```bash
kubectl get pods -n kube-system -l k8s-app=cilium
```

### Run Connectivity Test
The Cilium CLI provides a built-in connectivity test suite:

```bash
cilium connectivity test
```
*Note: This may take a few minutes to complete.*

### Verify Hubble Status
Check if Hubble Relay and UI are running:

```bash
kubectl get pods -n kube-system -l k8s-app=hubble-ui
kubectl get pods -n kube-system -l k8s-app=hubble-relay
```

## 🔭 Observability with Hubble

Hubble provides deep visibility into the network flows of your cluster.

### Accessing the UI
To access the Hubble UI, use the Cilium CLI to create a port-forward:

```bash
cilium hubble ui
```
This will open the UI in your default browser (usually at `http://localhost:12000`).

### Using Hubble CLI
You can also observe flows directly from the command line:

```bash
# Observe all flows
cilium hubble observe

# Observe flows for a specific namespace
cilium hubble observe -n default

# Observe dropped packets
cilium hubble observe --verdict DROPPED
```

---

## 🔐 Advanced Security: Tetragon

Tetragon provides eBPF-based security observability and runtime enforcement.

### Installation
```bash
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install tetragon cilium/tetragon -n kube-system
```

### Usage
Observe process execution events in real-time:
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=tetragon -c export-stdout -f | tetra getevents -o compact
```

---

## 🛡️ Transparent Encryption (WireGuard)

Cilium can transparently encrypt all traffic between pods using WireGuard.

### Enable Encryption
Upgrade your Cilium installation to enable WireGuard:

```bash
cilium upgrade --encryption wireguard
```

Or via Helm:
```bash
helm upgrade cilium cilium/cilium \
   --namespace kube-system \
   --reuse-values \
   --set encryption.enabled=true \
   --set encryption.type=wireguard
```

### Verify Encryption
Check the encryption status from a Cilium pod:
```bash
kubectl -n kube-system exec -ti ds/cilium -- cilium encrypt status
```

---

## 🕸️ Service Mesh & Ingress

Cilium can act as a fully featured Ingress Controller and Gateway API implementation.

### Enable Ingress Controller
```bash
helm upgrade cilium cilium/cilium \
   --namespace kube-system \
   --reuse-values \
   --set ingressController.enabled=true \
   --set ingressController.loadbalancerMode=dedicated
```

### Example Ingress Resource
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: basic-ingress
  annotations:
    ingress.cilium.io/loadbalancer-mode: dedicated
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
```

---

## 🚦 Network Policies (L3/L4 & L7)

Cilium Network Policies (CNP) provide advanced Layer 3/4 and Layer 7 filtering.

### Example: Deny All (Default Deny)
Create a file `deny-all.yaml`:
```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: default-deny
  namespace: default
spec:
  endpointSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### Example: Layer 7 HTTP Policy
Allow only `GET /public` on the backend service:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: l7-visibility
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
  - toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/public"
```

### Where to store policies?
Please store your custom `CiliumNetworkPolicy` manifests in this directory (`cilium/`) or a `policies/` subdirectory to keep them organized.
