#!/bin/bash

set -e

echo "=========================================="
echo "Cleaning up Gym Registration System"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

read -p "Are you sure you want to delete all resources? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo -e "${YELLOW}Deleting Istio configurations...${NC}"
kubectl delete -f telemetry.yaml 2>/dev/null || true
kubectl delete -f service-entry.yaml 2>/dev/null || true
kubectl delete -f sidecar.yaml 2>/dev/null || true
kubectl delete -f authorization-policy.yaml 2>/dev/null || true
kubectl delete -f peer-authentication.yaml 2>/dev/null || true
kubectl delete -f destinationrule-databases.yaml 2>/dev/null || true
kubectl delete -f destinationrule-backend.yaml 2>/dev/null || true
kubectl delete -f destinationrule-admin.yaml 2>/dev/null || true
kubectl delete -f destinationrule-frontend.yaml 2>/dev/null || true
kubectl delete -f virtualservice-backend.yaml 2>/dev/null || true
kubectl delete -f virtualservice-admin.yaml 2>/dev/null || true
kubectl delete -f virtualservice-frontend.yaml 2>/dev/null || true
kubectl delete -f gateway.yaml 2>/dev/null || true

echo -e "${YELLOW}Deleting namespace (this will delete all resources)...${NC}"
kubectl delete namespace gym-reg 2>/dev/null || true

echo -e "${GREEN}Cleanup completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Note: Istio itself is still installed. To remove Istio completely, run:${NC}"
echo "istioctl uninstall --purge -y"
echo "kubectl delete namespace istio-system"
