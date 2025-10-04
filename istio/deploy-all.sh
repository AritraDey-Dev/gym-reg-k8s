#!/bin/bash

set -e

echo "=========================================="
echo "Deploying Gym Registration System with Istio"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

# Check if istioctl is installed
if ! command -v istioctl &> /dev/null; then
    echo -e "${YELLOW}Warning: istioctl is not installed. You may need it for advanced operations.${NC}"
fi

echo -e "${GREEN}Step 1: Creating namespace with Istio injection enabled...${NC}"
kubectl apply -f namespace.yaml

echo -e "${GREEN}Step 2: Deploying MySQL...${NC}"
kubectl apply -f ../mysql/ -n gym-reg

echo -e "${GREEN}Step 3: Deploying Redis...${NC}"
kubectl apply -f ../redis/ -n gym-reg

echo -e "${GREEN}Step 4: Deploying Backend services...${NC}"
kubectl apply -f ../backend/ -n gym-reg

echo -e "${GREEN}Step 5: Deploying Frontend...${NC}"
kubectl apply -f ../frontend/ -n gym-reg

echo -e "${GREEN}Step 6: Deploying Admin Panel...${NC}"
kubectl apply -f ../admin-panel/ -n gym-reg

echo -e "${GREEN}Step 7: Deploying Istio Gateway...${NC}"
kubectl apply -f gateway.yaml

echo -e "${GREEN}Step 8: Deploying Virtual Services...${NC}"
kubectl apply -f virtualservice-frontend.yaml
kubectl apply -f virtualservice-admin.yaml
kubectl apply -f virtualservice-backend.yaml

echo -e "${GREEN}Step 9: Deploying Destination Rules...${NC}"
kubectl apply -f destinationrule-frontend.yaml
kubectl apply -f destinationrule-admin.yaml
kubectl apply -f destinationrule-backend.yaml
kubectl apply -f destinationrule-databases.yaml

echo -e "${GREEN}Step 10: Deploying Security Policies...${NC}"
kubectl apply -f peer-authentication.yaml
kubectl apply -f authorization-policy.yaml

echo -e "${GREEN}Step 11: Deploying Additional Configurations...${NC}"
kubectl apply -f sidecar.yaml
kubectl apply -f service-entry.yaml
kubectl apply -f telemetry.yaml

echo ""
echo -e "${GREEN}=========================================="
echo "Deployment Complete!"
echo "==========================================${NC}"

echo ""
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=mysql -n gym-reg --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=redis -n gym-reg --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=backend-main -n gym-reg --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=backend-stream -n gym-reg --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=frontend -n gym-reg --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=admin-panel -n gym-reg --timeout=120s || true

echo ""
echo -e "${GREEN}Checking pod status:${NC}"
kubectl get pods -n gym-reg

echo ""
echo -e "${GREEN}Getting Istio Ingress Gateway details:${NC}"
kubectl get svc istio-ingressgateway -n istio-system

echo ""
echo -e "${YELLOW}To access the application:${NC}"
INGRESS_HOST=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$INGRESS_HOST" ]; then
    INGRESS_HOST=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
fi
if [ -z "$INGRESS_HOST" ]; then
    echo -e "${YELLOW}LoadBalancer IP/Hostname not yet assigned. Use port-forward for testing:${NC}"
    echo "kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80"
else
    echo -e "Frontend: http://${INGRESS_HOST}/"
    echo -e "Admin Panel: http://${INGRESS_HOST}/admin"
    echo -e "Backend Main API: http://${INGRESS_HOST}/api/main"
    echo -e "Backend Stream API: http://${INGRESS_HOST}/api/stream"
fi

echo ""
echo -e "${YELLOW}To view Kiali dashboard:${NC}"
echo "istioctl dashboard kiali"

echo ""
echo -e "${GREEN}Deployment completed successfully!${NC}"
