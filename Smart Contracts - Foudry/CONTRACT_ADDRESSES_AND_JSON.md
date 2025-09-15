# EduCert Contract Addresses & JSON Files

## 📋 Contract Addresses (To be set after deployment)

```javascript
const CONTRACT_ADDRESSES = {
  // Core System Contracts
  verificationLogger: "0x...", // VerificationLogger.json
  contractRegistry: "0x...",   // ContractRegistry.json
  systemToken: "0x...",        // SystemToken.json
  userIdentityRegistry: "0x...", // UserIdentityRegistry.json
  
  // Trust Score Contract
  trustScore: "0x...",         // TrustScore.json
  
  // Verification Contracts
  faceVerificationManager: "0x...", // FaceVerificationManager.json
  aadhaarVerificationManager: "0x...", // AadhaarVerificationManager.json
  incomeVerificationManager: "0x...", // IncomeVerificationManager.json
  offlineVerificationManager: "0x...", // OfflineVerificationManager.json
  
  // Organization Contracts
  certificateManager: "0x...", // CertificateManager.json
  recognitionManager: "0x...", // RecognitionManager.json
  
  // Account Abstraction Contracts
  eduCertEntryPoint: "0x...", // EduCertEntryPoint.json
  eduCertAccountFactory: "0x...", // EduCertAccountFactory.json
  eduCertModularAccount: "0x...", // EduCertModularAccount.json
  alchemyGasManager: "0x...", // AlchemyGasManager.json
  
  // Advanced Features
  guardianManager: "0x...", // GuardianManager.json
  aaWalletManager: "0x...", // AAWalletManager.json
  paymasterManager: "0x...", // PaymasterManager.json
  economicIncentives: "0x...", // EconomicIncentives.json
  
  // Governance Contracts
  governanceManager: "0x...", // GovernanceManager.json
  disputeResolution: "0x...", // DisputeResolution.json
  
  // Privacy & Cross-Chain
  privacyManager: "0x...", // PrivacyManager.json
  crossChainManager: "0x...", // CrossChainManager.json
  globalCredentialAnchor: "0x...", // GlobalCredentialAnchor.json
};
```

## 📁 Available JSON Files

All contract JSON files are available in the `frontend-contracts/` directory:

### Core System
- ✅ `VerificationLogger.json` - Central event logging
- ✅ `ContractRegistry.json` - Contract address registry
- ✅ `SystemToken.json` - Native token
- ✅ `UserIdentityRegistry.json` - User identity management

### Trust Score
- ✅ `TrustScore.json` - Trust score calculation

### Verification
- ✅ `FaceVerificationManager.json` - Face verification
- ✅ `AadhaarVerificationManager.json` - Aadhaar verification
- ✅ `IncomeVerificationManager.json` - Income verification
- ✅ `OfflineVerificationManager.json` - Offline verification

### Organization
- ✅ `CertificateManager.json` - Certificate issuance
- ✅ `RecognitionManager.json` - Badge & recognition

### Account Abstraction
- ✅ `EduCertEntryPoint.json` - ERC-4337 entry point
- ✅ `EduCertAccountFactory.json` - Account creation factory
- ✅ `EduCertModularAccount.json` - Smart account implementation
- ✅ `AlchemyGasManager.json` - Gas sponsorship manager

### Advanced Features
- ✅ `GuardianManager.json` - Account recovery
- ✅ `AAWalletManager.json` - Wallet management
- ✅ `PaymasterManager.json` - Payment processing
- ✅ `EconomicIncentives.json` - Reward system

### Governance
- ✅ `GovernanceManager.json` - Decentralized governance
- ✅ `DisputeResolution.json` - Dispute handling

### Privacy & Cross-Chain
- ✅ `PrivacyManager.json` - Privacy controls
- ✅ `CrossChainManager.json` - Cross-chain operations
- ✅ `GlobalCredentialAnchor.json` - Global credential hub

### Interfaces
- ✅ `IVerificationLogger.json` - Verification logger interface
- ✅ `ITrustScore.json` - Trust score interface
- ✅ `IUserIdentityRegistry.json` - User identity interface

## 🚀 Deployment Instructions

### 1. Set Environment Variables
```bash
# Create .env file with your values
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

### 2. Deploy Contracts
```bash
# Deploy to Sepolia testnet
forge script script/DeployEduCertCore.s.sol:DeployEduCertCore \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --slow
```

### 3. Update Contract Addresses
After deployment, update the contract addresses in your frontend application.

## 🔧 Frontend Integration

### Using Ethers.js
```javascript
import { ethers } from 'ethers';
import VerificationLogger from './contracts/VerificationLogger.json';
import TrustScore from './contracts/TrustScore.json';

const provider = new ethers.providers.JsonRpcProvider('YOUR_RPC_URL');
const verificationLogger = new ethers.Contract(
  CONTRACT_ADDRESSES.verificationLogger,
  VerificationLogger.abi,
  provider
);
```

### Using Web3.js
```javascript
import Web3 from 'web3';
import VerificationLogger from './contracts/VerificationLogger.json';

const web3 = new Web3('YOUR_RPC_URL');
const verificationLogger = new web3.eth.Contract(
  VerificationLogger.abi,
  CONTRACT_ADDRESSES.verificationLogger
);
```

## 📊 Network Information

### Sepolia Testnet
- **Chain ID**: 11155111
- **RPC URL**: https://sepolia.infura.io/v3/YOUR_PROJECT_ID
- **Explorer**: https://sepolia.etherscan.io/
- **LayerZero Endpoint**: 0x464570adA09869d8741132183721B4f0769a0287
- **ERC-4337 EntryPoint**: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789

## 🎯 Key Features

### Account Abstraction
- **Gasless Onboarding**: 2M gas allowance for new users
- **Session Keys**: Privacy-preserving dApp interactions
- **Trust Score Integration**: Higher trust = more gas sponsorship

### Identity Verification
- **Face Verification**: Biometric verification
- **Aadhaar Verification**: Government ID verification
- **Income Verification**: Income source verification
- **Offline Verification**: Works without internet

### Cross-Chain Support
- **LayerZero Integration**: Cross-chain messaging
- **Global Credentials**: Unified credential system
- **Multi-Chain**: Ethereum, Polygon, Arbitrum, Base

## 🚨 Important Notes

1. **Contract Addresses**: Set actual deployed addresses
2. **Network**: Ensure correct network connection
3. **Gas**: Account for gas costs
4. **Permissions**: Some functions require specific roles
5. **Upgrades**: Some contracts are upgradeable

## 📞 Support

For technical support:
- Check contract source code in `/src`
- Review deployment scripts in `/script`
- Check system architecture flowchart
- Contact development team

---

**Ready for deployment! 🚀**
