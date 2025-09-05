# Identity Verification dApp (React + Vite + TypeScript)

This project scaffolds a full-featured frontend for your blockchain identity verification system using your provided contract ABIs.

Features
- Wallet connection (MetaMask, WalletConnect optional)
- Wizard-style verification flow (Face → Aadhaar → Income → ZK Proof)
- Real-time dashboard with profile status and live event feed
- Dynamic forms for all write methods from every ABI
- Admin area for organization/certificate/recognition management
- Tailwind CSS, dark mode, glassmorphism UI
- PWA (installable) with offline caching

Environment variables
Create a .env file in the project root and add:

VITE_RPC_SEPOLIA=
VITE_WALLETCONNECT_PROJECT_ID=
VITE_PINATA_JWT=
# or legacy keys
VITE_PINATA_API_KEY=
VITE_PINATA_API_SECRET=
VITE_PINATA_GATEWAY=gateway.pinata.cloud

Do NOT commit your .env file.

Prereqs
- Node.js >= 18
- A supported wallet (MetaMask) in the browser

Setup
1) Install dependencies
   npm install
   # or
   pnpm install
   # or
   yarn

2) Run the app
   npm run dev

3) Optional: enable WalletConnect
   Create a .env file in the project root and add:
   VITE_WALLETCONNECT_PROJECT_ID={{YOUR_WALLETCONNECT_PROJECT_ID}}

Where to provide contract addresses
- Go to Settings in the app and paste the deployed addresses for each contract.
- Chain ID can also be set there (e.g. 11155111 for Sepolia, 80002 for Polygon Amoy).

Replace/Update ABIs
- All ABIs are under src/abi/*.json
- Replace any file with your new ABI JSON
- Update imports if you rename files: see src/contracts/abis.ts

Detected Contracts and Key Methods (from your ABIs)
- UserIdentityRegistry
  - verifyFace(bytes32 _faceHash, bytes _proof)
  - verifyAadhaar(bytes32 _aadhaarHash, bytes _proof)
  - verifyIncome(bytes32 _incomeHash, bytes _proof, uint256 _annualIncome)
  - getUserProfile(address), getVerificationLevels(address)
- CertificateManager
  - issueCertificate(address, string, string, uint256, bool), revokeCertificate(uint256)
  - verifyCertificate(uint256), getActiveCertificates(address)
- OrganizationRegistry
  - registerOrganization(...), approveOrganization(uint256,bool)
  - getOrganization(id), getOrganizationByAddress(address)
- GlobalCredentialAnchor
  - anchorCredential(bytes32, string, string, uint8, uint256, string)
  - revokeCredential(uint256), getActiveCredentials(address)
- CrossChainManager
  - anchorCrossChain(uint256, string, string, bytes32)
  - addSupportedChain(string)
- RecognitionManager
  - addCountryRecognition(uint256, string, string), revokeCountryRecognition(uint256, string)
- VerificationLogger
  - logVerification(address, string, bool, string)
  - getUserLogsPaginated(address, uint256, uint256)

Verification Flow
- Face step: capture webcam image, compute SHA-256 hash client-side, submit verifyFace
- Aadhaar step: upload QR/document, compute hash, submit verifyAadhaar
- Income step: upload proof, compute hash, input income, submit verifyIncome
- ZK Proof step: lists all write functions that accept a proof-like bytes input

Security Notes
- No contract addresses are hardcoded.
- When an address is missing, UI prompts to set address in Settings.
- Proof bytes must be supplied as 0x-prefixed hex; generation is out-of-scope here.

Build
- npm run build
- npm run preview

Tech Stack
- Vite + React + TypeScript
- wagmi v2 + viem
- Tailwind CSS
- vite-plugin-pwa

