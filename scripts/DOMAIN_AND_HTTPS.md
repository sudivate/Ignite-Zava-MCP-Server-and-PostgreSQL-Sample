# Domain Name and HTTPS Setup Guide

This guide explains how to configure a custom domain name and HTTPS/SSL certificates for your Zava Shop deployment.

## 📋 Overview

Instead of accessing your application via `http://<IP-ADDRESS>`, you can set up:
- **Custom Domain:** `https://zavashop.yourdomain.com`
- **HTTPS/SSL:** Automatic SSL certificates from Let's Encrypt
- **Auto-renewal:** Certificates automatically renewed before expiration

## 🎯 Three Options for Domain + HTTPS

### Option 1: Automated Script (Recommended)
Use the provided script with your own domain:
```bash
./scripts/06-setup-domain-and-https.sh zavashop.yourdomain.com admin@yourdomain.com
```

### Option 2: Azure DNS + Application Gateway
Use Azure's managed services (more expensive but fully integrated).

### Option 3: External DNS + cert-manager
Use any DNS provider with Kubernetes ingress (most flexible).

---

## 🚀 Option 1: Automated Setup with Script

### Prerequisites
- Own domain name (e.g., `yourdomain.com`)
- Access to DNS management for your domain
- Application already deployed to AKS

### Step 1: Prepare Your Domain
Choose a subdomain for your application:
- `zavashop.yourdomain.com`
- `shop.yourdomain.com`
- `app.yourdomain.com`

### Step 2: Run the Setup Script
```bash
cd scripts
./06-setup-domain-and-https.sh zavashop.yourdomain.com admin@yourdomain.com
```

**What it does:**
1. Installs cert-manager (for SSL certificate management)
2. Installs NGINX Ingress Controller
3. Gets LoadBalancer IP for ingress
4. Pauses for you to configure DNS
5. Creates Let's Encrypt ClusterIssuer
6. Creates Ingress with TLS
7. Automatically requests SSL certificate

### Step 3: Configure DNS (During Script Pause)
The script will display an IP address. Go to your DNS provider and create an A record:

**Example for GoDaddy/Namecheap/CloudFlare:**
```
Type: A
Name: zavashop (or whatever subdomain you chose)
Value: <IP-ADDRESS-FROM-SCRIPT>
TTL: 300 seconds
```

**DNS Propagation:** Wait 5-15 minutes for DNS to propagate globally.

**Verify DNS:**
```bash
nslookup zavashop.yourdomain.com
# or
dig zavashop.yourdomain.com
```

### Step 4: Verify Setup
```bash
# Check certificate status
kubectl get certificate -n zava-shop

# Should show: READY = True
NAME                  READY   SECRET                AGE
zava-shop-tls-cert   True    zava-shop-tls-cert    5m

# Check ingress
kubectl get ingress -n zava-shop

# Test HTTPS
curl -I https://zavashop.yourdomain.com
```

### Step 5: Access Your Application
Open browser: `https://zavashop.yourdomain.com`

---

## 🔵 Option 2: Azure Application Gateway + Azure DNS

### Benefits
- Fully managed Azure service
- WAF (Web Application Firewall) included
- DDoS protection
- Azure-native certificate management

### Cost
- Application Gateway: ~$150-250/month
- Azure DNS: ~$0.50/million queries

### Setup Steps

#### 1. Create Azure DNS Zone
```bash
DOMAIN_NAME="yourdomain.com"
RESOURCE_GROUP="zava-shop-rg"

# Create DNS zone
az network dns zone create \
  --resource-group $RESOURCE_GROUP \
  --name $DOMAIN_NAME

# Get name servers
az network dns zone show \
  --resource-group $RESOURCE_GROUP \
  --name $DOMAIN_NAME \
  --query nameServers
```

#### 2. Update Domain Registrar
Point your domain to Azure name servers (from above output).

#### 3. Create DNS Record
```bash
SUBDOMAIN="zavashop"
INGRESS_IP="<your-ingress-ip>"

az network dns record-set a add-record \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DOMAIN_NAME \
  --record-set-name $SUBDOMAIN \
  --ipv4-address $INGRESS_IP
```

#### 4. Enable Application Gateway Ingress Controller
```bash
# Enable AGIC addon
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name zava-shop-aks \
  --addons ingress-appgw \
  --appgw-name zava-shop-appgw \
  --appgw-subnet-cidr "10.2.0.0/16"
```

#### 5. Configure TLS with Azure Key Vault
```bash
# Create Key Vault
az keyvault create \
  --name zava-shop-kv \
  --resource-group $RESOURCE_GROUP \
  --location westus2

# Import/Generate certificate
az keyvault certificate create \
  --vault-name zava-shop-kv \
  --name zava-shop-cert \
  --policy "$(az keyvault certificate get-default-policy)"
```

---

## 🟢 Option 3: External DNS Provider + cert-manager

### Popular DNS Providers
- **Cloudflare** (Recommended - free tier available)
- **Google Cloud DNS**
- **Route53 (AWS)**
- **Azure DNS**

### Setup with Cloudflare Example

#### 1. Install cert-manager
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
```

#### 2. Install NGINX Ingress
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml
```

#### 3. Get Ingress IP
```bash
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

#### 4. Configure Cloudflare DNS
- Login to Cloudflare
- Add A record: `zavashop` → `<ingress-ip>`
- Enable "Proxy" (orange cloud) for DDoS protection

#### 5. Create ClusterIssuer
```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

#### 6. Create Ingress with TLS
```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: zava-shop-ingress
  namespace: zava-shop
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - zavashop.yourdomain.com
    secretName: zava-shop-tls-cert
  rules:
  - host: zavashop.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
EOF
```

---

## 🔍 Verification & Troubleshooting

### Check Certificate Status
```bash
# View certificates
kubectl get certificate -n zava-shop

# Describe certificate (shows events)
kubectl describe certificate zava-shop-tls-cert -n zava-shop

# Check certificate ready status
kubectl get certificate zava-shop-tls-cert -n zava-shop -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Should output: True
```

### Check Ingress Status
```bash
# View ingress
kubectl get ingress -n zava-shop

# Describe ingress
kubectl describe ingress zava-shop-ingress -n zava-shop

# Check ingress address
kubectl get ingress zava-shop-ingress -n zava-shop -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Test SSL Certificate
```bash
# Test HTTPS connection
curl -v https://zavashop.yourdomain.com

# Check certificate details
openssl s_client -connect zavashop.yourdomain.com:443 -servername zavashop.yourdomain.com </dev/null

# Test with specific SSL labs
https://www.ssllabs.com/ssltest/analyze.html?d=zavashop.yourdomain.com
```

### Common Issues

#### Certificate Not Issued (Pending)
```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate request
kubectl get certificaterequest -n zava-shop

# Check order
kubectl get order -n zava-shop

# Check challenge
kubectl get challenge -n zava-shop
```

**Common causes:**
- DNS not propagated yet (wait 15 minutes)
- Wrong DNS configuration
- Firewall blocking port 80/443
- Let's Encrypt rate limit hit

#### Ingress Not Working
```bash
# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Check ingress controller service
kubectl get svc -n ingress-nginx

# Test from inside cluster
kubectl run test-pod --rm -it --image=curlimages/curl -n zava-shop -- sh
curl http://frontend-service.zava-shop.svc.cluster.local
```

#### DNS Not Resolving
```bash
# Check DNS propagation
dig zavashop.yourdomain.com

# Check from different DNS servers
dig @8.8.8.8 zavashop.yourdomain.com
dig @1.1.1.1 zavashop.yourdomain.com

# Wait longer - DNS can take up to 48 hours (usually 5-15 minutes)
```

---

## 💰 Cost Comparison

| Option | Monthly Cost | Complexity | Benefits |
|--------|-------------|------------|----------|
| **Option 1: NGINX + Let's Encrypt** | $0 (uses existing LoadBalancer ~$3) | Low | Free SSL, automatic renewal |
| **Option 2: Azure App Gateway** | ~$150-250 | Medium | WAF, DDoS protection, Azure-native |
| **Option 3: Cloudflare + cert-manager** | $0 (Cloudflare free tier) | Low | DDoS protection, CDN, analytics |

---

## 🔄 Certificate Auto-Renewal

### Let's Encrypt Certificates
- **Validity:** 90 days
- **Auto-renewal:** cert-manager renews 30 days before expiration
- **No action needed:** Fully automated

### Check Renewal Status
```bash
# Check certificate expiration
kubectl get certificate zava-shop-tls-cert -n zava-shop -o jsonpath='{.status.notAfter}'

# Check cert-manager logs for renewals
kubectl logs -n cert-manager -l app=cert-manager --since=24h | grep renew
```

---

## 🌐 Multiple Domains

To serve multiple domains:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: zava-shop-ingress
  namespace: zava-shop
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - zavashop.com
    - www.zavashop.com
    - shop.example.com
    secretName: zava-shop-tls-cert
  rules:
  - host: zavashop.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
  - host: www.zavashop.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
```

---

## 📊 Architecture Comparison

### Before (IP-based)
```
Internet → LoadBalancer (20.120.189.103) → Frontend Pod
```

### After (Domain + HTTPS)
```
Internet → DNS (zavashop.yourdomain.com)
        → NGINX Ingress Controller (LoadBalancer)
        → TLS Termination (Let's Encrypt cert)
        → Frontend Service
        → Frontend Pod
```

---

## ✅ Recommended Setup

**For Production:**
1. **Use Option 1** (NGINX + Let's Encrypt) - Cost-effective and reliable
2. **Configure DNS with your provider** (Cloudflare recommended for free DDoS)
3. **Enable HTTP → HTTPS redirect** (included in script)
4. **Monitor certificate renewal** (automated by cert-manager)

**For Enterprise:**
1. **Use Option 2** (Azure Application Gateway)
2. **Enable WAF rules**
3. **Configure Azure DNS**
4. **Integrate with Azure Key Vault**

---

## 🚀 Quick Start

```bash
# 1. Run the automated script
./scripts/06-setup-domain-and-https.sh zavashop.yourdomain.com your-email@domain.com

# 2. Configure DNS when prompted (create A record)

# 3. Wait for certificate issuance (2-5 minutes)

# 4. Access your app
open https://zavashop.yourdomain.com
```

That's it! Your application is now secured with HTTPS and accessible via a custom domain. 🎉
