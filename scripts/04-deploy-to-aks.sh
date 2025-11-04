#!/bin/bash
set -e

# Configuration
RESOURCE_GROUP="zava-shop-rg"
AKS_CLUSTER_NAME="zava-shop-aks"
K8S_NAMESPACE="zava-shop"

echo "==========================================="
echo "Step 4: Deploying to AKS"
echo "==========================================="

# Get AKS credentials
echo ""
echo "Getting AKS credentials..."
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --overwrite-existing

# Deploy Kubernetes resources in order
echo ""
echo "Deploying namespace and secrets..."
kubectl apply -f k8s/namespace.yaml

echo ""
echo "Deploying RBAC (Service Account)..."
kubectl apply -f k8s/rbac.yaml

echo ""
echo "Deploying PostgreSQL database..."
kubectl apply -f k8s/postgres.yaml

echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n $K8S_NAMESPACE --timeout=300s

echo ""
echo "Deploying Finance MCP Server..."
kubectl apply -f k8s/finance-mcp.yaml

echo ""
echo "Deploying Supplier MCP Server..."
kubectl apply -f k8s/supplier-mcp.yaml

echo "Waiting for MCP servers to be ready..."
kubectl wait --for=condition=ready pod -l component=mcp-server -n $K8S_NAMESPACE --timeout=300s

echo ""
echo "Deploying API Server..."
kubectl apply -f k8s/api.yaml

echo "Waiting for API to be ready..."
kubectl wait --for=condition=ready pod -l app=api -n $K8S_NAMESPACE --timeout=300s

echo ""
echo "Deploying Frontend..."
kubectl apply -f k8s/frontend.yaml

echo "Waiting for Frontend to be ready..."
kubectl wait --for=condition=ready pod -l app=frontend -n $K8S_NAMESPACE --timeout=300s

# Get LoadBalancer IP
echo ""
echo "Getting LoadBalancer external IP..."
echo "This may take a few minutes..."
EXTERNAL_IP=""
while [ -z $EXTERNAL_IP ]; do
  EXTERNAL_IP=$(kubectl get svc frontend-service -n $K8S_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  [ -z "$EXTERNAL_IP" ] && sleep 10
done

echo ""
echo "==========================================="
echo "Deployment Complete!"
echo "==========================================="
echo ""
echo "Deployment Status:"
kubectl get deployments -n $K8S_NAMESPACE
echo ""
echo "Pod Status:"
kubectl get pods -n $K8S_NAMESPACE
echo ""
echo "Services:"
kubectl get svc -n $K8S_NAMESPACE
echo ""
echo "==========================================="
echo "Application URL: http://$EXTERNAL_IP"
echo "==========================================="
echo ""
echo "Login credentials:"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo "To view logs: kubectl logs -f <pod-name> -n $K8S_NAMESPACE"
echo "To view pod status: kubectl get pods -n $K8S_NAMESPACE"
