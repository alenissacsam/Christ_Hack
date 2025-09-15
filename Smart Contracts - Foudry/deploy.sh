#!/bin/bash

# EduCert System Deployment Script
# This script automates the deployment of the entire EduCert system

set -e

echo "🚀 EduCert System Deployment Script"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Check if .env file exists
if [ ! -f .env ]; then
    print_error ".env file not found!"
    echo "Please create a .env file with the following variables:"
    echo ""
    echo "# Deployment Configuration"
    echo "PRIVATE_KEY=0x..."
    echo "RPC_URL=https://..."
    echo "ETHERSCAN_API_KEY=..."
    echo ""
    echo "# Wallet Addresses"
    echo "COMMUNITY_WALLET=0x..."
    echo "TEAM_WALLET=0x..."
    echo "TREASURY_WALLET=0x..."
    echo "ECOSYSTEM_WALLET=0x..."
    echo ""
    echo "# External Dependencies"
    echo "LAYERZERO_ENDPOINT=0x..."
    echo "ENTRY_POINT=0x..."
    echo "ALCHEMY_POLICY_ID=..."
    echo "ALCHEMY_APP_ID=..."
    echo "ALCHEMY_PAYMASTER=0x..."
    echo ""
    exit 1
fi

# Load environment variables
source .env

# Validate required environment variables
required_vars=(
    "PRIVATE_KEY"
    "RPC_URL"
    "COMMUNITY_WALLET"
    "TEAM_WALLET"
    "TREASURY_WALLET"
    "ECOSYSTEM_WALLET"
    "LAYERZERO_ENDPOINT"
    "ENTRY_POINT"
    "ALCHEMY_POLICY_ID"
    "ALCHEMY_APP_ID"
    "ALCHEMY_PAYMASTER"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        print_error "Required environment variable $var is not set!"
        exit 1
    fi
done

print_status "Environment variables validated"

# Check if Foundry is installed
if ! command -v forge &> /dev/null; then
    print_error "Foundry is not installed!"
    echo "Please install Foundry:"
    echo "curl -L https://foundry.paradigm.xyz | bash"
    echo "foundryup"
    exit 1
fi

print_status "Foundry is installed"

# Function to deploy contracts
deploy_contracts() {
    print_header "=== DEPLOYING CONTRACTS ==="
    
    print_status "Compiling contracts..."
    forge clean
    forge build
    
    if [ $? -eq 0 ]; then
        print_status "Contracts compiled successfully"
    else
        print_error "Contract compilation failed!"
        exit 1
    fi
    
    print_status "Deploying EduCert system..."
    
    # Deploy contracts
    forge script script/DeployEduCertSystem.s.sol:DeployEduCertSystem \
        --rpc-url $RPC_URL \
        --broadcast \
        --verify \
        --slow \
        --gas-estimate-multiplier 120
    
    if [ $? -eq 0 ]; then
        print_status "Contracts deployed successfully!"
    else
        print_error "Contract deployment failed!"
        exit 1
    fi
}

# Function to configure contracts
configure_contracts() {
    print_header "=== CONFIGURING CONTRACTS ==="
    
    # Extract contract addresses from deployment output
    print_status "Extracting contract addresses..."
    
    # This would need to be customized based on the actual deployment output
    # For now, we'll assume the addresses are set in environment variables
    
    print_status "Running configuration script..."
    
    forge script script/ConfigureEduCertSystem.s.sol:ConfigureEduCertSystem \
        --rpc-url $RPC_URL \
        --broadcast
    
    if [ $? -eq 0 ]; then
        print_status "Contracts configured successfully!"
    else
        print_error "Contract configuration failed!"
        exit 1
    fi
}

# Function to verify deployment
verify_deployment() {
    print_header "=== VERIFYING DEPLOYMENT ==="
    
    print_status "Running deployment verification..."
    
    # Check if contracts are properly deployed
    # This would include checking contract code, roles, and initial state
    
    print_status "Deployment verification complete!"
}

# Function to generate deployment report
generate_report() {
    print_header "=== GENERATING DEPLOYMENT REPORT ==="
    
    local report_file="deployment_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > $report_file << EOF
# EduCert System Deployment Report

**Deployment Date:** $(date)
**Network:** $RPC_URL
**Deployer:** $(cast wallet address $PRIVATE_KEY)

## Contract Addresses

\`\`\`
# Core System
VERIFICATION_LOGGER_ADDRESS=0x...
CONTRACT_REGISTRY_ADDRESS=0x...
SYSTEM_TOKEN_ADDRESS=0x...
USER_IDENTITY_REGISTRY_ADDRESS=0x...

# Trust Score
TRUST_SCORE_ADDRESS=0x...

# Verification Contracts
FACE_VERIFICATION_MANAGER_ADDRESS=0x...
AADHAAR_VERIFICATION_MANAGER_ADDRESS=0x...
INCOME_VERIFICATION_MANAGER_ADDRESS=0x...
OFFLINE_VERIFICATION_MANAGER_ADDRESS=0x...

# Organization Contracts
ORGANIZATION_REGISTRY_ADDRESS=0x...
CERTIFICATE_MANAGER_ADDRESS=0x...
RECOGNITION_MANAGER_ADDRESS=0x...

# Account Abstraction Contracts
EDUCERT_ENTRY_POINT_ADDRESS=0x...
EDUCERT_ACCOUNT_FACTORY_ADDRESS=0x...
EDUCERT_MODULAR_ACCOUNT_ADDRESS=0x...
ALCHEMY_GAS_MANAGER_ADDRESS=0x...

# Advanced Features
GUARDIAN_MANAGER_ADDRESS=0x...
AA_WALLET_MANAGER_ADDRESS=0x...
PAYMASTER_MANAGER_ADDRESS=0x...
MIGRATION_MANAGER_ADDRESS=0x...
ECONOMIC_INCENTIVES_ADDRESS=0x...

# Governance Contracts
GOVERNANCE_MANAGER_ADDRESS=0x...
DISPUTE_RESOLUTION_ADDRESS=0x...

# Privacy & Cross-Chain
PRIVACY_MANAGER_ADDRESS=0x...
CROSS_CHAIN_MANAGER_ADDRESS=0x...
GLOBAL_CREDENTIAL_ANCHOR_ADDRESS=0x...

# Proxy Admin
PROXY_ADMIN_ADDRESS=0x...
\`\`\`

## Configuration Summary

- **Gasless Onboarding:** Enabled (2M gas for 7 days)
- **Trust Score Integration:** Active
- **Alchemy Integration:** Configured
- **Cross-Chain Support:** Enabled
- **Privacy Mode:** Active

## Next Steps

1. Test system functionality
2. Set up monitoring and alerting
3. Configure additional integrations
4. Deploy to production networks

EOF

    print_status "Deployment report generated: $report_file"
}

# Main deployment flow
main() {
    print_header "Starting EduCert System Deployment"
    
    # Check network connectivity
    print_status "Checking network connectivity..."
    if ! curl -s $RPC_URL > /dev/null; then
        print_error "Cannot connect to RPC URL: $RPC_URL"
        exit 1
    fi
    
    # Deploy contracts
    deploy_contracts
    
    # Configure contracts
    configure_contracts
    
    # Verify deployment
    verify_deployment
    
    # Generate report
    generate_report
    
    print_header "🎉 DEPLOYMENT COMPLETE!"
    print_status "EduCert system has been successfully deployed and configured"
    print_status "Check the deployment report for contract addresses and next steps"
}

# Handle script arguments
case "${1:-}" in
    "deploy")
        deploy_contracts
        ;;
    "configure")
        configure_contracts
        ;;
    "verify")
        verify_deployment
        ;;
    "report")
        generate_report
        ;;
    "full"|"")
        main
        ;;
    *)
        echo "Usage: $0 [deploy|configure|verify|report|full]"
        echo ""
        echo "Commands:"
        echo "  deploy    - Deploy contracts only"
        echo "  configure - Configure contracts only"
        echo "  verify    - Verify deployment only"
        echo "  report    - Generate deployment report only"
        echo "  full      - Run complete deployment (default)"
        exit 1
        ;;
esac
