# Monitoring Setup (Prometheus & Grafana)

This guide explains how to set up a basic monitoring stack for your Kubernetes cluster.

## 1. Create Namespace
```bash
kubectl create namespace monitoring
```

## 2. Deploy Prometheus
Prometheus collects metrics from your cluster.
```bash
kubectl apply -f monitoring/prometheus.yaml
```

## 3. Deploy Grafana
Grafana visualizes the metrics.
```bash
kubectl apply -f monitoring/grafana.yaml
```

## 4. Accessing the Dashboards

### Prometheus (Debug)
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```
Visit: http://localhost:9090

### Grafana (Visuals)
```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
```
Visit: http://localhost:3001
*   **User:** admin
*   **Password:** admin

## 5. Connect Grafana to Prometheus
1.  Log in to Grafana.
2.  Go to **Configuration** -> **Data Sources**.
3.  Click **Add data source** and select **Prometheus**.
4.  In the URL field, enter: `http://prometheus:9090`
5.  Click **Save & Test**.

## 6. Import Dashboards
1.  Go to **Dashboards** -> **Import**.
2.  Enter ID `315` (Kubernetes Cluster Monitoring) or `6417` (Kubernetes Pods).
3.  Click **Load** and select the Prometheus data source.
