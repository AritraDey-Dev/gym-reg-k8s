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
echo "⏳ Waiting for Metrics Server rollout..."
kubectl -n kube-system rollout status deployment metrics-server --timeout=300s

# 2. Apply HPAs and Load Generator
echo "⚖️ Applying HPA configurations..."
kubectl apply -f autoscaler/

# Patch HPAs to 5% to ensure scaling in CI
echo "🔧 Patching HPA targets to 5% for test..."
kubectl patch hpa backend-main-hpa --type='json' -p='[{"op": "replace", "path": "/spec/metrics/0/resource/target/averageUtilization", "value": 2}]'
kubectl patch hpa backend-stream-hpa --type='json' -p='[{"op": "replace", "path": "/spec/metrics/0/resource/target/averageUtilization", "value": 2}]'
kubectl patch hpa frontend-hpa --type='json' -p='[{"op": "replace", "path": "/spec/metrics/0/resource/target/averageUtilization", "value": 2}]'
kubectl patch hpa admin-panel-hpa --type='json' -p='[{"op": "replace", "path": "/spec/metrics/0/resource/target/averageUtilization", "value": 2}]'

echo "🔥 Applying Load Generator Job..."
# Ensure job is applied (in case it wasn't in autoscaler/ dir or needs re-apply)
kubectl apply -f autoscaler/load-test-job.yaml

# 3. Monitor Scaling
echo "👀 Monitoring scaling for all services..."
START_TIME=$(date +%s)

SERVICES=("backend-main" "backend-stream" "frontend" "admin-panel")
SCALED_SERVICES=()

while true; do
  ALL_SCALED=true
  
  for SERVICE in "${SERVICES[@]}"; do
    # Skip if already scaled
    if [[ " ${SCALED_SERVICES[*]} " =~ " ${SERVICE} " ]]; then
      continue
    fi

    CURRENT_REPLICAS=$(kubectl get deployment $SERVICE -o=jsonpath='{.status.replicas}')
    # Handle empty/error
    if [ -z "$CURRENT_REPLICAS" ]; then CURRENT_REPLICAS=0; fi

    if [ "$CURRENT_REPLICAS" -ge "$TARGET_REPLICAS" ]; then
      echo "✅ $SERVICE scaled to $CURRENT_REPLICAS replicas!"
      SCALED_SERVICES+=("$SERVICE")
    else
      ALL_SCALED=false
      # Get CPU usage for logging
      CPU_USAGE=$(kubectl get hpa "${SERVICE}-hpa" -o=jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}')
      echo "   $SERVICE: Replicas=$CURRENT_REPLICAS/$TARGET_REPLICAS | CPU=${CPU_USAGE:-0}%"
    fi
  done

  if [ "$ALL_SCALED" = true ]; then
    echo "🎉 All services scaled successfully!"
    break
  fi

  if [ $(($(date +%s) - $START_TIME)) -gt $TIMEOUT ]; then
    echo "❌ Timeout waiting for services to scale."
    echo "Scaled so far: ${SCALED_SERVICES[*]}"
    kubectl get hpa
    kubectl get pods
    exit 1
  fi

  sleep 15
done

# Cleanup
kubectl delete -f autoscaler/load-test-job.yaml
