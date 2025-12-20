#!/bin/bash

echo "Starting Policy Violation Test..."
echo "Cleaning up old test pods..."
kubectl delete pod test-hacker-db test-hacker-backend test-hacker-stream test-hacker-frontend --force --grace-period=0 2>/dev/null

echo ""
echo "1. Attempting to access MySQL from an unauthorized pod (should FAIL)..."
# Using nc -w 3 for 3 second timeout
kubectl run test-hacker-db --image=busybox --restart=Never --rm -it -- nc -w 3 -zv mysql 3306

echo ""
echo "2. Attempting to access Backend Main from an unauthorized pod (should FAIL)..."
# Using wget -T 3 for 3 second timeout
kubectl run test-hacker-backend --image=busybox --restart=Never --rm -it -- wget -T 3 -qO- http://backend-main:9084

echo ""
echo "3. Attempting to access Backend Stream from an unauthorized pod (should FAIL)..."
kubectl run test-hacker-stream --image=busybox --restart=Never --rm -it -- wget -T 3 -qO- http://backend-stream:9085

echo ""
echo "4. Attempting to access Frontend from an unauthorized pod (should FAIL)..."
kubectl run test-hacker-frontend --image=busybox --restart=Never --rm -it -- wget -T 3 -qO- http://frontend:3000

echo ""
echo "----------------------------------------------------------------"
echo "If you saw 'operation timed out', 'download timed out', or similar errors, the policies are WORKING."
echo "Check Hubble UI for RED flows from 'test-hacker-*' pods."
echo "----------------------------------------------------------------"
