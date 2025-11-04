# Configuration Template for Zava Shop Deployment

## Azure Configuration

### Resource Names (Optional - defaults are fine)
RESOURCE_GROUP="zava-shop-rg"
LOCATION="westus2"
ACR_NAME="zavashopacr13487"
AKS_CLUSTER_NAME="zava-shop-aks"
MANAGED_IDENTITY_NAME="zava-shop-identity"

### AKS Cluster Configuration
NODE_COUNT=2
NODE_SIZE="Standard_D2s_v3"  # 2 vCPU, 8 GB RAM

## Azure OpenAI Configuration (REQUIRED)

### Update these in scripts/02-setup-permissions.sh
OPENAI_RESOURCE_GROUP="rg-ignite"           # Your Azure OpenAI resource group
OPENAI_RESOURCE_NAME="aoai-awe7fqhdxceck"  # Your Azure OpenAI resource name

## Kubernetes Secrets (REQUIRED)

### Update these in k8s/namespace.yaml (must be base64 encoded)

# Azure OpenAI Endpoint (e.g., https://your-resource.openai.azure.com/)
# Encode: echo -n "https://your-resource.openai.azure.com/" | base64
AZURE_OPENAI_ENDPOINT_GPT5: "<base64-encoded-value>"

# Azure OpenAI Deployment Name (e.g., gpt-4)
# Encode: echo -n "gpt-4" | base64
AZURE_OPENAI_MODEL_DEPLOYMENT_NAME_GPT5: "<base64-encoded-value>"

# Development Guest Token (any secure random string)
# Encode: echo -n "your-secure-token-here" | base64
DEV_GUEST_TOKEN: "<base64-encoded-value>"

# Application Insights Connection String (optional, can be empty)
# Encode: echo -n "InstrumentationKey=..." | base64
APPLICATIONINSIGHTS_CONNECTION_STRING: "<base64-encoded-value>"

## Managed Identity Client ID

# This will be automatically updated by scripts/02b-update-namespace-config.sh
# Or manually update in k8s/namespace.yaml after running 02-setup-permissions.sh
azure.workload.identity/client-id: "<will-be-auto-populated>"

## Default Application Credentials

Username: admin
Password: admin123

## Cost Estimate (West US 2)

- AKS (2 x Standard_D2s_v3): ~$140/month
- ACR Basic: ~$5/month  
- Public IP: ~$3/month
- Total: ~$148/month

## Quick Start Steps

1. Update Azure OpenAI configuration in scripts/02-setup-permissions.sh
2. Update secrets in k8s/namespace.yaml (base64 encoded)
3. Run: ./scripts/deploy-all.sh
4. Or run scripts individually:
   - ./scripts/01-setup-infrastructure.sh
   - ./scripts/02-setup-permissions.sh
   - ./scripts/02b-update-namespace-config.sh
   - ./scripts/03-build-and-push-images.sh
   - ./scripts/04-deploy-to-aks.sh

## Helper Commands

# Encode a value to base64
echo -n "your-value-here" | base64

# Decode base64
echo "base64-encoded-value" | base64 -d

# Get managed identity client ID
az identity show --resource-group zava-shop-rg --name zava-shop-identity --query clientId -o tsv

# Get AKS credentials
az aks get-credentials --resource-group zava-shop-rg --name zava-shop-aks

# Check deployment status
kubectl get all -n zava-shop

# View logs
kubectl logs -f <pod-name> -n zava-shop

# Get LoadBalancer IP
kubectl get svc frontend-service -n zava-shop
