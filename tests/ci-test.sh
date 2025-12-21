#!/bin/bash
set -e

# Define Cluster Name
CLUSTER_NAME="gym-reg-ci"

# Detect the current kubectl context
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")

# Determine if we're using Kind or Minikube or need to create a cluster
if [ -n "$CURRENT_CONTEXT" ]; then
  echo "✅ Using existing cluster context: $CURRENT_CONTEXT"
  KUBECTL_CONTEXT="$CURRENT_CONTEXT"
elif kind get clusters 2>/dev/null | grep -q "$CLUSTER_NAME"; then
  echo "✅ Using existing Kind cluster: $CLUSTER_NAME"
  KUBECTL_CONTEXT="kind-$CLUSTER_NAME"
else
  echo "🚀 Creating new Kind cluster: $CLUSTER_NAME"
  kind create cluster --name "$CLUSTER_NAME"
  KUBECTL_CONTEXT="kind-$CLUSTER_NAME"
fi

echo "🚀 Starting CI Test with context: $KUBECTL_CONTEXT..."

# 2. Apply Secrets
if [ -f backend/secret.yaml ]; then
  echo "🔑 Applying existing secret.yaml..."
  kubectl apply -f backend/secret.yaml --context "$KUBECTL_CONTEXT"
else
  echo "🔑 Generating dummy secrets (secret.yaml missing)..."
  kubectl create secret generic backend-shared-secret \
    --from-literal=DB_PASSWORD=dummy \
    --from-literal=JWT_SECRET=dummy \
    --from-literal=RECAPTCHA_SECRET=dummy \
    --context "$KUBECTL_CONTEXT" --dry-run=client -o yaml | kubectl apply --context "$KUBECTL_CONTEXT" -f -
fi

# 3. Generate Dummy CA Cert ConfigMap (If missing)
if [ ! -f backend/ca-cert-configmap.yaml ]; then
  echo "📜 Generating dummy CA cert configmap..."
  kubectl create configmap ca-cert-config \
    --from-literal=ca-cert.pem="DUMMY CERT CONTENT" \
    --context "$KUBECTL_CONTEXT" --dry-run=client -o yaml | kubectl apply --context "$KUBECTL_CONTEXT" -f -
else
  echo "📜 Applying existing ca-cert-configmap.yaml..."
  kubectl apply -f backend/ca-cert-configmap.yaml --context "$KUBECTL_CONTEXT"
fi

# 4. Apply Database Manifests
echo "�️ Applying Database manifests (MySQL & Redis)..."
kubectl apply -f mysql/ --context "$KUBECTL_CONTEXT"
kubectl apply -f redis/ --context "$KUBECTL_CONTEXT"

echo "⏳ Waiting for Databases to be ready..."
kubectl wait --for=condition=ready pod -l app=mysql --timeout=600s --context "$KUBECTL_CONTEXT"
kubectl wait --for=condition=ready pod -l app=redis --timeout=600s --context "$KUBECTL_CONTEXT"

# 5. Apply Backend Manifests
echo "⚙️ Applying Backend manifests..."
kubectl apply -f backend/config.yaml --context "$KUBECTL_CONTEXT"
kubectl apply -f backend/backend-main-deployment.yaml --context "$KUBECTL_CONTEXT"
kubectl apply -f backend/backend-main-service.yaml --context "$KUBECTL_CONTEXT"
kubectl apply -f backend/backend-stream-deployment.yaml --context "$KUBECTL_CONTEXT"
kubectl apply -f backend/backend-stream-service.yaml --context "$KUBECTL_CONTEXT"

echo "⏳ Waiting for Backends to be ready..."
kubectl wait --for=condition=ready pod -l app=backend-main --timeout=600s --context "$KUBECTL_CONTEXT"
kubectl wait --for=condition=ready pod -l app=backend-stream --timeout=600s --context "$KUBECTL_CONTEXT"

# 6. Apply Frontend Manifests
echo "💻 Applying Frontend & Admin manifests..."
kubectl apply -f frontend/configmap.yaml --context "$KUBECTL_CONTEXT"
kubectl apply -f admin-panel/configmap.yaml --context "$KUBECTL_CONTEXT"
kubectl apply -f admin-panel/next-config-map.yaml --context "$KUBECTL_CONTEXT"

echo "⏳ Waiting for ConfigMaps to propagate..."
sleep 10

kubectl apply -f frontend/deployment.yaml --context "$KUBECTL_CONTEXT"
kubectl apply -f frontend/service.yaml --context "$KUBECTL_CONTEXT"
kubectl apply -f admin-panel/deployment.yaml --context "$KUBECTL_CONTEXT"
kubectl apply -f admin-panel/service.yaml --context "$KUBECTL_CONTEXT"

echo "⏳ Waiting for Frontend/Admin to be ready..."
kubectl wait --for=condition=ready pod -l app=frontend --timeout=600s --context "$KUBECTL_CONTEXT"
kubectl wait --for=condition=ready pod -l app=admin-panel --timeout=600s --context "$KUBECTL_CONTEXT"

# 7. Stability Check
echo "🕵️ Checking for stability (waiting 30s)..."
sleep 30
kubectl get pods --context "$KUBECTL_CONTEXT"

# Check for restarts
RESTARTS=$(kubectl get pods --context "$KUBECTL_CONTEXT" --no-headers | awk '{print $4}' | awk '{s+=$1} END {print s}')
if [ "$RESTARTS" -gt 0 ]; then
  echo "❌ Detected $RESTARTS restarts! Test Failed."
  kubectl get pods --context "$KUBECTL_CONTEXT"
  exit 1
else
  echo "✅ No restarts detected."
fi

echo "🎉 CI Test Passed! All pods are running and stable."
