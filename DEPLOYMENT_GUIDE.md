# EduCert System Deployment Guide

## Overview
This guide provides comprehensive instructions for deploying the EduCert smart contract system, including all necessary configurations and post-deployment setup.

## Prerequisites

### Environment Setup
1. **Foundry Installation**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Environment Variables**
   Create a `.env` file in the project root with the following variables:
   ```bash
   # Deployment Configuration
   PRIVATE_KEY=0x... # Deployer private key
   RPC_URL=https://... # Network RPC URL
   ETHERSCAN_API_KEY=... # For contract verification
   
   # Wallet Addresses (IMPORTANT: Use real addresses in production)
   COMMUNITY_WALLET=0x1000000000000000000000000000000000000001
   TEAM_WALLET=0x2000000000000000000000000000000000000002
   TREASURY_WALLET=0x3000000000000000000000000000000000000003
   ECOSYSTEM_WALLET=0x4000000000000000000000000000000000000004
   
   # External Dependencies
   LAYERZERO_ENDPOINT=0x3c2269811836af69497E5F486A85D7316753cf62 # Ethereum Mainnet
   WALLET_IMPLEMENTATION=0x5000000000000000000000000000000000000005
   ENTRY_POINT=0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789 # ERC-4337 EntryPoint v0.6
   ```

### Network-Specific Configurations

#### Ethereum Mainnet
```bash
LAYERZERO_ENDPOINT=0x3c2269811836af69497E5F486A85D7316753cf62
ENTRY_POINT=0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
```

#### Polygon Mainnet
```bash
LAYERZERO_ENDPOINT=0x3c2269811836af69497E5F486A85D7316753cf62
ENTRY_POINT=0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
```

#### Sepolia Testnet
```bash
LAYERZERO_ENDPOINT=0x464570adA09869d8741132183721B4f0769a0287
ENTRY_POINT=0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
```

## Deployment Process

### Step 1: Compile Contracts
```bash
forge clean
forge build
```

### Step 2: Deploy System Contracts
```bash
# Deploy to testnet first
forge script script/DeployEduCertSystem.s.sol:DeployEduCertSystem \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify \
    --slow

# For mainnet deployment, add additional flags:
# --legacy  # Use legacy transaction type if needed
# --gas-estimate-multiplier 120  # Add gas buffer
```

### Step 3: Post-Deployment Configuration
After deployment, run the configuration script to set up roles and integrations:

```bash
# Set deployed contract addresses in environment
export VERIFICATION_LOGGER_ADDRESS=0x...
export TRUST_SCORE_ADDRESS=0x...
# ... (set all contract addresses from deployment output)

# Run configuration script
forge script script/ConfigureEduCertSystem.s.sol:ConfigureEduCertSystem \
    --rpc-url $RPC_URL \
    --broadcast
```

## Deployed Contract Addresses Structure

The deployment script will output addresses in this format:

```
=== CORE SYSTEM CONTRACTS ===
VerificationLogger: 0x...
TrustScore: 0x...
UserIdentityRegistry: 0x...
ContractRegistry: 0x...
SystemToken: 0x...

=== VERIFICATION CONTRACTS ===
FaceVerificationManager: 0x...
AadhaarVerificationManager: 0x...
IncomeVerificationManager: 0x...

=== ORGANIZATION CONTRACTS ===
CertificateManager: 0x...
OrganizationRegistry: 0x...
RecognitionManager: 0x...

=== GOVERNANCE CONTRACTS ===
EconomicIncentives: 0x...
GovernanceManager: 0x...
DisputeResolution: 0x...

=== ADVANCED FEATURES ===
GuardianManager: 0x...
AAWalletManager: 0x...
PaymasterManager: 0x...
MigrationManager: 0x...

=== PRIVACY & CROSS-CHAIN ===
PrivacyManager: 0x...
CrossChainManager: 0x...
GlobalCredentialAnchor: 0x...
```

## Contract Architecture Overview

### Dependency Graph
```
VerificationLogger (Core logging)
├── TrustScore
├── UserIdentityRegistry
├── ContractRegistry
└── SystemToken

UserIdentityRegistry
├── FaceVerificationManager
├── AadhaarVerificationManager
└── IncomeVerificationManager

CertificateManager
└── OrganizationRegistry

TrustScore + VerificationLogger
├── RecognitionManager
├── EconomicIncentives
├── GovernanceManager
├── GuardianManager
├── DisputeResolution
└── AAWalletManager

Cross-Chain Integration
├── PrivacyManager
├── CrossChainManager
└── GlobalCredentialAnchor
```

## Post-Deployment Verification

### 1. Contract Verification
Verify all contracts are properly deployed and initialized:

```bash
# Check contract code is verified on Etherscan
# Verify proxy patterns are working correctly
cast call $VERIFICATION_LOGGER_ADDRESS "owner()(address)"
```

### 2. Role Assignment Verification
```bash
# Verify role assignments are correct
cast call $USER_REGISTRY_ADDRESS "hasRole(bytes32,address)(bool)" \
    $(cast keccak256 "REGISTRY_MANAGER_ROLE") $FACE_VERIFIER_ADDRESS
```

### 3. Integration Testing
```bash
# Test basic system functionality
cast send $USER_REGISTRY_ADDRESS "registerIdentity(address,bytes32)" \
    $TEST_USER_ADDRESS $TEST_COMMITMENT
```

## Security Considerations

### 1. Multi-Signature Setup
For production deployment, ensure all critical administrative roles are assigned to multi-signature wallets:

```solidity
// Example role assignments
grantRole(DEFAULT_ADMIN_ROLE, MULTISIG_WALLET);
grantRole(UPGRADER_ROLE, MULTISIG_WALLET);
grantRole(PAUSER_ROLE, EMERGENCY_MULTISIG);
```

### 2. Time-Locked Operations
Consider implementing time-locks for sensitive operations:
- Contract upgrades
- Role assignments
- Parameter changes

### 3. Emergency Procedures
Ensure emergency pause mechanisms are properly configured and tested.

## Monitoring and Maintenance

### 1. Event Monitoring
Set up monitoring for critical events:
- Contract upgrades
- Role changes
- Emergency pauses
- Large token transfers

### 2. Health Checks
Regular system health checks:
```bash
# Check contract versions
cast call $CONTRACT_REGISTRY_ADDRESS "getContractInfo(string)" "UserIdentityRegistry"

# Monitor system metrics
cast call $TRUST_SCORE_ADDRESS "getTotalUsers()(uint256)"
```

### 3. Upgrade Procedures
For contract upgrades:
1. Deploy new implementation
2. Test thoroughly on testnet
3. Propose upgrade through governance
4. Execute upgrade after timelock
5. Verify upgrade success

## Troubleshooting

### Common Issues

#### 1. Deployment Failures
```bash
# Check gas settings
forge script script/DeployEduCertSystem.s.sol --gas-estimate-multiplier 150

# Check nonce issues
cast nonce $DEPLOYER_ADDRESS --rpc-url $RPC_URL
```

#### 2. Initialization Failures
```bash
# Check proxy initialization
cast call $PROXY_ADDRESS "implementation()(address)"

# Verify initialization parameters
cast call $CONTRACT_ADDRESS "initialized()(bool)"
```

#### 3. Role Assignment Issues
```bash
# Check role hierarchy
cast call $CONTRACT_ADDRESS "getRoleAdmin(bytes32)(bytes32)" $ROLE_HASH

# Verify role assignments
cast call $CONTRACT_ADDRESS "hasRole(bytes32,address)(bool)" $ROLE_HASH $ADDRESS
```

## Gas Cost Estimates

Approximate gas costs for deployment (may vary by network):

| Contract Category | Estimated Gas |
|-------------------|---------------|
| Core Contracts | 8,000,000 |
| Verification Contracts | 6,000,000 |
| Organization Contracts | 7,000,000 |
| Governance Contracts | 5,000,000 |
| Advanced Features | 10,000,000 |
| Privacy & Cross-Chain | 4,000,000 |
| **Total** | **~40,000,000** |

## Support and Documentation

### Additional Resources
- Contract API Documentation: `docs/api/`
- Integration Examples: `examples/`
- Testing Guide: `test/README.md`
- Security Audit Reports: `audits/`

### Getting Help
- GitHub Issues: Submit technical issues
- Discord: Community support
- Documentation: Comprehensive guides and API references

## Conclusion

The EduCert system deployment involves multiple interconnected contracts with specific dependency requirements. Following this guide ensures proper deployment, configuration, and operation of the complete system.

Remember to:
1. Test thoroughly on testnet first
2. Use multi-signature wallets for administrative roles
3. Set up proper monitoring and alerting
4. Have emergency procedures ready
5. Keep detailed records of all deployments and configurations