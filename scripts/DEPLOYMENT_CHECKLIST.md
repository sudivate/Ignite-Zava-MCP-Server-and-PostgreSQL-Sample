# Deployment Checklist

Use this checklist to ensure a successful deployment.

## Pre-Deployment Setup

### Prerequisites
- [ ] Azure CLI installed (`az --version`)
- [ ] Azure CLI logged in (`az login`)
- [ ] Docker installed and running (`docker --version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] Git repository cloned
- [ ] Terminal in workspace root directory

### Azure OpenAI Configuration
- [ ] Know your Azure OpenAI resource group name
- [ ] Know your Azure OpenAI resource name
- [ ] Have access to the Azure OpenAI resource
- [ ] Updated `scripts/02-setup-permissions.sh` with correct values:
  ```bash
  OPENAI_RESOURCE_GROUP="your-rg-name"
  OPENAI_RESOURCE_NAME="your-resource-name"
  ```

### Kubernetes Secrets Configuration
- [ ] Have Azure OpenAI endpoint URL
- [ ] Have Azure OpenAI model deployment name
- [ ] Generated secure token for DEV_GUEST_TOKEN
- [ ] (Optional) Application Insights connection string
- [ ] All values base64 encoded:
  ```bash
  echo -n "your-value" | base64
  ```
- [ ] Updated `k8s/namespace.yaml` with encoded secrets

## Deployment Steps

### Step 1: Infrastructure Setup (15-20 min)
- [ ] Run `./scripts/01-setup-infrastructure.sh`
- [ ] Script completed without errors
- [ ] Note the Client ID from output
- [ ] Note the OIDC Issuer URL from output
- [ ] Verify AKS cluster created: `az aks list -o table`
- [ ] Verify ACR created: `az acr list -o table`

### Step 2: Permissions Setup (2-3 min)
- [ ] Run `./scripts/02-setup-permissions.sh`
- [ ] Script completed without errors
- [ ] Federated credential created
- [ ] Role assignment created
- [ ] Note the Client ID displayed

### Step 2b: Update Namespace Config (1 min)
- [ ] Run `./scripts/02b-update-namespace-config.sh`
- [ ] Client ID automatically updated in namespace.yaml
- [ ] Backup file created (namespace.yaml.bak)
- [ ] Verify all secrets in namespace.yaml are correct:
  - [ ] AZURE_OPENAI_ENDPOINT_GPT5
  - [ ] AZURE_OPENAI_MODEL_DEPLOYMENT_NAME_GPT5
  - [ ] DEV_GUEST_TOKEN
  - [ ] APPLICATIONINSIGHTS_CONNECTION_STRING
- [ ] Verify client ID annotation is correct

### Step 3: Build and Push Images (5-10 min)
- [ ] Run `./scripts/03-build-and-push-images.sh`
- [ ] Finance MCP image built successfully
- [ ] Supplier MCP image built successfully
- [ ] API image built successfully
- [ ] Frontend image built successfully
- [ ] All images pushed to ACR
- [ ] Verify images in ACR: `az acr repository list -n zavashopacr13487 -o table`

### Step 4: Deploy to AKS (5-10 min)
- [ ] Run `./scripts/04-deploy-to-aks.sh`
- [ ] Namespace created
- [ ] PostgreSQL deployed and ready
- [ ] Finance MCP deployed and ready
- [ ] Supplier MCP deployed and ready
- [ ] API deployed and ready
- [ ] Frontend deployed and ready
- [ ] LoadBalancer IP assigned
- [ ] Application URL displayed

### Step 5: Verification
- [ ] Run `./scripts/05-check-status.sh`
- [ ] All deployments show READY: 1/1
- [ ] All pods show STATUS: Running
- [ ] Frontend service has EXTERNAL-IP
- [ ] HTTP check returns 200 status
- [ ] Access application URL: `http://<EXTERNAL-IP>`
- [ ] Login page loads
- [ ] Can login with admin/admin123
- [ ] Dashboard loads successfully

## Post-Deployment Testing

### Basic Functionality
- [ ] Frontend loads without errors
- [ ] Login works (admin/admin123)
- [ ] Customer dashboard accessible
- [ ] Management dashboard accessible
- [ ] Can view products
- [ ] Can view stores
- [ ] Chat interface loads

### Backend Health
- [ ] API health check: `curl http://<IP>/api/health`
- [ ] Check API logs: `kubectl logs deployment/api -n zava-shop`
- [ ] Check Frontend logs: `kubectl logs deployment/frontend -n zava-shop`
- [ ] Check MCP server logs:
  ```bash
  kubectl logs deployment/finance-mcp -n zava-shop
  kubectl logs deployment/supplier-mcp -n zava-shop
  ```

### Workload Identity Verification
- [ ] API pod has workload identity label
- [ ] Service account has correct annotation
- [ ] No API key errors in logs
- [ ] Azure OpenAI calls working
- [ ] Check pod identity: 
  ```bash
  kubectl get pod -l app=api -n zava-shop -o yaml | grep azure.workload.identity
  ```

## Resource Verification

### Azure Resources
```bash
# List all resources in resource group
az resource list -g zava-shop-rg -o table

# Verify AKS
az aks show -g zava-shop-rg -n zava-shop-aks --query "provisioningState"

# Verify ACR
az acr show -g zava-shop-rg -n zavashopacr13487 --query "provisioningState"

# Verify Managed Identity
az identity show -g zava-shop-rg -n zava-shop-identity --query "provisioningState"
```

### Kubernetes Resources
```bash
# All resources
kubectl get all -n zava-shop

# Pods
kubectl get pods -n zava-shop

# Services
kubectl get svc -n zava-shop

# Persistent volumes
kubectl get pvc -n zava-shop

# Service account
kubectl get sa zava-shop-sa -n zava-shop -o yaml
```

## Troubleshooting Checklist

If deployment fails, check:

### General Issues
- [ ] Check script error messages
- [ ] Verify Azure CLI is logged in: `az account show`
- [ ] Verify kubectl context: `kubectl config current-context`
- [ ] Check pod logs for specific errors

### Authentication Issues
- [ ] Verify Client ID matches in:
  - Managed identity
  - Service account annotation
  - Federated credential
- [ ] Verify role assignment exists:
  ```bash
  az role assignment list --assignee <CLIENT_ID> -o table
  ```
- [ ] Check Azure OpenAI resource permissions

### Image Issues
- [ ] Verify ACR login: `az acr login -n zavashopacr13487`
- [ ] Verify images exist: `az acr repository list -n zavashopacr13487`
- [ ] Check image pull errors in pod events

### Pod Issues
- [ ] Describe pod: `kubectl describe pod <pod-name> -n zava-shop`
- [ ] Check events: `kubectl get events -n zava-shop --sort-by='.lastTimestamp'`
- [ ] Verify secrets: `kubectl get secret zava-secrets -n zava-shop -o yaml`
- [ ] Check resource constraints: `kubectl top nodes`

### Network Issues
- [ ] Verify LoadBalancer IP assigned: `kubectl get svc frontend-service -n zava-shop`
- [ ] Check service endpoints: `kubectl get endpoints -n zava-shop`
- [ ] Test internal connectivity:
  ```bash
  kubectl run test-pod --rm -it --image=curlimages/curl -n zava-shop -- sh
  # Inside pod: curl http://api-service:8000/health
  ```

## Cleanup Checklist

When ready to remove all resources:

- [ ] Backup any important data
- [ ] Run `./scripts/99-cleanup.sh`
- [ ] Confirm deletion when prompted
- [ ] Wait for resource group deletion to complete
- [ ] Verify resources removed:
  ```bash
  az group show -n zava-shop-rg
  # Should return: ResourceGroupNotFound
  ```

## Notes

- Estimated deployment time: 30-45 minutes
- Estimated monthly cost: ~$148 (West US 2)
- All scripts have error handling
- Backups created before modifications
- Can run individual scripts if needed

## Success Criteria

Deployment is successful when:
1. ✅ All 5 pods are Running
2. ✅ LoadBalancer has external IP
3. ✅ Application accessible via browser
4. ✅ Login works with admin credentials
5. ✅ No authentication errors in logs
6. ✅ Workload identity configured correctly
7. ✅ Azure OpenAI calls working

## Quick Reference

```bash
# One command deployment
./scripts/deploy-all.sh

# Check status anytime
./scripts/05-check-status.sh

# View application
http://<EXTERNAL-IP>

# Cleanup everything
./scripts/99-cleanup.sh
```
