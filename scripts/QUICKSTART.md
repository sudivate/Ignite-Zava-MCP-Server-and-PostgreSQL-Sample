# Quick Reference - Zava Shop Deployment

## One-Command Deployment
```bash
./scripts/deploy-all.sh
```

## Step-by-Step Deployment
```bash
# 1. Create infrastructure
./scripts/01-setup-infrastructure.sh

# 2. Setup permissions
./scripts/02-setup-permissions.sh

# 2b. Update namespace config (auto-populates client ID)
./scripts/02b-update-namespace-config.sh

# 3. Build and push images
./scripts/03-build-and-push-images.sh

# 4. Deploy to AKS
./scripts/04-deploy-to-aks.sh

# 5. Check status
./scripts/05-check-status.sh
```

## Before You Start

1. **Azure OpenAI Configuration** - Edit `scripts/02-setup-permissions.sh`:
   ```bash
   OPENAI_RESOURCE_GROUP="your-rg-name"
   OPENAI_RESOURCE_NAME="your-openai-resource-name"
   ```

2. **Kubernetes Secrets** - Edit `k8s/namespace.yaml` (base64 encoded):
   - AZURE_OPENAI_ENDPOINT_GPT5
   - AZURE_OPENAI_MODEL_DEPLOYMENT_NAME_GPT5
   - DEV_GUEST_TOKEN
   - APPLICATIONINSIGHTS_CONNECTION_STRING

## Common Commands

### Encode/Decode Base64
```bash
# Encode
echo -n "your-value" | base64

# Decode
echo "encoded-value" | base64 -d
```

### Check Deployment
```bash
kubectl get all -n zava-shop
kubectl get pods -n zava-shop
kubectl get svc -n zava-shop
```

### View Logs
```bash
kubectl logs -f deployment/api -n zava-shop
kubectl logs -f deployment/frontend -n zava-shop
kubectl logs -f deployment/finance-mcp -n zava-shop
kubectl logs -f deployment/supplier-mcp -n zava-shop
```

### Get Application URL
```bash
kubectl get svc frontend-service -n zava-shop
```

### Access Application
```
URL: http://<EXTERNAL-IP>
Username: admin
Password: admin123
```

### Troubleshooting
```bash
# Describe pod
kubectl describe pod <pod-name> -n zava-shop

# Check events
kubectl get events -n zava-shop --sort-by='.lastTimestamp'

# Restart deployment
kubectl rollout restart deployment/<deployment-name> -n zava-shop

# Check workload identity
kubectl get serviceaccount zava-shop-sa -n zava-shop -o yaml
```

### Scale Resources
```bash
# Scale deployment
kubectl scale deployment api --replicas=2 -n zava-shop

# Check resource usage
kubectl top nodes
kubectl top pods -n zava-shop
```

### Cleanup
```bash
./scripts/99-cleanup.sh
```

## Architecture

```
┌─────────────────────────────────────────┐
│           LoadBalancer (Public IP)       │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│            Frontend (Vue.js)             │
│              Port: 80                    │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│          API Server (FastAPI)            │
│              Port: 8000                  │
│    (Azure OpenAI via Workload Identity) │
└────┬─────────────────────────────┬──────┘
     │                             │
┌────▼──────────────┐    ┌─────────▼────────────┐
│  Finance MCP      │    │  Supplier MCP        │
│   Port: 8002      │    │   Port: 8002         │
└────┬──────────────┘    └─────────┬────────────┘
     │                             │
     └──────────┬──────────────────┘
                │
┌───────────────▼─────────────────────────┐
│       PostgreSQL + pgvector             │
│            Port: 5432                   │
└─────────────────────────────────────────┘
```

## Workload Identity Flow

```
1. Pod → K8s Service Account (annotated with azure.workload.identity/client-id)
2. K8s → Azure AD Token (via OIDC)
3. DefaultAzureCredential → Token retrieval
4. API → Azure OpenAI (with token)
5. No API keys stored! ✅
```

## Script Organization

- `01-setup-infrastructure.sh` - Creates Azure resources
- `02-setup-permissions.sh` - Configures workload identity and RBAC
- `02b-update-namespace-config.sh` - Auto-updates client ID in namespace.yaml
- `03-build-and-push-images.sh` - Builds and pushes Docker images
- `04-deploy-to-aks.sh` - Deploys all Kubernetes resources
- `05-check-status.sh` - Checks deployment health
- `99-cleanup.sh` - Deletes all resources
- `deploy-all.sh` - Runs all scripts in sequence

## File Structure

```
scripts/
├── 01-setup-infrastructure.sh      # Azure resources
├── 02-setup-permissions.sh         # Workload identity
├── 02b-update-namespace-config.sh  # Config helper
├── 03-build-and-push-images.sh     # Docker images
├── 04-deploy-to-aks.sh             # K8s deployment
├── 05-check-status.sh              # Status check
├── 99-cleanup.sh                   # Cleanup
├── deploy-all.sh                   # Master script
├── README.md                       # Full documentation
├── CONFIG_TEMPLATE.md              # Configuration guide
└── QUICKSTART.md                   # This file

k8s/
├── namespace.yaml                  # Namespace + secrets
├── rbac.yaml                       # Service account
├── postgres.yaml                   # Database
├── finance-mcp.yaml                # Finance MCP
├── supplier-mcp.yaml               # Supplier MCP
├── api.yaml                        # API server
└── frontend.yaml                   # Frontend + LoadBalancer
```

## Tips

- Run scripts from workspace root: `./scripts/script-name.sh`
- Check `scripts/README.md` for detailed documentation
- Keep `CONFIG_TEMPLATE.md` for reference
- Each script can run independently
- Scripts include error handling and validation
- Backup files created before modifications

## Support

For issues or questions, check:
1. Script output for error messages
2. Pod logs: `kubectl logs <pod-name> -n zava-shop`
3. Events: `kubectl get events -n zava-shop`
4. README.md for troubleshooting section
