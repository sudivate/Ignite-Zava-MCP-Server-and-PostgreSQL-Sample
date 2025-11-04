#!/bin/bash
set -e

# Configuration
RESOURCE_GROUP="zava-shop-rg"
K8S_NAMESPACE="zava-shop"

echo "==========================================="
echo "⚠️  WARNING: This will delete all resources"
echo "==========================================="
echo ""
echo "Resources to be deleted:"
echo "  - Kubernetes namespace: $K8S_NAMESPACE (with all deployments)"
echo "  - Resource Group: $RESOURCE_GROUP (with AKS, ACR, Managed Identity)"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Cleanup cancelled."
  exit 0
fi

echo ""
echo "Deleting Kubernetes namespace..."
kubectl delete namespace $K8S_NAMESPACE --ignore-not-found=true

echo ""
echo "Deleting Azure Resource Group..."
echo "This may take several minutes..."
az group delete --name $RESOURCE_GROUP --yes --no-wait

echo ""
echo "==========================================="
echo "Cleanup Initiated"
echo "==========================================="
echo ""
echo "Resource group deletion is running in the background."
echo "Check status with: az group show --name $RESOURCE_GROUP"
