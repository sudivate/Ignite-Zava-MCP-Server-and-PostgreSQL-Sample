#!/bin/bash

# Script to purchase Azure App Service Domain and configure DNS for Zava Shop
# This script helps you buy a domain directly through Azure and set up DNS

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Azure App Service Domain Setup${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Configuration
RESOURCE_GROUP="zava-shop-rg"
LOCATION="westus2"

# Check if domain name is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Domain name not provided${NC}"
    echo ""
    echo "Usage: $0 <desired-domain-name> [email]"
    echo ""
    echo "Example: $0 zavashop admin@example.com"
    echo ""
    echo -e "${YELLOW}Note: Do not include TLD (like .com). Script will check availability for common TLDs.${NC}"
    exit 1
fi

DOMAIN_BASE="$1"
CONTACT_EMAIL="${2:-admin@${DOMAIN_BASE}.com}"

echo -e "${YELLOW}Checking domain availability...${NC}"
echo ""

# Function to check domain availability
check_domain_availability() {
    local domain=$1
    echo -e "Checking: ${BLUE}${domain}${NC}"
    
    # Azure CLI doesn't have a direct command to check domain availability
    # We'll use the REST API approach
    result=$(az rest --method post \
        --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.DomainRegistration/checkDomainAvailability?api-version=2021-02-01" \
        --body "{\"name\":\"${domain}\"}" \
        --query "{available:available, domainType:domainType}" -o json 2>/dev/null || echo '{"available":false}')
    
    available=$(echo $result | grep -o '"available":[^,}]*' | cut -d':' -f2 | tr -d ' ')
    
    if [ "$available" == "true" ]; then
        echo -e "  ${GREEN}✓ Available${NC}"
        return 0
    else
        echo -e "  ${RED}✗ Not available${NC}"
        return 1
    fi
}

# Check availability for common TLDs
echo -e "${YELLOW}Checking availability for common domain extensions:${NC}"
echo ""

AVAILABLE_DOMAINS=()

for tld in "com" "net" "org" "io" "app"; do
    domain="${DOMAIN_BASE}.${tld}"
    if check_domain_availability "$domain"; then
        AVAILABLE_DOMAINS+=("$domain")
    fi
done

echo ""

if [ ${#AVAILABLE_DOMAINS[@]} -eq 0 ]; then
    echo -e "${RED}No available domains found for '${DOMAIN_BASE}'${NC}"
    echo -e "${YELLOW}Try a different name or check Azure Portal manually:${NC}"
    echo "https://portal.azure.com/#create/Microsoft.Domain"
    exit 1
fi

echo -e "${GREEN}Available domains:${NC}"
for i in "${!AVAILABLE_DOMAINS[@]}"; do
    echo "$((i+1)). ${AVAILABLE_DOMAINS[$i]}"
done
echo ""

# Prompt user to select domain
read -p "Select domain number (or 0 to exit): " selection

if [ "$selection" -eq 0 ] || [ "$selection" -gt "${#AVAILABLE_DOMAINS[@]}" ]; then
    echo -e "${YELLOW}Exiting...${NC}"
    exit 0
fi

SELECTED_DOMAIN="${AVAILABLE_DOMAINS[$((selection-1))]}"

echo ""
echo -e "${GREEN}Selected domain: ${SELECTED_DOMAIN}${NC}"
echo ""

# Show pricing information
echo -e "${YELLOW}Domain Pricing (approximate):${NC}"
echo "  .com domain: ~\$12-15/year"
echo "  .net domain: ~\$13-16/year"
echo "  .org domain: ~\$13-16/year"
echo "  .io domain: ~\$60-70/year"
echo "  .app domain: ~\$15-20/year"
echo ""
echo -e "${YELLOW}Note: You will be charged to your Azure subscription.${NC}"
echo ""

read -p "Continue with purchase? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}Purchase cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Purchasing Domain via Azure Portal${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

echo -e "${YELLOW}Unfortunately, Azure CLI does not support domain purchase directly.${NC}"
echo -e "${YELLOW}You need to complete the purchase through Azure Portal.${NC}"
echo ""
echo -e "${GREEN}Follow these steps:${NC}"
echo ""
echo "1. Open Azure Portal:"
echo "   https://portal.azure.com/#create/Microsoft.Domain"
echo ""
echo "2. Fill in the details:"
echo "   - Domain name: ${SELECTED_DOMAIN}"
echo "   - Resource group: ${RESOURCE_GROUP}"
echo "   - Contact email: ${CONTACT_EMAIL}"
echo ""
echo "3. Complete the purchase (takes 5-10 minutes)"
echo ""
echo "4. Return here and press Enter to continue with DNS setup..."
echo ""

read -p "Press Enter once domain purchase is complete..."

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Configuring DNS${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Wait for DNS zone to be created
echo -e "${YELLOW}Waiting for DNS zone to be created...${NC}"
sleep 10

# Check if DNS zone exists
DNS_ZONE_EXISTS=$(az network dns zone show --resource-group $RESOURCE_GROUP --name $SELECTED_DOMAIN 2>/dev/null || echo "")

if [ -z "$DNS_ZONE_EXISTS" ]; then
    echo -e "${RED}DNS zone not found. It may still be provisioning.${NC}"
    echo -e "${YELLOW}You can run the DNS configuration manually later:${NC}"
    echo ""
    echo "az network dns record-set a add-record \\"
    echo "  --resource-group $RESOURCE_GROUP \\"
    echo "  --zone-name $SELECTED_DOMAIN \\"
    echo "  --record-set-name \"@\" \\"
    echo "  --ipv4-address <YOUR-INGRESS-IP>"
    exit 0
fi

echo -e "${GREEN}DNS zone found!${NC}"
echo ""

# Get current frontend LoadBalancer IP or use ingress IP if available
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -z "$INGRESS_IP" ]; then
    # Try to get frontend service IP
    INGRESS_IP=$(kubectl get svc frontend-service -n zava-shop -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
fi

if [ -z "$INGRESS_IP" ]; then
    echo -e "${YELLOW}Could not automatically detect IP address.${NC}"
    read -p "Enter your LoadBalancer/Ingress IP address: " INGRESS_IP
fi

echo ""
echo -e "${YELLOW}Creating DNS A record...${NC}"
echo "  Domain: ${SELECTED_DOMAIN}"
echo "  IP: ${INGRESS_IP}"
echo ""

# Create A record for root domain
az network dns record-set a add-record \
  --resource-group $RESOURCE_GROUP \
  --zone-name $SELECTED_DOMAIN \
  --record-set-name "@" \
  --ipv4-address $INGRESS_IP

echo -e "${GREEN}✓ A record created for root domain${NC}"

# Create A record for www subdomain
az network dns record-set a add-record \
  --resource-group $RESOURCE_GROUP \
  --zone-name $SELECTED_DOMAIN \
  --record-set-name "www" \
  --ipv4-address $INGRESS_IP

echo -e "${GREEN}✓ A record created for www subdomain${NC}"
echo ""

# Show name servers
echo -e "${BLUE}DNS Name Servers:${NC}"
az network dns zone show \
  --resource-group $RESOURCE_GROUP \
  --name $SELECTED_DOMAIN \
  --query nameServers -o table

echo ""
echo -e "${GREEN}DNS configuration complete!${NC}"
echo ""

# Prompt to set up HTTPS
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Next Step: Set up HTTPS${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

read -p "Do you want to set up HTTPS with Let's Encrypt now? (yes/no): " setup_https

if [ "$setup_https" == "yes" ]; then
    echo ""
    echo -e "${YELLOW}Running HTTPS setup script...${NC}"
    echo ""
    
    # Check if script exists
    if [ -f "./06-setup-domain-and-https.sh" ]; then
        ./06-setup-domain-and-https.sh "$SELECTED_DOMAIN" "$CONTACT_EMAIL"
    else
        echo -e "${RED}HTTPS setup script not found.${NC}"
        echo -e "${YELLOW}Run manually:${NC}"
        echo "./scripts/06-setup-domain-and-https.sh $SELECTED_DOMAIN $CONTACT_EMAIL"
    fi
else
    echo ""
    echo -e "${YELLOW}You can set up HTTPS later by running:${NC}"
    echo "./scripts/06-setup-domain-and-https.sh $SELECTED_DOMAIN $CONTACT_EMAIL"
fi

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Setup Complete!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}Your domain is configured:${NC}"
echo "  Domain: ${SELECTED_DOMAIN}"
echo "  IP Address: ${INGRESS_IP}"
echo ""
echo -e "${YELLOW}DNS propagation may take 5-15 minutes.${NC}"
echo ""
echo "Test your domain:"
echo "  nslookup ${SELECTED_DOMAIN}"
echo "  curl http://${SELECTED_DOMAIN}"
echo ""
echo -e "${GREEN}After DNS propagates and HTTPS is set up:${NC}"
echo "  https://${SELECTED_DOMAIN}"
echo ""
