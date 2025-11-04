#!/bin/bash
set -e

echo "==========================================="
echo "Zava Shop - Complete AKS Deployment"
echo "==========================================="
echo ""
echo "This script will:"
echo "  1. Create Azure infrastructure (RG, ACR, AKS, Managed Identity)"
echo "  2. Setup permissions and workload identity"
echo "  3. Build and push Docker images"
echo "  4. Deploy to AKS"
echo "  5. Display application URL"
echo ""
echo "Prerequisites:"
echo "  - Azure CLI logged in (az login)"
echo "  - Docker running"
echo "  - kubectl installed"
echo "  - Azure OpenAI resource details configured"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Step 1: Setup Infrastructure
echo ""
echo "========================================="
echo "STEP 1: Setting up Infrastructure"
echo "========================================="
./scripts/01-setup-infrastructure.sh

# Step 2: Setup Permissions
echo ""
echo "========================================="
echo "STEP 2: Setting up Permissions"
echo "========================================="
./scripts/02-setup-permissions.sh

# Step 2b: Update namespace configuration
echo ""
echo "========================================="
echo "STEP 2b: Updating Namespace Configuration"
echo "========================================="
./scripts/02b-update-namespace-config.sh

echo ""
echo "⚠️  IMPORTANT: Please verify the secrets in k8s/namespace.yaml"
echo ""
echo "Required secrets (must be base64 encoded):"
echo "  - AZURE_OPENAI_ENDPOINT_GPT5"
echo "  - AZURE_OPENAI_MODEL_DEPLOYMENT_NAME_GPT5"
echo "  - DEV_GUEST_TOKEN"
echo "  - APPLICATIONINSIGHTS_CONNECTION_STRING"
echo ""
read -p "Have you verified/updated the secrets? (yes/no): " SECRETS_CONFIRMED

if [ "$SECRETS_CONFIRMED" != "yes" ]; then
  echo ""
  echo "Please update the secrets in k8s/namespace.yaml and run:"
  echo "  ./scripts/03-build-and-push-images.sh"
  echo "  ./scripts/04-deploy-to-aks.sh"
  exit 0
fi

# Step 3: Build and Push Images
echo ""
echo "========================================="
echo "STEP 3: Building and Pushing Images"
echo "========================================="
./scripts/03-build-and-push-images.sh

# Step 4: Deploy to AKS
echo ""
echo "========================================="
echo "STEP 4: Deploying to AKS"
echo "========================================="
./scripts/04-deploy-to-aks.sh

# Step 5: Check Status
echo ""
echo "========================================="
echo "STEP 5: Final Status Check"
echo "========================================="
sleep 10
./scripts/05-check-status.sh

echo ""
echo "==========================================="
echo "🎉 Deployment Complete!"
echo "==========================================="
echo ""
echo "Useful commands:"
echo "  Check status: ./scripts/05-check-status.sh"
echo "  View logs: kubectl logs -f <pod-name> -n zava-shop"
echo "  Cleanup: ./scripts/99-cleanup.sh"
