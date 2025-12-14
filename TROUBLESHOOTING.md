# Kubernetes Deployment Fixes & Troubleshooting

This document summarizes the fixes applied to get the Gym Registration application running on Kubernetes.

## 1. Frontend & Admin Panel OOM (Out of Memory)
**Issue:** The `next build` process inside the pods was consuming too much memory, causing `OOMKilled` errors and `CrashLoopBackOff`.
**Fix:**
- **Optimized Build:** Updated `deployment.yaml` to skip linting, type checking, and telemetry during build to save memory.
  ```bash
  export NEXT_TELEMETRY_DISABLED=1
  ./node_modules/.bin/next build --no-lint --no-mangling && npm start
  ```
- **Memory Settings:**
  - Reduced `requests.memory` to `512Mi` to allow scheduling on smaller nodes.
  - Kept `NODE_OPTIONS="--max-old-space-size=2048"` to limit Node.js heap usage.
  - Disabled source maps (`GENERATE_SOURCEMAP=false`).

## 2. Port Forwarding Conflicts
**Issue:** `kubectl port-forward` failed with "address already in use" because old Docker containers or processes were holding ports `9083-9086`.
**Fix:**
- Stopped conflicting Docker containers.
- Used the following commands to expose services:
  ```bash
  # Frontend (http://localhost:3000)
  kubectl port-forward svc/frontend 3000:3000

  # Admin Panel (http://localhost:3001)
  kubectl port-forward svc/admin-panel 3001:3001

  # Backend Main (HTTP: 9084, gRPC: 9083)
  kubectl port-forward svc/backend-main 9084:9084 9083:9083

  # Backend Stream (HTTP: 9085, gRPC: 9086)
  kubectl port-forward svc/backend-stream 9085:9085 9086:9086
  ```

## 3. Backend CA Certificate Missing
**Issue:** The backend failed to start or authenticate because `/app/ca-cert.pem` was missing.
**Fix:**
- Created a ConfigMap from the local `ca-cert.pem` file:
  ```bash
  kubectl create configmap ca-cert-config --from-file=ca-cert.pem=gym-reg-k8s/ca-cert.pem -o yaml > gym-reg-k8s/backend/ca-cert-configmap.yaml
  kubectl apply -f gym-reg-k8s/backend/ca-cert-configmap.yaml
  ```
- Mounted this ConfigMap as a volume in `backend-main` and `backend-stream` deployments at `/app/ca-cert.pem`.

## 4. OTP Generation Failed (DNS Issue)
**Issue:** The backend tried to connect to `grpc.lcas.spider-nitt.org` but resolved it to `127.0.0.1` (localhost), causing "connection refused".
**Fix:**
- Added `hostAliases` to `backend-main-deployment.yaml` and `backend-stream-deployment.yaml` to force the correct public IP resolution:
  ```yaml
  spec:
    hostAliases:
      - ip: "14.139.162.136"
        hostnames:
          - "grpc.lcas.spider-nitt.org"
  ```
