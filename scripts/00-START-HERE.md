# 🚀 Zava Shop AKS Deployment - START HERE

Welcome! This guide will help you deploy the Zava Shop application to Azure Kubernetes Service with workload identity authentication.

## 📋 Quick Overview

**What you'll deploy:**
- Azure Kubernetes Service (AKS) cluster with 2 nodes
- Azure Container Registry (ACR) with 4 Docker images
- PostgreSQL database with pgvector extension
- Finance and Supplier MCP servers
- FastAPI backend with Azure OpenAI integration
- Vue.js frontend with LoadBalancer

**Deployment time:** ~30-45 minutes  
**Estimated cost:** ~$148/month (West US 2)

## 🎯 Choose Your Path

### Option 1: Automated (Recommended)
Run everything with one command:
```bash
./scripts/deploy-all.sh
```
The script will pause for you to verify secrets before continuing.

### Option 2: Step-by-Step
Run scripts individually for more control:
```bash
./scripts/01-setup-infrastructure.sh      # ~15-20 min
./scripts/02-setup-permissions.sh         # ~2-3 min
./scripts/02b-update-namespace-config.sh  # ~1 min
# Verify secrets in k8s/namespace.yaml
./scripts/03-build-and-push-images.sh     # ~5-10 min
./scripts/04-deploy-to-aks.sh             # ~5-10 min
./scripts/05-check-status.sh              # Anytime
```

## 📚 Documentation Files

| File | Purpose | When to Use |
|------|---------|-------------|
| **QUICKSTART.md** | Quick commands reference | During deployment |
| **README.md** | Complete documentation | For detailed info |
| **CONFIG_TEMPLATE.md** | Configuration guide | Before starting |
| **DEPLOYMENT_CHECKLIST.md** | Step-by-step checklist | During deployment |

## ⚙️ Before You Start (5 minutes)

### 1. Prerequisites Check
- [ ] Azure CLI installed: `az --version`
- [ ] Logged in: `az login`
- [ ] Docker running: `docker --version`
- [ ] kubectl installed: `kubectl version --client`

### 2. Azure OpenAI Configuration

**Edit `scripts/02-setup-permissions.sh`:**
```bash
OPENAI_RESOURCE_GROUP="rg-ignite"           # Your resource group
OPENAI_RESOURCE_NAME="aoai-awe7fqhdxceck"  # Your OpenAI resource
```

### 3. Kubernetes Secrets Configuration

**Edit `k8s/namespace.yaml` (values must be base64 encoded):**

```bash
# Encode values like this:
echo -n "https://your-resource.openai.azure.com/" | base64

# Required secrets:
- AZURE_OPENAI_ENDPOINT_GPT5
- AZURE_OPENAI_MODEL_DEPLOYMENT_NAME_GPT5
- DEV_GUEST_TOKEN (any secure random string)
- APPLICATIONINSIGHTS_CONNECTION_STRING (optional, can be empty)
```

**Note:** Script `02b-update-namespace-config.sh` will auto-populate the managed identity client ID.

## 🚀 Quick Start

### 1. Make scripts executable
```bash
chmod +x scripts/*.sh
```

### 2. Run deployment
```bash
./scripts/deploy-all.sh
```

### 3. Access your application
```bash
# Get URL
kubectl get svc frontend-service -n zava-shop

# Open in browser
http://<EXTERNAL-IP>

# Login
Username: admin
Password: admin123
```

## 📊 What Each Script Does

| Script | Duration | Purpose |
|--------|----------|---------|
| `01-setup-infrastructure.sh` | 15-20 min | Creates Azure resources (RG, ACR, AKS, Identity) |
| `02-setup-permissions.sh` | 2-3 min | Configures workload identity and RBAC |
| `02b-update-namespace-config.sh` | 1 min | Auto-updates client ID in namespace.yaml |
| `03-build-and-push-images.sh` | 5-10 min | Builds and pushes 4 Docker images |
| `04-deploy-to-aks.sh` | 5-10 min | Deploys all K8s resources |
| `05-check-status.sh` | Instant | Checks deployment health |
| `99-cleanup.sh` | 5-10 min | Deletes all resources |

## ✅ Success Indicators

Your deployment is successful when:
1. All 5 pods show `STATUS: Running` and `READY: 1/1`
2. Frontend service has an `EXTERNAL-IP`
3. Application loads at `http://<EXTERNAL-IP>`
4. Login works with admin/admin123
5. No authentication errors in logs

## 🔧 Common Commands

```bash
# Check deployment status
./scripts/05-check-status.sh

# View pod logs
kubectl logs -f deployment/api -n zava-shop

# Get application URL
kubectl get svc frontend-service -n zava-shop

# Restart a deployment
kubectl rollout restart deployment/api -n zava-shop

# Access Kubernetes dashboard
kubectl get all -n zava-shop
```

## 🐛 Troubleshooting

### Pods not starting?
```bash
# Check pod status
kubectl describe pod <pod-name> -n zava-shop

# View logs
kubectl logs <pod-name> -n zava-shop

# Check events
kubectl get events -n zava-shop --sort-by='.lastTimestamp'
```

### Authentication errors?
- Verify client ID matches in managed identity and service account
- Check role assignment: `az role assignment list --assignee <CLIENT_ID>`
- Ensure federated credential exists

### Can't access application?
- Wait 2-5 minutes for LoadBalancer IP assignment
- Check service: `kubectl get svc frontend-service -n zava-shop`
- Verify pods are running: `kubectl get pods -n zava-shop`

## 🧹 Cleanup

To remove all resources:
```bash
./scripts/99-cleanup.sh
```

**Warning:** This deletes the entire resource group and all resources!

## 📖 Next Steps

1. **First time?** → Start with `QUICKSTART.md`
2. **Need details?** → Read `README.md`
3. **Want checklist?** → Use `DEPLOYMENT_CHECKLIST.md`
4. **Configuration?** → See `CONFIG_TEMPLATE.md`

## 🏗️ Architecture

```
Internet → LoadBalancer → Frontend → API → MCP Servers → PostgreSQL
                                     ↓
                              Azure OpenAI
                            (via Workload Identity)
```

## 🔐 Security Features

- ✅ Workload identity (no API keys stored)
- ✅ Azure AD authentication for OpenAI
- ✅ Kubernetes secrets for sensitive data
- ✅ Service account with limited permissions
- ✅ Federated identity credentials

## 💰 Cost Management

**Estimated costs (West US 2):**
- AKS: ~$140/month
- ACR: ~$5/month
- IP: ~$3/month
- **Total: ~$148/month**

**To minimize costs:**
- Delete resources when not in use: `./scripts/99-cleanup.sh`
- Scale down: `kubectl scale deployment api --replicas=0 -n zava-shop`

## 📞 Support

For issues:
1. Check logs: `kubectl logs <pod-name> -n zava-shop`
2. Review events: `kubectl get events -n zava-shop`
3. Read troubleshooting section in `README.md`
4. Check `DEPLOYMENT_CHECKLIST.md` for common issues

## 🎉 Ready to Deploy?

```bash
# Set up everything with one command
./scripts/deploy-all.sh

# Or follow the step-by-step guide
open scripts/QUICKSTART.md
```

**Good luck with your deployment! 🚀**
