# Deploying Zava Shop to Azure Kubernetes Service (AKS)

This guide provides instructions for deploying the Zava Shop application to Azure Kubernetes Service (AKS).

## Architecture Overview

The Zava Shop system consists of the following components:
- **Frontend**: Vue.js application served by Nginx
- **API Server**: FastAPI Python application
- **Finance MCP Server**: Model Context Protocol server for finance operations
- **Supplier MCP Server**: Model Context Protocol server for supplier operations
- **PostgreSQL Database**: Primary data store with pgvector extension

## Prerequisites

Before deploying to AKS, ensure you have:

1. **Azure CLI** installed and configured
   ```bash
   az --version
   az login
   ```

2. **kubectl** installed
   ```bash
   kubectl version --client
   ```

3. **Docker** installed and running
   ```bash
   docker --version
   ```

4. **Required Azure permissions**:
   - Contributor role on the subscription
   - Ability to create resource groups, AKS clusters, and ACR registries

## Environment Variables

Set the following environment variables before deployment:

```bash
# Required
export RESOURCE_GROUP="zava-shop-rg"
export AKS_CLUSTER="zava-shop-aks"
export ACR_NAME="zavashopacr"  # Must be globally unique
export LOCATION="eastus"

# Optional
export SUBSCRIPTION_ID="your-subscription-id"
```

## Secrets Configuration

Before deploying, update the secrets in `k8s/namespace.yaml`:

1. **Base64 encode your secrets**:
   ```bash
   echo -n "your-secret-value" | base64
   ```

2. **Update the following secrets**:
   - `DEV_GUEST_TOKEN`: Your guest token for development
   - `APPLICATIONINSIGHTS_CONNECTION_STRING`: Azure Application Insights connection string
   - `AZURE_OPENAI_ENDPOINT_GPT5`: Azure OpenAI endpoint
   - `AZURE_OPENAI_API_KEY_GPT5`: Azure OpenAI API key
   - `AZURE_OPENAI_MODEL_DEPLOYMENT_NAME_GPT5`: Model deployment name
   - `VITE_CHATKIT_DOMAIN_KEY`: ChatKit domain key
   - `POSTGRES_PASSWORD`: Change the default database password

## Quick Deployment

Use the automated deployment script:

```bash
./deploy-aks.sh
```

This script will:
1. Create Azure resources (Resource Group, ACR, AKS cluster)
2. Build and push Docker images to ACR
3. Deploy all components to AKS
4. Configure auto-scaling and resilience features

## Manual Deployment Steps

If you prefer manual deployment:

### 1. Create Azure Resources

```bash
# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Azure Container Registry
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Standard

# Create AKS cluster
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER \
  --node-count 3 \
  --node-vm-size Standard_D2s_v3 \
  --generate-ssh-keys \
  --attach-acr $ACR_NAME \
  --enable-managed-identity \
  --enable-addons monitoring
```

### 2. Build and Push Images

```bash
# Login to ACR
az acr login --name $ACR_NAME

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query "loginServer" --output tsv)

# Build and push images
docker build -f app/Dockerfile.financemcp -t $ACR_LOGIN_SERVER/zava-finance-mcp:latest ./app
docker push $ACR_LOGIN_SERVER/zava-finance-mcp:latest

docker build -f app/Dockerfile.mcp -t $ACR_LOGIN_SERVER/zava-supplier-mcp:latest ./app
docker push $ACR_LOGIN_SERVER/zava-supplier-mcp:latest

docker build -f app/Dockerfile.api -t $ACR_LOGIN_SERVER/zava-api:latest ./app
docker push $ACR_LOGIN_SERVER/zava-api:latest

docker build -f frontend/Dockerfile -t $ACR_LOGIN_SERVER/zava-frontend:latest ./frontend
docker push $ACR_LOGIN_SERVER/zava-frontend:latest
```

### 3. Update Kubernetes Manifests

Update the image references in the Kubernetes manifests to use your ACR:

```bash
sed -i "s|zava-finance-mcp:latest|$ACR_LOGIN_SERVER/zava-finance-mcp:latest|g" k8s/finance-mcp.yaml
sed -i "s|zava-supplier-mcp:latest|$ACR_LOGIN_SERVER/zava-supplier-mcp:latest|g" k8s/supplier-mcp.yaml
sed -i "s|zava-api:latest|$ACR_LOGIN_SERVER/zava-api:latest|g" k8s/api.yaml
sed -i "s|zava-frontend:latest|$ACR_LOGIN_SERVER/zava-frontend:latest|g" k8s/frontend.yaml
```

### 4. Deploy to AKS

```bash
# Get AKS credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER

# Deploy in order
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/finance-mcp.yaml
kubectl apply -f k8s/supplier-mcp.yaml
kubectl apply -f k8s/api.yaml
kubectl apply -f k8s/frontend.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/pdb.yaml
```

## Optional: Ingress Controller

For production deployments, install an ingress controller:

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Wait for controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Apply ingress configuration
kubectl apply -f k8s/ingress.yaml
```

## Accessing the Application

### Via LoadBalancer Service

Get the external IP:
```bash
kubectl get service frontend-service -n zava-shop
```

### Via Port Forwarding (for testing)

```bash
kubectl port-forward service/frontend-service 8080:80 -n zava-shop
```
Then access at: http://localhost:8080

### Via Ingress (if configured)

Update your domain DNS to point to the ingress controller's external IP, then access via your domain.

## Monitoring and Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n zava-shop
kubectl describe pod <pod-name> -n zava-shop
```

### View Logs
```bash
kubectl logs -f deployment/api -n zava-shop
kubectl logs -f deployment/finance-mcp -n zava-shop
kubectl logs -f deployment/supplier-mcp -n zava-shop
kubectl logs -f deployment/frontend -n zava-shop
```

### Check Services and Endpoints
```bash
kubectl get services -n zava-shop
kubectl get endpoints -n zava-shop
```

### Scale Deployments
```bash
kubectl scale deployment api --replicas=5 -n zava-shop
```

## Production Considerations

### Security
1. **Enable Pod Security Standards**:
   ```bash
   kubectl label --overwrite ns zava-shop pod-security.kubernetes.io/enforce=restricted
   ```

2. **Use Azure Key Vault for secrets**:
   - Install Azure Key Vault Provider for Secrets Store CSI Driver
   - Replace Kubernetes secrets with Key Vault references

3. **Enable Azure Active Directory integration**:
   ```bash
   az aks update -g $RESOURCE_GROUP -n $AKS_CLUSTER --enable-aad --aad-admin-group-object-ids <admin-group-id>
   ```

### Backup and Disaster Recovery
1. **Enable backup for AKS**:
   ```bash
   az aks enable-addons --addons azure-policy --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP
   ```

2. **Backup PostgreSQL data**:
   - Set up Azure Database for PostgreSQL instead of in-cluster deployment
   - Enable automated backups

### Monitoring
1. **Application Insights** is already configured
2. **Install Prometheus and Grafana**:
   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
   ```

## Cost Optimization

1. **Use spot instances for non-critical workloads**
2. **Enable cluster autoscaler**:
   ```bash
   az aks update \
     --resource-group $RESOURCE_GROUP \
     --name $AKS_CLUSTER \
     --enable-cluster-autoscaler \
     --min-count 1 \
     --max-count 10
   ```

3. **Right-size your resources** based on actual usage

## Cleanup

To delete all resources:

```bash
# Delete Kubernetes namespace (removes all app resources)
kubectl delete namespace zava-shop

# Delete Azure resources
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

## Troubleshooting Common Issues

### Image Pull Errors
- Ensure ACR is attached to AKS cluster
- Check image names and tags are correct

### Pod Startup Issues
- Check resource limits and requests
- Verify secrets are correctly base64 encoded
- Check environment variables

### Service Communication Issues
- Verify service names match deployment labels
- Check network policies if any are applied
- Ensure correct ports are configured

### Performance Issues
- Monitor resource usage with `kubectl top pods`
- Adjust HPA settings based on actual load
- Consider using larger VM sizes for nodes

For additional help, check the [Azure AKS documentation](https://docs.microsoft.com/en-us/azure/aks/).