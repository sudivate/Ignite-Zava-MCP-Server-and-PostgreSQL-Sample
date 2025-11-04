#!/bin/bash
set -e

# Configuration
RESOURCE_GROUP="zava-shop-rg"
MANAGED_IDENTITY_NAME="zava-shop-identity"
AKS_CLUSTER_NAME="zava-shop-aks"
K8S_NAMESPACE="zava-shop"
K8S_SERVICE_ACCOUNT="zava-shop-sa"

# Azure OpenAI Configuration
# You need to specify your Azure OpenAI resource details
OPENAI_RESOURCE_GROUP="rg-ignite"  # Change this to your Azure OpenAI resource group
OPENAI_RESOURCE_NAME="aoai-awe7fqhdxceck"  # Change this to your Azure OpenAI resource name

echo "==========================================="
echo "Step 2: Setting up Permissions"
echo "==========================================="

# Get Managed Identity Client ID
echo ""
echo "Getting managed identity details..."
CLIENT_ID=$(az identity show \
  --resource-group $RESOURCE_GROUP \
  --name $MANAGED_IDENTITY_NAME \
  --query clientId -o tsv)

echo "Managed Identity Client ID: $CLIENT_ID"

# Get OIDC Issuer URL
echo ""
echo "Getting OIDC Issuer URL..."
OIDC_ISSUER=$(az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)

echo "OIDC Issuer URL: $OIDC_ISSUER"

# Grant Cognitive Services OpenAI User role to the managed identity
echo ""
echo "Granting 'Cognitive Services OpenAI User' role to managed identity..."
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
OPENAI_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$OPENAI_RESOURCE_GROUP/providers/Microsoft.CognitiveServices/accounts/$OPENAI_RESOURCE_NAME"

az role assignment create \
  --assignee $CLIENT_ID \
  --role "Cognitive Services OpenAI User" \
  --scope $OPENAI_SCOPE

echo "Role assignment created successfully!"

# Create Federated Identity Credential
echo ""
echo "Creating federated identity credential..."
az identity federated-credential create \
  --name zava-shop-federated-credential \
  --identity-name $MANAGED_IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --issuer "$OIDC_ISSUER" \
  --subject "system:serviceaccount:$K8S_NAMESPACE:$K8S_SERVICE_ACCOUNT"

echo "Federated identity credential created successfully!"

echo ""
echo "==========================================="
echo "Permissions Setup Complete!"
echo "==========================================="
echo "Managed Identity Client ID: $CLIENT_ID"
echo "OpenAI Resource: $OPENAI_RESOURCE_NAME"
echo "Federated Credential: Linked to $K8S_NAMESPACE/$K8S_SERVICE_ACCOUNT"
echo ""
echo "Next: Update k8s/namespace.yaml with the Client ID annotation"
echo "Then run: 03-build-and-push-images.sh"
