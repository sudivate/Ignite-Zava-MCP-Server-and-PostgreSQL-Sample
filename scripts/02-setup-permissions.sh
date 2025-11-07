#!/bin/bash
set -e

# Configuration
RESOURCE_GROUP="zava-shop-rg"
MANAGED_IDENTITY_NAME="zava-shop-identity"
AKS_CLUSTER_NAME="zava-shop-aks"
K8S_NAMESPACE="zava-shop"
K8S_SERVICE_ACCOUNT="zava-shop-sa"

# Azure OpenAI / AI Foundry Configuration
# You need to specify your Azure OpenAI or AI Foundry resource details
OPENAI_RESOURCE_GROUP="zava-shop-rg"  # Resource group for Azure OpenAI or AI Foundry
OPENAI_RESOURCE_NAME="zava-shop-ai-foundry"  # Azure OpenAI or AI Foundry resource name

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

# Get the managed identity principal ID for role assignments
PRINCIPAL_ID=$(az identity show \
  --resource-group $RESOURCE_GROUP \
  --name $MANAGED_IDENTITY_NAME \
  --query principalId -o tsv)

echo "Managed Identity Principal ID: $PRINCIPAL_ID"

# Assign Cognitive Services OpenAI User role
az role assignment create \
  --assignee-object-id $PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Cognitive Services OpenAI User" \
  --scope $OPENAI_SCOPE

echo "Cognitive Services OpenAI User role assigned successfully!"

# Grant Cognitive Services OpenAI Contributor role for AI Foundry agent management
echo ""
echo "Granting 'Cognitive Services OpenAI Contributor' role to managed identity for AI Foundry..."
az role assignment create \
  --assignee-object-id $PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Cognitive Services OpenAI Contributor" \
  --scope $OPENAI_SCOPE

echo "Cognitive Services OpenAI Contributor role assigned successfully!"

# Create custom role for AI Foundry agent management
echo ""
echo "Creating custom role 'AI Foundry Agent Manager' for agent write permissions..."
CUSTOM_ROLE_DEF=$(cat <<EOF
{
  "Name": "AI Foundry Agent Manager - Zava Shop",
  "IsCustom": true,
  "Description": "Can create and manage AI Foundry agents",
  "Actions": [],
  "NotActions": [],
  "DataActions": [
    "Microsoft.CognitiveServices/accounts/AIServices/agents/*"
  ],
  "NotDataActions": [],
  "AssignableScopes": [
    "$OPENAI_SCOPE"
  ]
}
EOF
)

echo "$CUSTOM_ROLE_DEF" > /tmp/ai-foundry-agent-role.json

# Check if custom role already exists
CUSTOM_ROLE_ID=$(az role definition list --custom-role-only true --query "[?roleName=='AI Foundry Agent Manager - Zava Shop'].id" -o tsv)

if [ -z "$CUSTOM_ROLE_ID" ]; then
  echo "Creating new custom role..."
  CUSTOM_ROLE_RESULT=$(az role definition create --role-definition /tmp/ai-foundry-agent-role.json)
  CUSTOM_ROLE_ID=$(echo "$CUSTOM_ROLE_RESULT" | jq -r '.name')
  echo "Custom role created with ID: $CUSTOM_ROLE_ID"
else
  echo "Custom role already exists with ID: $CUSTOM_ROLE_ID"
fi

# Assign the custom role
echo "Assigning 'AI Foundry Agent Manager' role to managed identity..."
az role assignment create \
  --assignee-object-id $PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --role "$CUSTOM_ROLE_ID" \
  --scope $OPENAI_SCOPE

echo "AI Foundry Agent Manager role assigned successfully!"

# Cleanup temp file
rm -f /tmp/ai-foundry-agent-role.json

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
echo "Managed Identity Principal ID: $PRINCIPAL_ID"
echo "AI Foundry Resource: $OPENAI_RESOURCE_NAME"
echo "Federated Credential: Linked to $K8S_NAMESPACE/$K8S_SERVICE_ACCOUNT"
echo ""
echo "Assigned Roles:"
echo "  - Cognitive Services OpenAI User (read access)"
echo "  - Cognitive Services OpenAI Contributor (write access for OpenAI)"
echo "  - AI Foundry Agent Manager (custom - agent creation)"
echo ""
echo "Next: Update k8s/namespace.yaml with the Client ID annotation"
echo "Then run: 03-build-and-push-images.sh"
