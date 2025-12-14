#!/bin/bash
set -e

# Define Cluster Name
CLUSTER_NAME="gym-reg-ci"

echo "🚀 Starting CI Test..."

# 1. Create Kind Cluster
if kind get clusters | grep -q "$CLUSTER_NAME"; then
  echo "Cluster $CLUSTER_NAME already exists."
else
  echo "Creating Kind cluster..."
  kind create cluster --name "$CLUSTER_NAME"
fi

# 2. Apply Secrets
if [ -f backend/secret.yaml ]; then
  echo "🔑 Applying existing secret.yaml..."
  kubectl apply -f backend/secret.yaml --context kind-"$CLUSTER_NAME"
else
  echo "🔑 Generating dummy secrets (secret.yaml missing)..."
  kubectl create secret generic backend-shared-secret \
    --from-literal=DB_PASSWORD=dummy \
    --from-literal=JWT_SECRET=dummy \
    --from-literal=RECAPTCHA_SECRET=dummy \
    --context kind-"$CLUSTER_NAME" --dry-run=client -o yaml | kubectl apply --context kind-"$CLUSTER_NAME" -f -
fi

# 3. Generate Dummy CA Cert ConfigMap (If missing)
if [ ! -f backend/ca-cert-configmap.yaml ]; then
  echo "📜 Generating dummy CA cert configmap..."
  kubectl create configmap ca-cert-config \
    --from-literal=ca-cert.pem="DUMMY CERT CONTENT" \
    --context kind-"$CLUSTER_NAME" --dry-run=client -o yaml | kubectl apply --context kind-"$CLUSTER_NAME" -f -
else
  echo "📜 Applying existing ca-cert-configmap.yaml..."
  kubectl apply -f backend/ca-cert-configmap.yaml --context kind-"$CLUSTER_NAME"
fi

# 4. Apply Manifests
echo "📄 Applying Kubernetes manifests..."
kubectl apply -f backend/config.yaml --context kind-"$CLUSTER_NAME"
kubectl apply -f frontend/configmap.yaml --context kind-"$CLUSTER_NAME"
kubectl apply -f admin-panel/configmap.yaml --context kind-"$CLUSTER_NAME"

kubectl apply -f mysql/ --context kind-"$CLUSTER_NAME"
kubectl apply -f redis/ --context kind-"$CLUSTER_NAME"
kubectl apply -f backend/backend-main-deployment.yaml --context kind-"$CLUSTER_NAME"
kubectl apply -f backend/backend-stream-deployment.yaml --context kind-"$CLUSTER_NAME"
kubectl apply -f frontend/deployment.yaml --context kind-"$CLUSTER_NAME"
kubectl apply -f admin-panel/deployment.yaml --context kind-"$CLUSTER_NAME"

# 5. Wait for Rollout
echo "⏳ Waiting for pods to be ready (Timeout: 5m)..."
kubectl wait --for=condition=ready pod --all --timeout=300s --context kind-"$CLUSTER_NAME"

# 6. Verification
echo "✅ Checking Pod Status..."
kubectl get pods --context kind-"$CLUSTER_NAME"

echo "🎉 CI Test Passed! All pods are running."
