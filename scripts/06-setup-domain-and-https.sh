#!/bin/bash
set -e

# Configuration
RESOURCE_GROUP="zava-shop-rg"
AKS_CLUSTER_NAME="zava-shop-aks"
K8S_NAMESPACE="zava-shop"
DOMAIN_NAME="$1"  # Pass your domain as argument, e.g., zavashop.yourdomain.com
EMAIL="$2"        # Email for Let's Encrypt certificate notifications

if [ -z "$DOMAIN_NAME" ] || [ -z "$EMAIL" ]; then
  echo "Usage: $0 <domain-name> <email>"
  echo "Example: $0 zavashop.yourdomain.com admin@yourdomain.com"
  exit 1
fi

echo "==========================================="
echo "Setting up Domain Name and HTTPS"
echo "==========================================="
echo "Domain: $DOMAIN_NAME"
echo "Email: $EMAIL"
echo ""

# Get AKS credentials
echo "Getting AKS credentials..."
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --overwrite-existing

# Install cert-manager for automatic SSL certificate management
echo ""
echo "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# Install NGINX Ingress Controller
echo ""
echo "Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

echo "Waiting for Ingress Controller to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller -n ingress-nginx --timeout=300s

# Get the LoadBalancer IP for the Ingress Controller
echo ""
echo "Getting Ingress Controller LoadBalancer IP..."
INGRESS_IP=""
while [ -z $INGRESS_IP ]; do
  echo "Waiting for LoadBalancer IP assignment..."
  INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  [ -z "$INGRESS_IP" ] && sleep 10
done

echo ""
echo "==========================================="
echo "⚠️  IMPORTANT: DNS Configuration Required"
echo "==========================================="
echo ""
echo "Ingress Controller IP: $INGRESS_IP"
echo ""
echo "Please create an A record in your DNS provider:"
echo "  Type: A"
echo "  Name: $(echo $DOMAIN_NAME | cut -d. -f1)"
echo "  Value: $INGRESS_IP"
echo "  TTL: 300 (or your preference)"
echo ""
echo "For example, if your domain is zavashop.yourdomain.com:"
echo "  Add an A record for 'zavashop' pointing to $INGRESS_IP"
echo ""
read -p "Press Enter after you've configured DNS (this may take 5-15 minutes to propagate)..."

# Create ClusterIssuer for Let's Encrypt
echo ""
echo "Creating Let's Encrypt ClusterIssuer..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $EMAIL
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Update frontend service to ClusterIP (no longer needs LoadBalancer)
echo ""
echo "Updating frontend service to ClusterIP..."
kubectl patch svc frontend-service -n $K8S_NAMESPACE -p '{"spec":{"type":"ClusterIP"}}'

# Create Ingress resource with TLS
echo ""
echo "Creating Ingress resource with TLS..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: zava-shop-ingress
  namespace: $K8S_NAMESPACE
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - $DOMAIN_NAME
    secretName: zava-shop-tls-cert
  rules:
  - host: $DOMAIN_NAME
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

echo ""
echo "Waiting for certificate to be issued..."
echo "This may take 2-5 minutes..."
sleep 30

# Check certificate status
kubectl get certificate -n $K8S_NAMESPACE

echo ""
echo "==========================================="
echo "✅ Setup Complete!"
echo "==========================================="
echo ""
echo "Domain: https://$DOMAIN_NAME"
echo "Ingress IP: $INGRESS_IP"
echo ""
echo "Check certificate status:"
echo "  kubectl get certificate -n $K8S_NAMESPACE"
echo "  kubectl describe certificate zava-shop-tls-cert -n $K8S_NAMESPACE"
echo ""
echo "Check Ingress status:"
echo "  kubectl get ingress -n $K8S_NAMESPACE"
echo ""
echo "Note: It may take a few minutes for the SSL certificate to be issued."
echo "Once ready, your application will be available at: https://$DOMAIN_NAME"
