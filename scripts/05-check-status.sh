#!/bin/bash
set -e

# Configuration
RESOURCE_GROUP="zava-shop-rg"
AKS_CLUSTER_NAME="zava-shop-aks"
K8S_NAMESPACE="zava-shop"

echo "==========================================="
echo "Checking Deployment Status"
echo "==========================================="

# Get AKS credentials
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --overwrite-existing \
  --output none

echo ""
echo "=== Deployments ==="
kubectl get deployments -n $K8S_NAMESPACE

echo ""
echo "=== Pods ==="
kubectl get pods -n $K8S_NAMESPACE

echo ""
echo "=== Services ==="
kubectl get svc -n $K8S_NAMESPACE

echo ""
echo "=== Node Resource Usage ==="
kubectl top nodes 2>/dev/null || echo "Metrics server not available"

echo ""
echo "=== Pod Resource Usage ==="
kubectl top pods -n $K8S_NAMESPACE 2>/dev/null || echo "Metrics server not available"

# Get LoadBalancer IP
EXTERNAL_IP=$(kubectl get svc frontend-service -n $K8S_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$EXTERNAL_IP" ]; then
  echo ""
  echo "⚠️  LoadBalancer IP not yet assigned. Run this script again in a few minutes."
else
  echo ""
  echo "==========================================="
  echo "Application URL: http://$EXTERNAL_IP"
  echo "==========================================="
  
  # Test frontend accessibility
  echo ""
  echo "Testing frontend accessibility..."
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$EXTERNAL_IP || echo "000")
  
  if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Frontend is accessible (HTTP $HTTP_CODE)"
  else
    echo "⚠️  Frontend returned HTTP $HTTP_CODE"
  fi
fi
