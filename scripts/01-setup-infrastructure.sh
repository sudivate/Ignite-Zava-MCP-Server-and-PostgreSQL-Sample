#!/bin/bash
set -e

# Configuration
RESOURCE_GROUP="zava-shop-rg"
LOCATION="westus2"
ACR_NAME="zavashopacr13487"
AKS_CLUSTER_NAME="zava-shop-aks"
NODE_COUNT=2
NODE_SIZE="Standard_D2s_v3"
MANAGED_IDENTITY_NAME="zava-shop-identity"

echo "==========================================="
echo "Step 1: Setting up Azure Infrastructure"
echo "==========================================="

# Create Resource Group
echo ""
echo "Creating resource group: $RESOURCE_GROUP in $LOCATION..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Azure Container Registry
echo ""
echo "Creating Azure Container Registry: $ACR_NAME..."
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --location $LOCATION

# Login to ACR
echo ""
echo "Logging in to Azure Container Registry..."
az acr login --name $ACR_NAME

# Create AKS Cluster with OIDC and Workload Identity enabled
echo ""
echo "Creating AKS cluster: $AKS_CLUSTER_NAME..."
echo "This may take 10-15 minutes..."
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --node-count $NODE_COUNT \
  --node-vm-size $NODE_SIZE \
  --generate-ssh-keys \
  --attach-acr $ACR_NAME \
  --enable-managed-identity \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --location $LOCATION

# Get AKS credentials
echo ""
echo "Getting AKS credentials..."
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --overwrite-existing

# Get OIDC Issuer URL
echo ""
echo "Retrieving OIDC Issuer URL..."
OIDC_ISSUER=$(az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)

echo "OIDC Issuer URL: $OIDC_ISSUER"

# Create Managed Identity
echo ""
echo "Creating managed identity: $MANAGED_IDENTITY_NAME..."
az identity create \
  --name $MANAGED_IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

# Get Managed Identity details
CLIENT_ID=$(az identity show \
  --resource-group $RESOURCE_GROUP \
  --name $MANAGED_IDENTITY_NAME \
  --query clientId -o tsv)

echo ""
echo "==========================================="
echo "Infrastructure Setup Complete!"
echo "==========================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "ACR Name: $ACR_NAME"
echo "AKS Cluster: $AKS_CLUSTER_NAME"
echo "Managed Identity: $MANAGED_IDENTITY_NAME"
echo "Client ID: $CLIENT_ID"
echo "OIDC Issuer: $OIDC_ISSUER"
echo ""
echo "Save these values for the next steps!"
