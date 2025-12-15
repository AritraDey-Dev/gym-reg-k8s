# Ingress Setup for Gym-Reg-Backend

This directory contains the Ingress resource configuration for exposing the Gym-Reg-Backend services.

## Prerequisites

- A Kubernetes cluster (Kind, Minikube, or Cloud).
- An Ingress Controller installed.
  - **For Kind**:
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    ```

## Usage

1.  **Apply the Ingress Resource**:
    ```bash
    kubectl apply -f ingress.yaml
    ```

2.  **Verify Ingress**:
    ```bash
    kubectl get ingress
    ```
    - **Cloud**: Wait for the `ADDRESS` field to show an IP or DNS name.
    - **Local (Kind/Minikube)**: The `ADDRESS` might remain empty or show `localhost` depending on your setup. This is normal if you don't have a LoadBalancer.

## Accessing Services (Local vs Cloud)

### 1. Cloud / Managed Kubernetes
If you are on AWS, GCP, or Azure, the Ingress Controller will typically assign a LoadBalancer IP. Use that IP to access your services.

### 2. Local (Kind / Minikube)
**Do you need to port-forward?**
- **YES**, but you port-forward the **Ingress Controller**, NOT the individual services.

**Steps for Local Access:**

1.  **Find your Ingress Controller Service**:
    Usually in the `ingress-nginx` namespace.
    ```bash
    kubectl get svc -n ingress-nginx
    ```

2.  **Port-Forward the Controller**:
    Forward the controller's port 80 to your local port 8080 (or any free port).
    ```bash
    kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8000:80
    ```
    *(Note: Replace `ingress-nginx` and `ingress-nginx-controller` with your actual namespace and service name if different).*

3.  **Access via Browser**:
    Now you can access your app via `localhost:8080`:
    - **Frontend**: `http://localhost:8080/`
    - **Admin Panel**: `http://localhost:8080/admin`
    - **Backend**: `http://localhost:8080/api/main`
