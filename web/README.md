# Christ Hack Web UI

A lightweight React + Vite frontend for the digital identity system. Connect a wallet and interact with:
- UserRegistry: register and upgrade verification
- OrganizationRegistry: register, verify orgs, issue and revoke certificates
- AuditLogger: browse audit logs

Quickstart
- Install Node.js 18+ and PNPM/NPM/Yarn.
- Copy environment template and fill addresses:
  cp .env.example .env
  # then edit .env with your deployed contract addresses
- Install deps and run dev server:
  npm install
  npm run dev

Environment variables
- VITE_DEFAULT_CHAIN_ID: target EVM chain ID (default 11155111 = Sepolia)
- VITE_RPC_URL: optional RPC URL; if unset, the injected wallet provider is used
- VITE_USER_REGISTRY_ADDRESS: deployed UserRegistry address
- VITE_ORG_REGISTRY_ADDRESS: deployed OrganizationRegistry address
- VITE_AUDIT_LOGGER_ADDRESS: deployed AuditLogger address

Notes
- Some actions require roles (e.g., verifyOrganization). Ensure your wallet has the required role in the contracts.
- hash inputs (faceHash, nationalIdHash, orgId, certId) must be 32-byte hex strings (0x-prefixed).
- You can further customize styling or add role management flows.

