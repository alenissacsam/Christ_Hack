#!/usr/bin/env python3
"""
Blockchain Integration Module
Handles smart contract interactions for biometric verification system
"""

import json
import time
import requests
from typing import Dict, Optional, Any
from dataclasses import dataclass
import hashlib
import hmac
from utils import CryptoUtils
import os

@dataclass
class VerificationPayload:
    """Data structure for verification payload sent to smart contract"""
    user_id: str
    biometric_hash: str
    signature: str
    wallet_address: str
    timestamp: int
    verification_type: str = "face_voice_lipsync"
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "user_id": self.user_id,
            "biometric_hash": self.biometric_hash,
            "signature": self.signature,
            "wallet_address": self.wallet_address,
            "timestamp": self.timestamp,
            "verification_type": self.verification_type
        }
    
    def to_json(self) -> str:
        return json.dumps(self.to_dict(), indent=2)

class BlockchainIntegration:
    """Handles all blockchain and smart contract interactions"""
    
    def __init__(self, config: Dict[str, str] = None):
        """
        Initialize blockchain integration
        
        Args:
            config: Configuration dictionary with endpoints and keys
        """
        self.config = config or self._load_default_config()
        self.session = requests.Session()
        
        # Generate or load backend private key for signing
        self.backend_private_key = self._get_backend_private_key()
        
        # Set up session headers
        self.session.headers.update({
            'Content-Type': 'application/json',
            'User-Agent': 'BiometricVerification/1.0',
            'Accept': 'application/json'
        })
        
        # Add API key if provided
        if self.config.get('api_key'):
            self.session.headers['Authorization'] = f"Bearer {self.config['api_key']}"
    
    def _load_default_config(self) -> Dict[str, str]:
        """Load default configuration for blockchain integration"""
        return {
            # Your identity DApp backend endpoints
            'enrollment_endpoint': 'http://localhost:3000/api/biometric/enroll',
            'verification_endpoint': 'http://localhost:3000/api/biometric/verify',
            'contract_address': '0x742d35Cc6629C0532E3D60C1dcBfC62E2AaF0e19',  # Example
            'chain_id': '11155111',  # Sepolia testnet
            'network': 'sepolia',
            'gas_limit': '500000',
            'max_retries': 3,
            'timeout': 30,
            'api_key': None,  # Set via environment variable or config file
            'backend_private_key': None  # Will be generated if not provided
        }
    
    def _get_backend_private_key(self) -> str:
        """Get or generate backend private key for signing"""
        # Try to get from config first
        if self.config.get('backend_private_key'):
            return self.config['backend_private_key']
        
        # Try to get from environment variable
        env_key = os.getenv('BACKEND_PRIVATE_KEY')
        if env_key:
            return env_key
        
        # Generate a new key and save it (for demo purposes)
        print("⚠️ No backend private key found, generating a new one...")
        backend_key = CryptoUtils.create_backend_private_key()
        print(f"🔑 Generated backend private key: {backend_key[:10]}...")
        print("💡 In production, set BACKEND_PRIVATE_KEY environment variable")
        
        return backend_key
    
    def enroll_biometric(self, payload: VerificationPayload) -> Dict[str, Any]:
        """
        Send biometric enrollment data to smart contract
        
        Args:
            payload: Verification payload containing biometric data
            
        Returns:
            Response from smart contract
        """
        print(f"🔗 Enrolling biometric data for user: {payload.user_id}")
        
        try:
            # Generate Ethereum-compatible signature
            ethereum_signature = CryptoUtils.generate_ethereum_signature(
                payload.biometric_hash,
                payload.wallet_address,
                self.backend_private_key
            )
            
            # Prepare enrollment data
            enrollment_data = {
                **payload.to_dict(),
                'action': 'enroll',
                'contract_address': self.config['contract_address'],
                'chain_id': self.config['chain_id'],
                'gas_limit': self.config['gas_limit'],
                'ethereum_signature': ethereum_signature  # Add Ethereum signature
            }
            
            # Add HMAC signature for API security
            enrollment_data['api_signature'] = self._generate_api_signature(enrollment_data)
            
            print(f"📤 Sending enrollment to: {self.config['enrollment_endpoint']}")
            print(f"📋 Payload preview: {json.dumps({k: v[:16] + '...' if isinstance(v, str) and len(v) > 16 else v for k, v in enrollment_data.items()}, indent=2)}")
            
            # Send to backend
            response = self._make_request(
                'POST', 
                self.config['enrollment_endpoint'], 
                enrollment_data
            )
            
            if response and response.get('success'):
                print("✅ Biometric enrollment successful")
                return {
                    'success': True,
                    'transaction_hash': response.get('transaction_hash'),
                    'block_number': response.get('block_number'),
                    'gas_used': response.get('gas_used'),
                    'contract_address': self.config['contract_address']
                }
            else:
                print("❌ Biometric enrollment failed")
                return {
                    'success': False,
                    'error': response.get('error', 'Unknown error'),
                    'details': response
                }
                
        except Exception as e:
            print(f"💥 Enrollment error: {str(e)}")
            return {
                'success': False,
                'error': f"Enrollment failed: {str(e)}"
            }
    
    def verify_biometric(self, payload: VerificationPayload) -> Dict[str, Any]:
        """
        Send biometric verification data to smart contract
        
        Args:
            payload: Verification payload containing biometric data
            
        Returns:
            Response from smart contract verification
        """
        print(f"🔍 Verifying biometric data for user: {payload.user_id}")
        
        try:
            # Generate Ethereum-compatible signature
            ethereum_signature = CryptoUtils.generate_ethereum_signature(
                payload.biometric_hash,
                payload.wallet_address,
                self.backend_private_key
            )
            
            # Prepare verification data
            verification_data = {
                **payload.to_dict(),
                'action': 'verify',
                'contract_address': self.config['contract_address'],
                'chain_id': self.config['chain_id'],
                'gas_limit': self.config['gas_limit'],
                'ethereum_signature': ethereum_signature  # Add Ethereum signature
            }
            
            # Add HMAC signature for API security
            verification_data['api_signature'] = self._generate_api_signature(verification_data)
            
            print(f"📤 Sending verification to: {self.config['verification_endpoint']}")
            print(f"📋 Hash: {payload.biometric_hash[:16]}...")
            print(f"📋 Signature: {payload.signature[:32]}...")
            print(f"📋 Wallet: {payload.wallet_address}")
            
            # Send to backend
            response = self._make_request(
                'POST', 
                self.config['verification_endpoint'], 
                verification_data
            )
            
            if response and response.get('success'):
                verification_result = response.get('verification_result', False)
                print(f"✅ Verification result: {'PASS' if verification_result else 'FAIL'}")
                
                return {
                    'success': True,
                    'verified': verification_result,
                    'transaction_hash': response.get('transaction_hash'),
                    'block_number': response.get('block_number'),
                    'gas_used': response.get('gas_used'),
                    'confidence_score': response.get('confidence_score', 0.0),
                    'verification_timestamp': response.get('verification_timestamp')
                }
            else:
                print("❌ Biometric verification failed")
                return {
                    'success': False,
                    'verified': False,
                    'error': response.get('error', 'Unknown error'),
                    'details': response
                }
                
        except Exception as e:
            print(f"💥 Verification error: {str(e)}")
            return {
                'success': False,
                'verified': False,
                'error': f"Verification failed: {str(e)}"
            }
    
    def _make_request(self, method: str, url: str, data: Dict[str, Any] = None) -> Optional[Dict[str, Any]]:
        """
        Make HTTP request with retry logic
        
        Args:
            method: HTTP method (GET, POST, etc.)
            url: Request URL
            data: Request payload
            
        Returns:
            Response data or None if failed
        """
        for attempt in range(self.config['max_retries']):
            try:
                print(f"🌐 Attempt {attempt + 1}/{self.config['max_retries']}: {method} {url}")
                
                if method.upper() == 'POST':
                    response = self.session.post(
                        url, 
                        json=data, 
                        timeout=self.config['timeout']
                    )
                elif method.upper() == 'GET':
                    response = self.session.get(
                        url, 
                        params=data, 
                        timeout=self.config['timeout']
                    )
                else:
                    raise ValueError(f"Unsupported HTTP method: {method}")
                
                # Check response status
                response.raise_for_status()
                
                # Parse JSON response
                result = response.json()
                print(f"📨 Response status: {response.status_code}")
                return result
                
            except requests.exceptions.Timeout:
                print(f"⏰ Request timeout (attempt {attempt + 1})")
                if attempt < self.config['max_retries'] - 1:
                    time.sleep(2 ** attempt)  # Exponential backoff
                    
            except requests.exceptions.ConnectionError:
                print(f"🔌 Connection error (attempt {attempt + 1})")
                if attempt < self.config['max_retries'] - 1:
                    time.sleep(2 ** attempt)
                    
            except requests.exceptions.HTTPError as e:
                print(f"🚨 HTTP error: {e.response.status_code} - {e.response.text}")
                if e.response.status_code >= 500:  # Server error, retry
                    if attempt < self.config['max_retries'] - 1:
                        time.sleep(2 ** attempt)
                        continue
                break  # Client error, don't retry
                
            except Exception as e:
                print(f"💥 Request error: {str(e)}")
                break
        
        return None
    
    def _generate_api_signature(self, data: Dict[str, Any]) -> str:
        """
        Generate HMAC signature for API security
        
        Args:
            data: Data to sign
            
        Returns:
            HMAC signature
        """
        if not self.config.get('api_key'):
            return ""
        
        # Create canonical string from data
        canonical_data = json.dumps(data, sort_keys=True, separators=(',', ':'))
        
        # Generate HMAC signature
        signature = hmac.new(
            self.config['api_key'].encode(),
            canonical_data.encode(),
            hashlib.sha256
        ).hexdigest()
        
        return signature
    
    def get_verification_history(self, user_id: str) -> Dict[str, Any]:
        """
        Get verification history from blockchain
        
        Args:
            user_id: User identifier
            
        Returns:
            Verification history
        """
        try:
            history_endpoint = f"{self.config.get('base_url', 'http://localhost:3000')}/api/verification/history/{user_id}"
            response = self._make_request('GET', history_endpoint)
            
            if response:
                return {
                    'success': True,
                    'history': response.get('verifications', []),
                    'total_verifications': len(response.get('verifications', [])),
                    'success_rate': response.get('success_rate', 0.0)
                }
            else:
                return {
                    'success': False,
                    'error': 'Failed to fetch verification history'
                }
                
        except Exception as e:
            print(f"History fetch error: {str(e)}")
            return {
                'success': False,
                'error': f"History fetch failed: {str(e)}"
            }
    
    def validate_contract_state(self) -> Dict[str, Any]:
        """
        Validate smart contract state and connectivity
        
        Returns:
            Contract validation results
        """
        try:
            validate_endpoint = f"{self.config.get('base_url', 'http://localhost:3000')}/api/contract/validate"
            
            validation_data = {
                'contract_address': self.config['contract_address'],
                'chain_id': self.config['chain_id'],
                'network': self.config['network']
            }
            
            response = self._make_request('POST', validate_endpoint, validation_data)
            
            if response:
                return {
                    'success': True,
                    'contract_valid': response.get('valid', False),
                    'contract_balance': response.get('balance'),
                    'contract_owner': response.get('owner'),
                    'network_status': response.get('network_status'),
                    'gas_price': response.get('gas_price')
                }
            else:
                return {
                    'success': False,
                    'error': 'Contract validation failed'
                }
                
        except Exception as e:
            print(f"Contract validation error: {str(e)}")
            return {
                'success': False,
                'error': f"Contract validation failed: {str(e)}"
            }

# Convenience functions for integration with main verification system

def send_enrollment_to_blockchain(user_id: str, biometric_hash: str, signature: str, wallet_address: str) -> bool:
    """
    Convenience function to send enrollment data to blockchain
    
    Args:
        user_id: User identifier
        biometric_hash: SHA-256 hash of biometric data
        signature: Cryptographic signature
        wallet_address: User's wallet address
        
    Returns:
        Success status
    """
    blockchain = BlockchainIntegration()
    
    payload = VerificationPayload(
        user_id=user_id,
        biometric_hash=biometric_hash,
        signature=signature,
        wallet_address=wallet_address,
        timestamp=int(time.time())
    )
    
    result = blockchain.enroll_biometric(payload)
    return result.get('success', False)

def send_verification_to_blockchain(user_id: str, verification_hash: str, signature: str, wallet_address: str) -> Dict[str, Any]:
    """
    Convenience function to send verification data to blockchain
    
    Args:
        user_id: User identifier
        verification_hash: SHA-256 hash of verification data
        signature: Cryptographic signature
        wallet_address: User's wallet address
        
    Returns:
        Verification results
    """
    blockchain = BlockchainIntegration()
    
    payload = VerificationPayload(
        user_id=user_id,
        biometric_hash=verification_hash,
        signature=signature,
        wallet_address=wallet_address,
        timestamp=int(time.time())
    )
    
    return blockchain.verify_biometric(payload)

def test_blockchain_connectivity() -> bool:
    """
    Test blockchain connectivity and smart contract status
    
    Returns:
        Connection status
    """
    blockchain = BlockchainIntegration()
    result = blockchain.validate_contract_state()
    
    if result['success']:
        print("🔗 Blockchain connection: OK")
        print(f"📜 Contract address: {blockchain.config['contract_address']}")
        print(f"🌐 Network: {blockchain.config['network']}")
        print(f"✅ Contract valid: {result.get('contract_valid', False)}")
        return result.get('contract_valid', False)
    else:
        print("❌ Blockchain connection: FAILED")
        print(f"❌ Error: {result.get('error', 'Unknown error')}")
        return False

# Example usage and testing
if __name__ == "__main__":
    print("🧪 Testing Blockchain Integration")
    print("=" * 40)
    
    # Test connectivity
    if test_blockchain_connectivity():
        print("\n✅ Blockchain integration ready!")
        
        # Example enrollment test
        test_enrollment = send_enrollment_to_blockchain(
            user_id="test_user_123",
            biometric_hash="a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456",
            signature="dGVzdF9zaWduYXR1cmVfZXhhbXBsZQ==",
            wallet_address="0x742d35Cc6629C0532E3D60C1dcBfC62E2AaF0e19"
        )
        
        print(f"\n🧪 Test enrollment result: {'SUCCESS' if test_enrollment else 'FAILED'}")
    else:
        print("\n❌ Blockchain integration not available")
        print("💡 Make sure your identity DApp backend is running on localhost:3000")
        print("💡 Check the smart contract deployment and configuration")
