#!/bin/bash
set -e

# Configuration
ACR_NAME="zavashopacr13487"
ACR_LOGIN_SERVER="$ACR_NAME.azurecr.io"

echo "==========================================="
echo "Step 3: Building and Pushing Docker Images"
echo "==========================================="

# Login to ACR
echo ""
echo "Logging in to Azure Container Registry..."
az acr login --name $ACR_NAME

# Build and push Finance MCP Server
echo ""
echo "Building Finance MCP Server image..."
docker build \
  -f app/Dockerfile.financemcp \
  -t $ACR_LOGIN_SERVER/zava-finance-mcp:latest \
  ./app

echo "Pushing Finance MCP Server image..."
docker push $ACR_LOGIN_SERVER/zava-finance-mcp:latest

# Build and push Supplier MCP Server
echo ""
echo "Building Supplier MCP Server image..."
docker build \
  -f app/Dockerfile.mcp \
  -t $ACR_LOGIN_SERVER/zava-supplier-mcp:latest \
  ./app

echo "Pushing Supplier MCP Server image..."
docker push $ACR_LOGIN_SERVER/zava-supplier-mcp:latest

# Build and push API Server
echo ""
echo "Building API Server image..."
docker build \
  -f app/Dockerfile.api \
  -t $ACR_LOGIN_SERVER/zava-api:latest \
  ./app

echo "Pushing API Server image..."
docker push $ACR_LOGIN_SERVER/zava-api:latest

# Build and push Frontend
echo ""
echo "Building Frontend image..."
docker build \
  -f frontend/Dockerfile \
  -t $ACR_LOGIN_SERVER/zava-frontend:latest \
  ./frontend

echo "Pushing Frontend image..."
docker push $ACR_LOGIN_SERVER/zava-frontend:latest

echo ""
echo "==========================================="
echo "All Images Built and Pushed Successfully!"
echo "==========================================="
echo "Images in $ACR_LOGIN_SERVER:"
echo "  - zava-finance-mcp:latest"
echo "  - zava-supplier-mcp:latest"
echo "  - zava-api:latest"
echo "  - zava-frontend:latest"
echo ""
echo "Next: Run 04-deploy-to-aks.sh"
