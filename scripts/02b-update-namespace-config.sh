#!/bin/bash

# Helper script to update namespace.yaml with managed identity client ID

RESOURCE_GROUP="zava-shop-rg"
MANAGED_IDENTITY_NAME="zava-shop-identity"

echo "==========================================="
echo "Update Namespace Configuration Helper"
echo "==========================================="

# Get Client ID
echo ""
echo "Retrieving managed identity client ID..."
CLIENT_ID=$(az identity show \
  --resource-group $RESOURCE_GROUP \
  --name $MANAGED_IDENTITY_NAME \
  --query clientId -o tsv 2>/dev/null)

if [ -z "$CLIENT_ID" ]; then
  echo "❌ Error: Could not retrieve managed identity client ID"
  echo "Make sure you have run 01-setup-infrastructure.sh first"
  exit 1
fi

echo "✅ Client ID: $CLIENT_ID"

# Update namespace.yaml
NAMESPACE_FILE="k8s/namespace.yaml"

if [ ! -f "$NAMESPACE_FILE" ]; then
  echo "❌ Error: $NAMESPACE_FILE not found"
  exit 1
fi

echo ""
echo "Updating $NAMESPACE_FILE..."

# Create backup
cp $NAMESPACE_FILE ${NAMESPACE_FILE}.bak
echo "Created backup: ${NAMESPACE_FILE}.bak"

# Update the client ID annotation
sed -i "s/azure.workload.identity\/client-id: .*/azure.workload.identity\/client-id: $CLIENT_ID/" $NAMESPACE_FILE

echo ""
echo "==========================================="
echo "✅ Configuration Updated!"
echo "==========================================="
echo ""
echo "Updated: $NAMESPACE_FILE"
echo "Backup: ${NAMESPACE_FILE}.bak"
echo ""
echo "Please verify the following in $NAMESPACE_FILE:"
echo "  1. AZURE_OPENAI_ENDPOINT_GPT5 (base64 encoded)"
echo "  2. AZURE_OPENAI_MODEL_DEPLOYMENT_NAME_GPT5 (base64 encoded)"
echo "  3. DEV_GUEST_TOKEN (base64 encoded)"
echo "  4. APPLICATIONINSIGHTS_CONNECTION_STRING (base64 encoded)"
echo ""
echo "To encode values: echo -n 'your-value' | base64"
echo ""
echo "After verifying secrets, proceed with: ./scripts/03-build-and-push-images.sh"
