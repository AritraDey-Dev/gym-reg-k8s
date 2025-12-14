#!/bin/bash
set -e

CLUSTER_NAME="gym-reg-ci"
TIMEOUT=300 # 5 minutes wait per service
TARGET_REPLICAS=5

echo "🚀 Starting Autoscaling Test..."

# Ensure context
kubectl config use-context kind-"$CLUSTER_NAME"

# 1. Install Metrics Server (Required for HPA)
echo "📊 Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# Patch for Kind (Insecure TLS)
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
echo "⏳ Waiting for Metrics Server to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=180s

# 2. Apply HPAs
echo "⚖️ Applying HPA configurations..."
kubectl apply -f autoscaler/

# Function to test scaling
test_scaling() {
  SERVICE=$1
  PORT=$2

  echo "---------------------------------------------------"
  echo "🧪 Testing Autoscaling for $SERVICE..."
  echo "---------------------------------------------------"

  # Cleanup any existing load generator
  kubectl delete pod "load-$SERVICE" --ignore-not-found=true

  # Get current replicas
  INITIAL_REPLICAS=$(kubectl get deployment $SERVICE -o=jsonpath='{.status.replicas}')
  echo "Current Replicas: $INITIAL_REPLICAS"

  # Start Load Generator
  echo "🔥 Starting Load Generator for $SERVICE..."
  kubectl run "load-$SERVICE" --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://$SERVICE:$PORT; done"

  # Wait for scaling
  START_TIME=$(date +%s)
  while true; do
    CURRENT_REPLICAS=$(kubectl get deployment $SERVICE -o=jsonpath='{.status.replicas}')
    
    # Handle empty metrics (initially)
    CPU_USAGE=$(kubectl get hpa "$SERVICE-hpa" -o=jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}')
    if [ -z "$CPU_USAGE" ]; then CPU_USAGE="0"; fi

    echo "Time: $(($(date +%s) - $START_TIME))s | Replicas: $CURRENT_REPLICAS | CPU: ${CPU_USAGE}%"

    if [ "$CURRENT_REPLICAS" -ge "$TARGET_REPLICAS" ]; then
      echo "✅ $SERVICE scaled to $CURRENT_REPLICAS replicas! Success."
      break
    fi

    if [ $(($(date +%s) - $START_TIME)) -gt $TIMEOUT ]; then
      echo "❌ Timeout waiting for $SERVICE to scale."
      kubectl get hpa "$SERVICE-hpa"
      kubectl describe hpa "$SERVICE-hpa"
      kubectl logs "load-$SERVICE"
      kubectl delete pod "load-$SERVICE" --force --grace-period=0
      exit 1
    fi

    sleep 10
  done

  # Cleanup Load Generator
  echo "🧹 Stopping Load Generator..."
  kubectl delete pod "load-$SERVICE" --force --grace-period=0
}

# 3. Run Tests sequentially
# Note: Ports must match the Service ports
test_scaling "backend-main" 9084
test_scaling "backend-stream" 9085
test_scaling "frontend" 3000
test_scaling "admin-panel" 3001

echo "🎉 All Autoscaling Tests Passed!"
