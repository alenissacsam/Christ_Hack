# 🚀 EduCert System Deployment Guide

This guide provides comprehensive instructions for deploying the entire EduCert smart contract system.

## 📋 Prerequisites

### 1. **Foundry Installation**
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. **Environment Setup**
```bash
# Copy the environment template
cp env.example .env

# Edit .env with your actual values
nano .env
```

### 3. **Required Environment Variables**
```bash
# Deployment Configuration
PRIVATE_KEY=your_private_key_here
RPC_URL=https://sepolia.infura.io/v3/your_project_id
ETHERSCAN_API_KEY=your_etherscan_api_key

# Wallet Addresses
COMMUNITY_WALLET=0x...
TEAM_WALLET=0x...
TREASURY_WALLET=0x...
ECOSYSTEM_WALLET=0x...

# External Dependencies
LAYERZERO_ENDPOINT=0x464570adA09869d8741132183721B4f0769a0287
ENTRY_POINT=0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789

# Alchemy Integration
ALCHEMY_POLICY_ID=your_alchemy_policy_id
ALCHEMY_APP_ID=your_alchemy_app_id
ALCHEMY_PAYMASTER=0x0000000071727De22E5E9d8BAf0edAc6f37da032
```

## 🏗️ Deployment Process

### **Option 1: Automated Deployment (Recommended)**
```bash
# Make the deployment script executable
chmod +x deploy.sh

# Run full deployment
./deploy.sh full

# Or run individual steps
./deploy.sh deploy      # Deploy contracts only
./deploy.sh configure   # Configure contracts only
./deploy.sh verify      # Verify deployment only
./deploy.sh report      # Generate report only
```

### **Option 2: Manual Deployment**
```bash
# Step 1: Compile contracts
forge clean
forge build

# Step 2: Deploy contracts
forge script script/DeployEduCertSystem.s.sol:DeployEduCertSystem \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify \
    --slow \
    --gas-estimate-multiplier 120

# Step 3: Configure contracts
forge script script/ConfigureEduCertSystem.s.sol:ConfigureEduCertSystem \
    --rpc-url $RPC_URL \
    --broadcast
```

## 📊 Contract Deployment Order

The deployment script follows this dependency order:

### **1. Core System Foundation**
- `VerificationLogger` - Central event logging
- `ContractRegistry` - Contract address registry
- `SystemToken` - Native token
- `UserIdentityRegistry` - User identity management
- `TrustScore` - Trust score calculation

### **2. Verification System**
- `FaceVerificationManager` - Face verification
- `AadhaarVerificationManager` - Aadhaar verification
- `IncomeVerificationManager` - Income verification
- `OfflineVerificationManager` - Offline verification

### **3. Organization System**
- `OrganizationRegistry` - Organization management
- `CertificateManager` - Certificate issuance (upgradeable)
- `RecognitionManager` - Badge & recognition

### **4. Account Abstraction System**
- `EduCertEntryPoint` - ERC-4337 entry point wrapper
- `EduCertModularAccount` - Smart account implementation
- `AlchemyGasManager` - Gas sponsorship (upgradeable)
- `EduCertAccountFactory` - Account creation factory

### **5. Advanced Features**
- `GuardianManager` - Account recovery
- `AAWalletManager` - Wallet management
- `PaymasterManager` - Payment processing
- `MigrationManager` - Account migration
- `EconomicIncentives` - Reward system

### **6. Governance System**
- `GovernanceManager` - Decentralized governance
- `DisputeResolution` - Dispute handling

### **7. Privacy & Cross-Chain**
- `PrivacyManager` - Privacy controls
- `CrossChainManager` - Cross-chain operations (upgradeable)
- `GlobalCredentialAnchor` - Global credential hub (upgradeable)

## 🔧 Post-Deployment Configuration

After deployment, the configuration script automatically:

### **Role Assignment**
- Grants `LOGGER_ROLE` to all contracts that need to log events
- Grants `SCORE_MANAGER_ROLE` to contracts that update trust scores
- Grants `REGISTRY_MANAGER_ROLE` to verification managers
- Grants `ISSUER_ROLE` to organization registry
- Grants `ADMIN_ROLE` to team wallet

### **System Parameters**
- Sets trust score thresholds for gasless transactions
- Configures Alchemy gas sponsorship rules
- Sets up onboarding gas allowance (2M gas for 7 days)
- Configures cross-chain parameters
- Sets up governance parameters

### **Token Distribution**
- Community: 40% of total supply
- Team: 20% of total supply
- Treasury: 25% of total supply
- Ecosystem: 15% of total supply

## 🌐 Network-Specific Configurations

### **Ethereum Mainnet**
```bash
RPC_URL=https://mainnet.infura.io/v3/your_project_id
LAYERZERO_ENDPOINT=0x3c2269811836af69497E5F486A85D7316753cf62
ETHERSCAN_API_KEY=your_etherscan_api_key
```

### **Polygon Mainnet**
```bash
RPC_URL=https://polygon-mainnet.infura.io/v3/your_project_id
LAYERZERO_ENDPOINT=0x3c2269811836af69497E5F486A85D7316753cf62
ETHERSCAN_API_KEY=your_polygonscan_api_key
```

### **Arbitrum Mainnet**
```bash
RPC_URL=https://arbitrum-mainnet.infura.io/v3/your_project_id
LAYERZERO_ENDPOINT=0x3c2269811836af69497E5F486A85D7316753cf62
ETHERSCAN_API_KEY=your_arbiscan_api_key
```

### **Base Mainnet**
```bash
RPC_URL=https://base-mainnet.infura.io/v3/your_project_id
LAYERZERO_ENDPOINT=0x3c2269811836af69497E5F486A85D7316753cf62
ETHERSCAN_API_KEY=your_basescan_api_key
```

### **Sepolia Testnet**
```bash
RPC_URL=https://sepolia.infura.io/v3/your_project_id
LAYERZERO_ENDPOINT=0x464570adA09869d8741132183721B4f0769a0287
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## 📈 Gas Cost Estimates

Approximate gas costs for deployment:

| Contract Category | Estimated Gas |
|-------------------|---------------|
| Core Contracts | 8,000,000 |
| Verification Contracts | 6,000,000 |
| Organization Contracts | 7,000,000 |
| Account Abstraction | 10,000,000 |
| Advanced Features | 8,000,000 |
| Governance Contracts | 5,000,000 |
| Privacy & Cross-Chain | 4,000,000 |
| **Total** | **~48,000,000** |

## 🔍 Verification Process

### **Contract Verification**
All contracts are automatically verified on Etherscan during deployment.

### **Manual Verification**
```bash
# Verify specific contract
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> \
    --chain-id <CHAIN_ID> \
    --etherscan-api-key $ETHERSCAN_API_KEY
```

### **Verification Checklist**
- [ ] All contracts deployed successfully
- [ ] All contracts verified on Etherscan
- [ ] Roles and permissions configured correctly
- [ ] Token distribution completed
- [ ] System parameters set correctly
- [ ] Alchemy integration configured
- [ ] Cross-chain settings configured

## 🧪 Testing Deployment

### **Basic Functionality Test**
```bash
# Test contract interactions
cast call $VERIFICATION_LOGGER_ADDRESS "getTotalLogs()(uint256)"
cast call $TRUST_SCORE_ADDRESS "getTotalUsers()(uint256)"
cast call $CONTRACT_REGISTRY_ADDRESS "getContractInfo(string)" "VerificationLogger"
```

### **Role Verification**
```bash
# Check role assignments
cast call $USER_REGISTRY_ADDRESS "hasRole(bytes32,address)(bool)" \
    $(cast keccak256 "REGISTRY_MANAGER_ROLE") $FACE_VERIFIER_ADDRESS
```

### **Integration Testing**
```bash
# Test basic system functionality
cast send $USER_REGISTRY_ADDRESS "registerIdentity(address,bytes32)" \
    $TEST_USER_ADDRESS $TEST_COMMITMENT
```

## 🚨 Troubleshooting

### **Common Issues**

#### **1. Deployment Failures**
```bash
# Check gas settings
forge script script/DeployEduCertSystem.s.sol --gas-estimate-multiplier 150

# Check nonce issues
cast nonce $DEPLOYER_ADDRESS --rpc-url $RPC_URL
```

#### **2. Initialization Failures**
```bash
# Check proxy initialization
cast call $PROXY_ADDRESS "implementation()(address)"

# Verify initialization parameters
cast call $CONTRACT_ADDRESS "initialized()(bool)"
```

#### **3. Role Assignment Issues**
```bash
# Check role hierarchy
cast call $CONTRACT_ADDRESS "getRoleAdmin(bytes32)(bytes32)" $ROLE_HASH

# Verify role assignments
cast call $CONTRACT_ADDRESS "hasRole(bytes32,address)(bool)" $ROLE_HASH $ADDRESS
```

### **Error Codes**
- `INVALID_ADDRESS`: Check address format and validity
- `ROLE_NOT_GRANTED`: Verify role assignments
- `INITIALIZATION_FAILED`: Check initialization parameters
- `GAS_LIMIT_EXCEEDED`: Increase gas limit or optimize contracts

## 📊 Monitoring & Maintenance

### **Health Checks**
```bash
# Check contract versions
cast call $CONTRACT_REGISTRY_ADDRESS "getContractInfo(string)" "UserIdentityRegistry"

# Monitor system metrics
cast call $TRUST_SCORE_ADDRESS "getTotalUsers()(uint256)"
cast call $VERIFICATION_LOGGER_ADDRESS "getTotalLogs()(uint256)"
```

### **Event Monitoring**
Set up monitoring for critical events:
- Contract upgrades
- Role changes
- Emergency pauses
- Large token transfers
- Trust score updates

### **Upgrade Procedures**
For contract upgrades:
1. Deploy new implementation
2. Test thoroughly on testnet
3. Propose upgrade through governance
4. Execute upgrade after timelock
5. Verify upgrade success

## 🔒 Security Considerations

### **Production Deployment**
- Use multi-signature wallets for administrative roles
- Implement time-locks for sensitive operations
- Set up emergency pause mechanisms
- Use hardware wallets for deployment keys

### **Access Control**
```solidity
// Example role assignments
grantRole(DEFAULT_ADMIN_ROLE, MULTISIG_WALLET);
grantRole(UPGRADER_ROLE, MULTISIG_WALLET);
grantRole(PAUSER_ROLE, EMERGENCY_MULTISIG);
```

### **Emergency Procedures**
- Emergency pause functionality
- Role revocation procedures
- Contract upgrade rollback
- Asset recovery mechanisms

## 📚 Additional Resources

### **Documentation**
- [Contract API Documentation](docs/api/)
- [Integration Examples](examples/)
- [Testing Guide](test/README.md)
- [Security Audit Reports](audits/)

### **Support**
- GitHub Issues: Submit technical issues
- Discord: Community support
- Documentation: Comprehensive guides and API references

## 🎉 Success Criteria

A successful deployment should have:

- ✅ All contracts deployed and verified
- ✅ All roles and permissions configured
- ✅ Token distribution completed
- ✅ System parameters set correctly
- ✅ Alchemy integration working
- ✅ Cross-chain functionality enabled
- ✅ Basic functionality tested
- ✅ Monitoring and alerting set up

---

**Ready to deploy? Run `./deploy.sh full` to start!** 🚀
