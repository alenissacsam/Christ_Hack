const knowledge: { q: string[]; a: string }[] = [
  {
    q: ['face', 'selfie', 'liveness'],
    a: 'Face Check: Start camera, capture a frame, and submit. If the camera is blocked, allow permission in your browser. We never show your hash; it is computed locally and sent securely to the contract.'
  },
  {
    q: ['aadhaar', 'qr', 'scan'],
    a: 'Aadhaar: Use “Use Camera” to scan the QR. You will see a live preview and a green box when detected. Alternatively, upload a photo of the QR. We hash the QR text locally and submit to the contract with your proof.'
  },
  {
    q: ['income', 'document', 'annual'],
    a: 'Income: Upload your income document, enter amount, and submit. You may also paste/upload a verification code (optional).'
  },
  {
    q: ['wallet', 'connect', 'metamask', 'network', 'sepolia'],
    a: 'Connect your MetaMask on Ethereum Sepolia. If transactions are pending, check gas or network congestion. Make sure the correct chain and RPC are configured.'
  },
  {
    q: ['admin', 'role', 'access'],
    a: 'Admin Services are only available to wallets holding the DEFAULT_ADMIN_ROLE on the UserIdentityRegistry contract. If you believe you should have access, ask your administrator to grant the role.'
  },
  {
    q: ['error', 'failed', 'revert', 'wrong'],
    a: 'If an action fails, check: (1) your wallet is connected, (2) you are on Sepolia, (3) contract addresses are configured in Settings, (4) you have required roles/permissions.'
  },
]

export default knowledge
