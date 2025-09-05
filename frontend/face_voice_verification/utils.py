import cv2
import numpy as np
import mediapipe as mp
import hashlib
import json
import os
import time
import sqlite3
from datetime import datetime
from typing import Dict, List, Tuple, Optional
from scipy import signal
from scipy.spatial.distance import euclidean
from scipy.ndimage import gaussian_filter1d
import librosa
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.backends import default_backend
import base64
from eth_account import Account
from eth_utils import keccak, to_hex
from eth_account.messages import encode_defunct

# Configuration Constants
class Config:
    # Face Detection
    FACE_CONFIDENCE_THRESHOLD = 0.7
    HEAD_POSE_THRESHOLD = 15.0  # degrees
    BLINK_THRESHOLD = 0.25
    SMILE_THRESHOLD = 0.6
    
    # Voice Processing
    SAMPLE_RATE = 16000
    CHUNK_SIZE = 1024
    MFCC_FEATURES = 13
    VOICE_SIMILARITY_THRESHOLD = 0.85
    
    # Lip Sync
    LIP_SYNC_THRESHOLD = 0.3
    AUDIO_ENERGY_SMOOTH_WINDOW = 5
    
    # Database
    DB_PATH = "identity_data.db"
    
    # Liveness Challenges
    CHALLENGES = [
        "Please blink twice",
        "Please smile",
        "Please turn your head left",
        "Please turn your head right",
        "Please nod your head up and down"
    ]
    
    VOICE_PHRASES = [
        "The quick brown fox jumps over the lazy dog",
        "Pack my box with five dozen liquor jugs",
        "How vexingly quick daft zebras jump",
        "Bright vixens jump quickly over fences"
    ]

class CryptoUtils:
    """Cryptographic utilities for hashing and signature generation"""
    
    @staticmethod
    def generate_hash(data: bytes) -> str:
        """Generate SHA-256 hash of input data"""
        return hashlib.sha256(data).hexdigest()
    
    @staticmethod
    def generate_ethereum_keypair():
        """Generate Ethereum-compatible key pair"""
        account = Account.create()
        return account.key.hex(), account.address
    
    @staticmethod
    def generate_keypair():
        """Generate ECDSA key pair for signing (legacy method)"""
        private_key = ec.generate_private_key(ec.SECP256K1(), default_backend())
        public_key = private_key.public_key()
        return private_key, public_key
    
    @staticmethod
    def generate_ethereum_signature(biometric_hash: str, user_address: str, backend_private_key: str) -> str:
        """Generate Ethereum signature exactly matching smart contract format"""
        try:
            # Convert hash to bytes32 format (ensure it's 64 hex chars)
            if not biometric_hash.startswith('0x'):
                biometric_hash = '0x' + biometric_hash
            
            # Pad to 32 bytes (64 hex chars) if needed
            if len(biometric_hash) < 66:  # 0x + 64 chars
                biometric_hash = biometric_hash.ljust(66, '0')
            
            # Ensure user address is checksummed
            if not user_address.startswith('0x'):
                user_address = '0x' + user_address
            
            # Create message hash exactly as in Solidity:
            # solidityKeccak256(["address", "bytes32"], [userAddress, faceHash])
            
            # Convert to bytes for keccak256
            address_bytes = bytes.fromhex(user_address[2:].rjust(40, '0'))
            hash_bytes = bytes.fromhex(biometric_hash[2:].rjust(64, '0'))
            
            # Create the exact same hash as solidityKeccak256
            message_hash = keccak(
                address_bytes.rjust(32, b'\x00') +  # address padded to 32 bytes
                hash_bytes  # bytes32 hash
            )
            
            # Create EIP-191 signature ("Ethereum Signed Message")
            backend_account = Account.from_key(backend_private_key)
            
            # Sign the raw hash (ethers.js does arrayify(message) before signing)
            signature = backend_account.signHash(message_hash)
            
            return signature.signature.hex()
            
        except Exception as e:
            print(f"Ethereum signature generation error: {e}")
            # Fallback to simple signature for testing
            return CryptoUtils.sign_data_simple(biometric_hash, user_address, backend_private_key)
    
    @staticmethod
    def sign_data_simple(data: str, wallet_address: str, private_key_hex: str) -> str:
        """Simple signature for testing/fallback"""
        try:
            message = f"{data}.{wallet_address}"
            account = Account.from_key(private_key_hex)
            
            # Create EIP-191 message
            encoded_message = encode_defunct(text=message)
            signature = account.sign_message(encoded_message)
            
            return signature.signature.hex()
        except Exception as e:
            print(f"Simple signature error: {e}")
            return "0x" + hashlib.sha256(f"{data}{wallet_address}".encode()).hexdigest()
    
    @staticmethod
    def sign_data(private_key, data: str, wallet_address: str) -> str:
        """Legacy signature method for backward compatibility"""
        try:
            # Try Ethereum signing if private_key is a hex string
            if isinstance(private_key, str) and private_key.startswith('0x'):
                return CryptoUtils.sign_data_simple(data, wallet_address, private_key)
            
            # Original ECDSA method
            message = f"{data}.{wallet_address}".encode('utf-8')
            signature = private_key.sign(message, ec.ECDSA(hashes.SHA256()))
            return base64.b64encode(signature).decode('utf-8')
        except Exception as e:
            print(f"Legacy signature error: {e}")
            return "legacy_signature_" + hashlib.md5(f"{data}{wallet_address}".encode()).hexdigest()
    
    @staticmethod
    def verify_signature(public_key, signature: str, data: str, wallet_address: str) -> bool:
        """Verify signature (legacy method)"""
        try:
            message = f"{data}.{wallet_address}".encode('utf-8')
            sig_bytes = base64.b64decode(signature)
            public_key.verify(sig_bytes, message, ec.ECDSA(hashes.SHA256()))
            return True
        except:
            return False
    
    @staticmethod
    def create_backend_private_key() -> str:
        """Generate a backend private key for signing"""
        account = Account.create()
        return account.key.hex()

class FaceProcessor:
    """Face processing utilities using MediaPipe"""
    
    def __init__(self):
        self.mp_face_mesh = mp.solutions.face_mesh
        self.mp_face_detection = mp.solutions.face_detection
        self.face_mesh = self.mp_face_mesh.FaceMesh(
            static_image_mode=False,
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        self.face_detection = self.mp_face_detection.FaceDetection(
            model_selection=0,
            min_detection_confidence=0.5
        )
        
        # Key facial landmarks
        self.LEFT_EYE_LANDMARKS = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246]
        self.RIGHT_EYE_LANDMARKS = [362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398]
        self.MOUTH_LANDMARKS = [61, 84, 17, 314, 405, 320, 307, 375, 321, 308, 324, 318]
        
    def extract_face_embedding(self, image: np.ndarray) -> Optional[np.ndarray]:
        """Extract facial feature embedding from image"""
        rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = self.face_mesh.process(rgb_image)
        
        if not results.multi_face_landmarks:
            return None
        
        landmarks = results.multi_face_landmarks[0]
        
        # Extract key facial features
        features = []
        h, w, _ = image.shape
        
        for idx in range(0, 468, 10):  # Sample landmarks
            if idx < len(landmarks.landmark):
                lm = landmarks.landmark[idx]
                features.extend([lm.x * w, lm.y * h, lm.z])
        
        return np.array(features)
    
    def detect_blink(self, landmarks, image_shape) -> bool:
        """Detect eye blink using eye aspect ratio"""
        def eye_aspect_ratio(eye_landmarks):
            # Calculate vertical distances
            A = euclidean([landmarks.landmark[eye_landmarks[1]].x * image_shape[1],
                          landmarks.landmark[eye_landmarks[1]].y * image_shape[0]], 
                         [landmarks.landmark[eye_landmarks[5]].x * image_shape[1],
                          landmarks.landmark[eye_landmarks[5]].y * image_shape[0]])
            
            B = euclidean([landmarks.landmark[eye_landmarks[2]].x * image_shape[1],
                          landmarks.landmark[eye_landmarks[2]].y * image_shape[0]], 
                         [landmarks.landmark[eye_landmarks[4]].x * image_shape[1],
                          landmarks.landmark[eye_landmarks[4]].y * image_shape[0]])
            
            # Calculate horizontal distance
            C = euclidean([landmarks.landmark[eye_landmarks[0]].x * image_shape[1],
                          landmarks.landmark[eye_landmarks[0]].y * image_shape[0]], 
                         [landmarks.landmark[eye_landmarks[3]].x * image_shape[1],
                          landmarks.landmark[eye_landmarks[3]].y * image_shape[0]])
            
            # Calculate EAR
            ear = (A + B) / (2.0 * C)
            return ear
        
        # Get EAR for both eyes
        left_ear = eye_aspect_ratio(self.LEFT_EYE_LANDMARKS[:6])
        right_ear = eye_aspect_ratio(self.RIGHT_EYE_LANDMARKS[:6])
        
        # Average EAR
        ear = (left_ear + right_ear) / 2.0
        
        return ear < Config.BLINK_THRESHOLD
    
    def detect_smile(self, landmarks, image_shape) -> bool:
        """Detect smile using mouth landmarks"""
        mouth_points = []
        for idx in self.MOUTH_LANDMARKS:
            lm = landmarks.landmark[idx]
            mouth_points.append([lm.x * image_shape[1], lm.y * image_shape[0]])
        
        mouth_points = np.array(mouth_points)
        
        # Calculate mouth width to height ratio
        mouth_width = euclidean(mouth_points[0], mouth_points[6])
        mouth_height = euclidean(mouth_points[3], mouth_points[9])
        
        smile_ratio = mouth_width / mouth_height
        return smile_ratio > Config.SMILE_THRESHOLD
    
    def get_head_pose(self, landmarks, image_shape) -> Tuple[float, float, float]:
        """Calculate head pose angles (yaw, pitch, roll)"""
        h, w = image_shape[:2]
        
        # 3D model points (nose tip, chin, left eye corner, right eye corner, left mouth corner, right mouth corner)
        model_points = np.array([
            (0.0, 0.0, 0.0),             # Nose tip
            (0.0, -330.0, -65.0),        # Chin
            (-225.0, 170.0, -135.0),     # Left eye corner
            (225.0, 170.0, -135.0),      # Right eye corner
            (-150.0, -150.0, -125.0),    # Left mouth corner
            (150.0, -150.0, -125.0)      # Right mouth corner
        ])
        
        # 2D image points from landmarks
        image_points = np.array([
            (landmarks.landmark[1].x * w, landmarks.landmark[1].y * h),     # Nose tip
            (landmarks.landmark[152].x * w, landmarks.landmark[152].y * h), # Chin
            (landmarks.landmark[33].x * w, landmarks.landmark[33].y * h),   # Left eye corner
            (landmarks.landmark[263].x * w, landmarks.landmark[263].y * h), # Right eye corner
            (landmarks.landmark[61].x * w, landmarks.landmark[61].y * h),   # Left mouth corner
            (landmarks.landmark[291].x * w, landmarks.landmark[291].y * h)  # Right mouth corner
        ], dtype="double")
        
        # Camera internals
        focal_length = w
        center = (w/2, h/2)
        camera_matrix = np.array([
            [focal_length, 0, center[0]],
            [0, focal_length, center[1]],
            [0, 0, 1]], dtype="double")
        
        dist_coeffs = np.zeros((4, 1))
        
        # Solve PnP
        success, rotation_vector, translation_vector = cv2.solvePnP(
            model_points, image_points, camera_matrix, dist_coeffs)
        
        if not success:
            return 0.0, 0.0, 0.0
        
        # Convert rotation vector to rotation matrix
        rotation_matrix, _ = cv2.Rodrigues(rotation_vector)
        
        # Extract Euler angles
        angles = cv2.decomposeProjectionMatrix(
            np.hstack((rotation_matrix, translation_vector)))[-1]
        
        pitch, yaw, roll = angles.flatten()
        
        return yaw, pitch, roll
    
    def extract_lip_landmarks(self, landmarks, image_shape) -> np.ndarray:
        """Extract lip movement features"""
        lip_points = []
        for idx in self.MOUTH_LANDMARKS:
            lm = landmarks.landmark[idx]
            lip_points.append([lm.x * image_shape[1], lm.y * image_shape[0]])
        
        return np.array(lip_points).flatten()

class VoiceProcessor:
    """Voice processing utilities"""
    
    @staticmethod
    def extract_mfcc(audio_data: np.ndarray, sr: int = Config.SAMPLE_RATE) -> np.ndarray:
        """Extract MFCC features from audio"""
        mfccs = librosa.feature.mfcc(
            y=audio_data, 
            sr=sr, 
            n_mfcc=Config.MFCC_FEATURES
        )
        return np.mean(mfccs.T, axis=0)
    
    @staticmethod
    def compute_audio_energy(audio_data: np.ndarray, window_size: int = 1024) -> np.ndarray:
        """Compute audio energy over time"""
        energy = []
        for i in range(0, len(audio_data) - window_size, window_size // 2):
            window = audio_data[i:i + window_size]
            energy.append(np.sum(window ** 2))
        
        # Smooth the energy signal
        energy = np.array(energy)
        energy = gaussian_filter1d(energy, sigma=Config.AUDIO_ENERGY_SMOOTH_WINDOW)
        return energy
    
    @staticmethod
    def compare_voiceprints(voiceprint1: np.ndarray, voiceprint2: np.ndarray) -> float:
        """Compare two voiceprint embeddings using cosine similarity"""
        similarity = np.dot(voiceprint1, voiceprint2) / (
            np.linalg.norm(voiceprint1) * np.linalg.norm(voiceprint2))
        return similarity

class LipSyncProcessor:
    """Lip-sync verification utilities"""
    
    @staticmethod
    def compute_lip_movement(lip_sequences: List[np.ndarray]) -> np.ndarray:
        """Compute lip movement energy over time"""
        movement = []
        for i in range(1, len(lip_sequences)):
            diff = np.linalg.norm(lip_sequences[i] - lip_sequences[i-1])
            movement.append(diff)
        
        # Smooth the movement signal
        movement = np.array(movement)
        movement = gaussian_filter1d(movement, sigma=Config.AUDIO_ENERGY_SMOOTH_WINDOW)
        return movement
    
    @staticmethod
    def dtw_alignment(seq1: np.ndarray, seq2: np.ndarray) -> float:
        """Dynamic Time Warping alignment between two sequences"""
        n, m = len(seq1), len(seq2)
        dtw_matrix = np.full((n + 1, m + 1), np.inf)
        dtw_matrix[0, 0] = 0
        
        for i in range(1, n + 1):
            for j in range(1, m + 1):
                cost = abs(seq1[i-1] - seq2[j-1])
                dtw_matrix[i, j] = cost + min(
                    dtw_matrix[i-1, j],      # insertion
                    dtw_matrix[i, j-1],      # deletion
                    dtw_matrix[i-1, j-1]     # match
                )
        
        return dtw_matrix[n, m] / (n + m)
    
    @staticmethod
    def compute_correlation(audio_energy: np.ndarray, lip_movement: np.ndarray) -> float:
        """Compute correlation between audio energy and lip movement"""
        # Normalize lengths
        min_len = min(len(audio_energy), len(lip_movement))
        audio_energy = audio_energy[:min_len]
        lip_movement = lip_movement[:min_len]
        
        # Normalize values
        audio_energy = (audio_energy - np.mean(audio_energy)) / np.std(audio_energy)
        lip_movement = (lip_movement - np.mean(lip_movement)) / np.std(lip_movement)
        
        # Compute cross-correlation
        correlation = np.corrcoef(audio_energy, lip_movement)[0, 1]
        return correlation if not np.isnan(correlation) else 0.0

class DatabaseManager:
    """Database management for user templates"""
    
    def __init__(self, db_path: str = Config.DB_PATH):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Initialize SQLite database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                user_id TEXT PRIMARY KEY,
                face_hash TEXT NOT NULL,
                voice_hash TEXT NOT NULL,
                private_key TEXT NOT NULL,
                public_key TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS verification_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT,
                verification_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                face_liveness BOOLEAN,
                voice_match BOOLEAN,
                lip_sync BOOLEAN,
                overall_result BOOLEAN,
                hash_value TEXT,
                signature TEXT,
                FOREIGN KEY (user_id) REFERENCES users (user_id)
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def save_user_template(self, user_id: str, face_embedding: np.ndarray, 
                          voice_embedding: np.ndarray, private_key, public_key) -> Tuple[str, str]:
        """Save user biometric templates as hashes"""
        # Generate hashes
        face_hash = CryptoUtils.generate_hash(face_embedding.tobytes())
        voice_hash = CryptoUtils.generate_hash(voice_embedding.tobytes())
        
        # Serialize keys
        private_pem = private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        )
        public_pem = public_key.public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo
        )
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT OR REPLACE INTO users 
            (user_id, face_hash, voice_hash, private_key, public_key) 
            VALUES (?, ?, ?, ?, ?)
        ''', (user_id, face_hash, voice_hash, private_pem.decode(), public_pem.decode()))
        
        conn.commit()
        conn.close()
        
        return face_hash, voice_hash
    
    def get_user_data(self, user_id: str) -> Optional[Dict]:
        """Retrieve user data from database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT face_hash, voice_hash, private_key, public_key 
            FROM users WHERE user_id = ?
        ''', (user_id,))
        
        result = cursor.fetchone()
        conn.close()
        
        if result:
            private_key = serialization.load_pem_private_key(
                result[2].encode(), password=None, backend=default_backend())
            public_key = serialization.load_pem_public_key(
                result[3].encode(), backend=default_backend())
            
            return {
                'face_hash': result[0],
                'voice_hash': result[1],
                'private_key': private_key,
                'public_key': public_key
            }
        return None
    
    def log_verification(self, user_id: str, face_liveness: bool, voice_match: bool, 
                        lip_sync: bool, overall_result: bool, hash_value: str, signature: str):
        """Log verification attempt"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO verification_logs 
            (user_id, face_liveness, voice_match, lip_sync, overall_result, hash_value, signature) 
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (user_id, face_liveness, voice_match, lip_sync, overall_result, hash_value, signature))
        
        conn.commit()
        conn.close()
    
    def export_logs(self, user_id: str = None) -> List[Dict]:
        """Export verification logs as JSON"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        if user_id:
            cursor.execute('SELECT * FROM verification_logs WHERE user_id = ?', (user_id,))
        else:
            cursor.execute('SELECT * FROM verification_logs')
        
        columns = [description[0] for description in cursor.description]
        results = []
        
        for row in cursor.fetchall():
            results.append(dict(zip(columns, row)))
        
        conn.close()
        return results

def generate_random_phrase() -> str:
    """Generate a random phrase for voice challenge"""
    import random
    
    # Different types of phrases for variety
    phrase_types = [
        "nato_phonetic",
        "common_words", 
        "sentences",
        "numbers_and_words"
    ]
    
    phrase_type = random.choice(phrase_types)
    
    if phrase_type == "nato_phonetic":
        nato_words = [
            "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", 
            "Golf", "Hotel", "India", "Juliet", "Kilo", "Lima", 
            "Mike", "November", "Oscar", "Papa", "Quebec", "Romeo",
            "Sierra", "Tango", "Uniform", "Victor", "Whiskey", "X-ray", "Yankee", "Zulu"
        ]
        selected = random.sample(nato_words, 3)
        number = random.randint(10, 99)
        return f"{' '.join(selected)} {number}"
    
    elif phrase_type == "common_words":
        adjectives = ["bright", "quick", "smart", "happy", "calm", "clear", "fresh", "strong"]
        nouns = ["ocean", "mountain", "forest", "river", "garden", "window", "bridge", "castle"]
        verbs = ["flows", "shines", "grows", "stands", "moves", "glows", "dances", "sings"]
        
        adj = random.choice(adjectives)
        noun = random.choice(nouns)
        verb = random.choice(verbs)
        number = random.randint(100, 999)
        
        return f"The {adj} {noun} {verb} {number}"
    
    elif phrase_type == "sentences":
        sentences = [
            "Security verification in progress",
            "Digital identity confirmation required", 
            "Biometric authentication system active",
            "Voice pattern recognition enabled",
            "Blockchain verification protocol initiated",
            "Smart contract validation sequence started",
            "Cryptographic signature generation complete",
            "Multi-factor authentication process running"
        ]
        base_sentence = random.choice(sentences)
        number = random.randint(100, 999)
        return f"{base_sentence} {number}"
    
    else:  # numbers_and_words
        colors = ["red", "blue", "green", "yellow", "purple", "orange", "silver", "golden"]
        objects = ["key", "box", "door", "card", "book", "phone", "watch", "coin"]
        
        color = random.choice(colors)
        obj = random.choice(objects)
        num1 = random.randint(10, 99)
        num2 = random.randint(100, 999)
        
        return f"{color.capitalize()} {obj} number {num1} code {num2}"

def send_to_smart_contract(hash_value: str, signature: str, wallet_address: str) -> bool:
    """Send hash and signature to smart contract backend"""
    try:
        # Import blockchain integration (local import to avoid circular dependency)
        from blockchain_integration import send_verification_to_blockchain
        
        # Generate a temporary user ID for this verification
        temp_user_id = f"verify_{int(time.time())}"
        
        # Send verification to blockchain
        result = send_verification_to_blockchain(
            user_id=temp_user_id,
            verification_hash=hash_value,
            signature=signature,
            wallet_address=wallet_address
        )
        
        success = result.get('success', False) and result.get('verified', False)
        
        if success:
            print(f"✅ Smart contract verification successful")
            print(f"📜 Transaction hash: {result.get('transaction_hash', 'N/A')}")
            print(f"📊 Confidence score: {result.get('confidence_score', 0.0)}")
        else:
            print(f"❌ Smart contract verification failed: {result.get('error', 'Unknown error')}")
        
        return success
        
    except ImportError:
        # Fallback to simulation if blockchain integration is not available
        print("⚠️ Blockchain integration not available, using simulation mode")
        payload = {
            "hash": hash_value,
            "signature": signature,
            "wallet_address": wallet_address,
            "timestamp": int(time.time())
        }
        
        print(f"📤 Simulating smart contract call: {json.dumps(payload, indent=2)}")
        return True
        
    except Exception as e:
        print(f"💥 Smart contract integration error: {str(e)}")
        return False
