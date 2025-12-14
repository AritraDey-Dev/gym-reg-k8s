# Autoscaling Test Guide

This guide explains how to verify that your Horizontal Pod Autoscaler (HPA) is working correctly.

## 1. Prerequisites
Ensure the Metrics Server and HPA are applied:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl apply -f autoscaler/backend-main-hpa.yaml
```

## 2. Start Monitoring
Open separate terminals to watch the HPA status for all services:
```bash
kubectl get hpa backend-main-hpa -w
```
```bash
kubectl get hpa backend-stream-hpa -w
```
```bash
kubectl get hpa frontend-hpa -w
```
```bash
kubectl get hpa admin-panel-hpa -w
```
*Initially, all should show `REPLICAS: 1` and `TARGETS: <unknown>/70%` or `0%/70%`.*

## 3. Generate Load
Apply the load generator job. This creates a pod that spams requests to your backend.
```bash
kubectl apply -f autoscaler/load-test-job.yaml
```

## 4. Observe Scaling
Wait for 1-2 minutes.
1.  You will see the `TARGETS` CPU % rise above 70% for **all** services.
2.  The `REPLICAS` count will increase (e.g., `1 -> 2 -> 4`).
3.  Check the pods:
    ```bash
    kubectl get pods
    ```

## 5. Stop the Test
Delete the load generator to stop the traffic.
```bash
kubectl delete -f autoscaler/load-test-job.yaml
```
*After a few minutes, the HPA will scale the pods back down to 1.*
