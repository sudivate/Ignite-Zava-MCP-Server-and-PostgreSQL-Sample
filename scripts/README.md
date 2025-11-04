# Zava Shop - Deployment Scripts

This directory contains scripts to deploy the Zava Shop application to Azure Kubernetes Service (AKS) with workload identity authentication.

## Prerequisites

- Azure CLI installed and logged in (`az login`)
- Docker installed and running
- kubectl installed
- Sufficient Azure subscription permissions to create resources
- An existing Azure OpenAI resource

## Configuration

Before running the scripts, update these values:

### In `02-setup-permissions.sh`:
```bash
OPENAI_RESOURCE_GROUP="rg-ignite"  # Your Azure OpenAI resource group
OPENAI_RESOURCE_NAME="aoai-awe7fqhdxceck"  # Your Azure OpenAI resource name
```

### In `k8s/namespace.yaml`:
After running script 02, update the service account annotation with your managed identity client ID:
```yaml
metadata:
  annotations:
    azure.workload.identity/client-id: "<CLIENT_ID_FROM_SCRIPT_02>"
```

Update the secrets section with your actual values:
- `AZURE_OPENAI_ENDPOINT_GPT5`
- `AZURE_OPENAI_MODEL_DEPLOYMENT_NAME_GPT5`
- `DEV_GUEST_TOKEN`
- `APPLICATIONINSIGHTS_CONNECTION_STRING`

## Additional Documentation

- **[00-START-HERE.md](00-START-HERE.md)** - Begin here for first-time setup
- **[QUICKSTART.md](QUICKSTART.md)** - Fast deployment guide (under 10 minutes)
- **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** - Pre-flight checklist
- **[CONFIG_TEMPLATE.md](CONFIG_TEMPLATE.md)** - Configuration reference
- **[DOMAIN_AND_HTTPS.md](DOMAIN_AND_HTTPS.md)** - Domain name and SSL setup guide

---

## Deployment Steps

### 1. Setup Infrastructure
Creates Azure resources (Resource Group, ACR, AKS, Managed Identity):
```bash
chmod +x scripts/*.sh
./scripts/01-setup-infrastructure.sh
```

**What it does:**
- Creates resource group `zava-shop-rg` in West US 2
- Creates Azure Container Registry
- Creates AKS cluster with 2 nodes (Standard_D2s_v3)
- Enables OIDC issuer and workload identity
- Creates managed identity for workload identity

**Duration:** ~15-20 minutes

### 2. Setup Permissions
Configures workload identity and Azure OpenAI access:
```bash
./scripts/02-setup-permissions.sh
```

**What it does:**
- Grants "Cognitive Services OpenAI User" role to managed identity
- Creates federated identity credential linking K8s service account to Azure identity
- Displays Client ID to update in namespace.yaml

**After this step:** Update `k8s/namespace.yaml` with the Client ID!

### 3. Build and Push Images
Builds Docker images and pushes to ACR:
```bash
./scripts/03-build-and-push-images.sh
```

**What it does:**
- Builds 4 Docker images:
  - Finance MCP Server
  - Supplier MCP Server
  - API Server
  - Frontend
- Pushes all images to Azure Container Registry

**Duration:** ~5-10 minutes

### 4. Deploy to AKS
Deploys all Kubernetes resources:
```bash
./scripts/04-deploy-to-aks.sh
```

**What it does:**
- Applies namespace and secrets
- Deploys PostgreSQL with persistent storage
- Deploys Finance and Supplier MCP servers
- Deploys API server
- Deploys Frontend with LoadBalancer
- Waits for all pods to be ready
- Displays application URL

**Duration:** ~5-10 minutes

### 5. Check Status
Verifies deployment health:
```bash
./scripts/05-check-status.sh
```

**What it shows:**
- Deployment status
- Pod status
- Service details
- Resource usage
- Application URL and accessibility

## Troubleshooting

### View Pod Logs
```bash
kubectl logs -f <pod-name> -n zava-shop
```

### Check Pod Details
```bash
kubectl describe pod <pod-name> -n zava-shop
```

### View All Resources
```bash
kubectl get all -n zava-shop
```

### Test API Health
```bash
EXTERNAL_IP=$(kubectl get svc frontend-service -n zava-shop -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$EXTERNAL_IP/api/health
```

### Common Issues

**Pods in CrashLoopBackOff:**
- Check logs: `kubectl logs <pod-name> -n zava-shop`
- Verify secrets in namespace.yaml are correct
- Ensure managed identity has proper permissions

**LoadBalancer IP not assigned:**
- Wait 2-5 minutes for Azure to provision public IP
- Check service: `kubectl get svc frontend-service -n zava-shop`

**Authentication errors:**
- Verify Client ID annotation in namespace.yaml
- Check federated credential: `az identity federated-credential list --identity-name zava-shop-identity -g zava-shop-rg`
- Ensure Azure OpenAI role assignment exists

## Cleanup

To delete all resources:
```bash
./scripts/99-cleanup.sh
```

**Warning:** This deletes the entire resource group and all contained resources!

## Architecture

### Components
- **PostgreSQL**: Database with pgvector extension
- **Finance MCP**: MCP server for finance operations
- **Supplier MCP**: MCP server for supplier operations
- **API**: FastAPI backend with Azure OpenAI integration
- **Frontend**: Vue.js frontend with Nginx

### Workload Identity Flow
1. Pod uses Kubernetes service account with annotation
2. K8s injects Azure identity token
3. DefaultAzureCredential retrieves token
4. Token used to authenticate with Azure OpenAI
5. No API keys stored in environment variables

## Default Credentials

- **Admin User**: `admin`
- **Admin Password**: `admin123`

## Resource Names

- Resource Group: `zava-shop-rg`
- ACR: `zavashopacr13487.azurecr.io`
- AKS Cluster: `zava-shop-aks`
- Namespace: `zava-shop`
- Managed Identity: `zava-shop-identity`

## Cost Considerations

**Estimated monthly cost (West US 2):**
- AKS (2 x Standard_D2s_v3): ~$140
- ACR Basic: ~$5
- Public IP: ~$3
- **Total: ~$148/month**

To minimize costs, delete resources when not in use with the cleanup script.
