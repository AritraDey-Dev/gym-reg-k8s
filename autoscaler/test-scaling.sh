#!/bin/bash

echo "Starting Full Stack Load Test for Autoscaling..."
echo "This script will deploy load generators for Frontend, Backend Main, and Backend Stream."

# 1. Deploy Load Generators
echo "Deploying load-generator-frontend..."
kubectl run load-generator-frontend --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://frontend:3000; done" > /dev/null 2>&1

echo "Deploying load-generator-backend-main..."
kubectl run load-generator-backend-main --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://backend-main:9084; done" > /dev/null 2>&1

echo "Deploying load-generator-backend-stream..."
kubectl run load-generator-backend-stream --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://backend-stream:9085; done" > /dev/null 2>&1

echo "All load generators started."
echo "Waiting for load to increase... (Press Ctrl+C to stop test)"
echo ""

# 2. Monitor HPA
# Trap Ctrl+C to cleanup
trap cleanup INT

function cleanup() {
    echo ""
    echo "Stopping load test..."
    kubectl delete pod load-generator-frontend --force --grace-period=0 > /dev/null 2>&1
    kubectl delete pod load-generator-backend-main --force --grace-period=0 > /dev/null 2>&1
    kubectl delete pod load-generator-backend-stream --force --grace-period=0 > /dev/null 2>&1
    echo "Load generators deleted."
    echo "Scaling will gradually go down after a few minutes."
    exit 0
}

echo "Monitoring HPA status (Updates every 15s):"
echo "TARGETS format: <Current CPU>% / <Target CPU>%"
echo "---------------------------------------------------"

while true; do
    clear
    echo "Load Generators: RUNNING (Frontend, Backend-Main, Backend-Stream)"
    echo "Press Ctrl+C to stop."
    echo ""
    echo "Current HPA Status:"
    kubectl get hpa
    echo ""
    echo "Top Pods (CPU Usage):"
    kubectl top pods | grep -E "(frontend|backend)"
    sleep 15
done
