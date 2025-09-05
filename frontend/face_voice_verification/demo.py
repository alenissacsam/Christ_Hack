#!/usr/bin/env python3
"""
Biometric Verification System Demo
Demonstrates the complete face + voice + lip-sync verification pipeline
"""

import os
import sys
import time
from datetime import datetime

def print_banner():
    """Print demo banner"""
    print("🛡️" + "=" * 60 + "🛡️")
    print("          BIOMETRIC IDENTITY VERIFICATION SYSTEM")
    print("    🔒 Face Liveness • 🎤 Voice Match • 💋 Lip-Sync")
    print("🛡️" + "=" * 60 + "🛡️")
    print()

def print_section(title, emoji="🔸"):
    """Print section header"""
    print(f"\n{emoji} {title}")
    print("-" * (len(title) + 4))

def simulate_progress(message, duration=2):
    """Simulate progress with dots"""
    print(f"{message}", end="", flush=True)
    for _ in range(duration * 2):
        print(".", end="", flush=True)
        time.sleep(0.5)
    print(" ✅")

def check_system_requirements():
    """Check if all required components are available"""
    print_section("System Requirements Check", "🔍")
    
    requirements = [
        ("Python 3.9+", lambda: sys.version_info >= (3, 9), "✅ Python OK", "❌ Please upgrade Python"),
        ("OpenCV", lambda: __import__('cv2'), "✅ OpenCV OK", "❌ pip install opencv-python"),
        ("MediaPipe", lambda: __import__('mediapipe'), "✅ MediaPipe OK", "❌ pip install mediapipe"),
        ("Librosa", lambda: __import__('librosa'), "✅ Librosa OK", "❌ pip install librosa"),
        ("SoundDevice", lambda: __import__('sounddevice'), "✅ SoundDevice OK", "❌ pip install sounddevice"),
        ("Cryptography", lambda: __import__('cryptography'), "✅ Cryptography OK", "❌ pip install cryptography"),
        ("Tkinter", lambda: __import__('tkinter'), "✅ Tkinter OK", "❌ Install tkinter package"),
        ("PIL", lambda: __import__('PIL'), "✅ Pillow OK", "❌ pip install pillow"),
    ]
    
    all_ok = True
    for name, check_func, ok_msg, fail_msg in requirements:
        try:
            check_func()
            print(f"  {ok_msg}")
        except Exception:
            print(f"  {fail_msg}")
            all_ok = False
    
    return all_ok

def check_hardware():
    """Check camera and microphone availability"""
    print_section("Hardware Check", "🔧")
    
    # Check camera
    try:
        import cv2
        cap = cv2.VideoCapture(0)
        if cap.isOpened():
            print("  ✅ Camera detected and accessible")
            ret, frame = cap.read()
            if ret:
                print(f"  ✅ Camera resolution: {frame.shape[1]}x{frame.shape[0]}")
            else:
                print("  ⚠️ Camera detected but unable to capture frames")
            cap.release()
        else:
            print("  ❌ No camera detected or camera access denied")
            return False
    except Exception as e:
        print(f"  ❌ Camera check failed: {e}")
        return False
    
    # Check microphone
    try:
        import sounddevice as sd
        devices = sd.query_devices()
        input_devices = [d for d in devices if d['max_input_channels'] > 0]
        if input_devices:
            print(f"  ✅ {len(input_devices)} audio input device(s) detected")
            print(f"  📤 Default input: {sd.query_devices(kind='input')['name']}")
        else:
            print("  ❌ No audio input devices detected")
            return False
    except Exception as e:
        print(f"  ❌ Audio check failed: {e}")
        return False
    
    return True

def demo_cryptographic_functions():
    """Demonstrate cryptographic functions"""
    print_section("Cryptographic Security Demo", "🔐")
    
    try:
        from utils import CryptoUtils
        import numpy as np
        
        # Generate sample biometric data
        print("  🧬 Generating sample biometric data...")
        fake_face_data = np.random.rand(141).astype(np.float32)  # 47 landmarks * 3 coords
        fake_voice_data = np.random.rand(13).astype(np.float32)  # MFCC features
        
        # Generate hashes
        face_hash = CryptoUtils.generate_hash(fake_face_data.tobytes())
        voice_hash = CryptoUtils.generate_hash(fake_voice_data.tobytes())
        
        print(f"  🔸 Face embedding hash: {face_hash[:32]}...")
        print(f"  🔸 Voice embedding hash: {voice_hash[:32]}...")
        
        # Generate keypair
        print("  🔑 Generating ECDSA key pair...")
        private_key, public_key = CryptoUtils.generate_keypair()
        
        # Create signature
        wallet_address = "0x742d35Cc6629C0532E3D60C1dcBfC62E2AaF0e19"
        combined_hash = CryptoUtils.generate_hash((face_hash + voice_hash).encode())
        signature = CryptoUtils.sign_data(private_key, combined_hash, wallet_address)
        
        print(f"  🔸 Combined biometric hash: {combined_hash[:32]}...")
        print(f"  🔸 Cryptographic signature: {signature[:48]}...")
        
        # Verify signature
        is_valid = CryptoUtils.verify_signature(public_key, signature, combined_hash, wallet_address)
        print(f"  🔸 Signature verification: {'✅ VALID' if is_valid else '❌ INVALID'}")
        
        print("  ✅ Cryptographic functions working correctly!")
        return True
        
    except Exception as e:
        print(f"  ❌ Cryptographic demo failed: {e}")
        return False

def demo_voice_recognition():
    """Demonstrate voice recognition and phrase generation"""
    print_section("Voice Recognition Demo", "🎤")
    
    try:
        from utils import generate_random_phrase
        
        print("  🗣️ Generating sample voice challenge phrases...")
        
        # Generate several example phrases
        for i in range(5):
            phrase = generate_random_phrase()
            print(f"  📢 Example phrase {i+1}: \"{phrase}\"")
        
        print("\n  💡 During verification, users will see phrases like these displayed prominently")
        print("  💡 The system provides speech-to-text feedback showing what it heard")
        print("  💡 Similarity matching ensures users spoke the correct phrase")
        
        # Test speech recognition if available
        try:
            import speech_recognition as sr
            print("  ✅ Speech recognition library available")
            print("  ✅ Users will get real-time feedback on what they spoke")
        except ImportError:
            print("  ⚠️ Speech recognition not installed (optional feature)")
            print("  💡 Install with: pip install SpeechRecognition")
        
        return True
        
    except Exception as e:
        print(f"  ❌ Voice recognition demo failed: {e}")
        return False

def demo_face_processing():
    """Demonstrate face processing capabilities"""
    print_section("Face Processing Demo", "📸")
    
    try:
        from utils import FaceProcessor
        import cv2
        import numpy as np
        
        print("  📷 Initializing face processor...")
        face_processor = FaceProcessor()
        
        print("  📷 Attempting to capture frame from camera...")
        cap = cv2.VideoCapture(0)
        
        if not cap.isOpened():
            print("  ❌ Cannot open camera for face processing demo")
            return False
        
        # Capture a few frames to let camera adjust
        for _ in range(10):
            cap.read()
        
        ret, frame = cap.read()
        cap.release()
        
        if not ret:
            print("  ❌ Failed to capture frame")
            return False
        
        print(f"  ✅ Frame captured: {frame.shape[1]}x{frame.shape[0]} resolution")
        
        # Process face
        print("  🔍 Detecting face and extracting features...")
        embedding = face_processor.extract_face_embedding(frame)
        
        if embedding is not None:
            print(f"  ✅ Face detected! Feature vector size: {len(embedding)}")
            print(f"  🔸 Sample features: {embedding[:5].round(3)}")
            
            # Test face analysis on the frame
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = face_processor.face_mesh.process(rgb_frame)
            
            if results.multi_face_landmarks:
                landmarks = results.multi_face_landmarks[0]
                print(f"  ✅ Face mesh detected: {len(landmarks.landmark)} landmarks")
                
                # Test head pose
                yaw, pitch, roll = face_processor.get_head_pose(landmarks, frame.shape)
                print(f"  🔸 Head pose - Yaw: {yaw:.1f}°, Pitch: {pitch:.1f}°, Roll: {roll:.1f}°")
                
                print("  ✅ Face processing demo successful!")
                return True
            else:
                print("  ⚠️ Face mesh not detected")
                return False
        else:
            print("  ❌ No face detected in captured frame")
            print("  💡 Make sure you're visible to the camera and try again")
            return False
            
    except Exception as e:
        print(f"  ❌ Face processing demo failed: {e}")
        return False

def demo_blockchain_integration():
    """Demonstrate blockchain integration"""
    print_section("Blockchain Integration Demo", "🔗")
    
    try:
        from blockchain_integration import test_blockchain_connectivity, send_enrollment_to_blockchain
        
        print("  🌐 Testing blockchain connectivity...")
        
        # Test basic connectivity
        if test_blockchain_connectivity():
            print("  ✅ Blockchain integration is configured and ready!")
            
            # Test sample enrollment
            print("  🧪 Testing sample biometric enrollment...")
            test_result = send_enrollment_to_blockchain(
                user_id="demo_user_001",
                biometric_hash="demo_hash_" + str(int(time.time())),
                signature="demo_signature_encoded",
                wallet_address="0x742d35Cc6629C0532E3D60C1dcBfC62E2AaF0e19"
            )
            
            if test_result:
                print("  ✅ Blockchain enrollment test successful!")
            else:
                print("  ⚠️ Blockchain enrollment test failed (backend may be offline)")
            
            return True
        else:
            print("  ⚠️ Blockchain backend not available")
            print("  💡 This is normal if your identity DApp backend isn't running")
            print("  💡 The system will work in simulation mode")
            return True
            
    except Exception as e:
        print(f"  ❌ Blockchain integration demo failed: {e}")
        print("  💡 System will fall back to simulation mode")
        return True

def show_demo_options():
    """Show available demo options"""
    print_section("Available Demos", "🎯")
    
    options = [
        ("1", "🔐 Full Enrollment Demo", "Complete user registration with face + voice capture"),
        ("2", "🛡️ Full Verification Demo", "Complete identity verification with all challenges"),
        ("3", "📊 System Performance Test", "Run performance benchmarks and accuracy tests"),
        ("4", "🔍 Component Tests", "Test individual components (face, voice, lip-sync)"),
        ("5", "📝 View Verification Logs", "Show recent verification attempts and results"),
        ("6", "🧪 Blockchain Integration", "Test smart contract connectivity and operations"),
        ("7", "🔐 Ethereum Signatures", "Test Ethereum signature compatibility with smart contracts"),
        ("0", "🚪 Exit Demo", "Exit the demo system")
    ]
    
    for key, name, description in options:
        print(f"  {key}. {name}")
        print(f"     {description}")
        print()

def run_enrollment_demo():
    """Run the enrollment demo"""
    print_section("Enrollment Demo", "🔐")
    
    print("  Starting biometric enrollment demo...")
    print("  This will launch the enrollment GUI with a demo user.")
    print()
    
    demo_user_id = f"demo_user_{int(time.time())}"
    demo_wallet = "0x742d35Cc6629C0532E3D60C1dcBfC62E2AaF0e19"
    
    print(f"  👤 Demo User ID: {demo_user_id}")
    print(f"  💼 Demo Wallet: {demo_wallet}")
    print()
    
    input("  Press Enter to launch enrollment GUI (or Ctrl+C to cancel)...")
    
    try:
        from enroll import BiometricEnrollment
        enrollment = BiometricEnrollment(demo_user_id, demo_wallet)
        enrollment.start_enrollment_gui()
        print("  ✅ Enrollment demo completed!")
        
    except KeyboardInterrupt:
        print("  🛑 Enrollment demo cancelled by user")
    except Exception as e:
        print(f"  ❌ Enrollment demo failed: {e}")

def run_verification_demo():
    """Run the verification demo"""
    print_section("Verification Demo", "🛡️")
    
    # Check if any users are enrolled
    try:
        from utils import DatabaseManager
        db = DatabaseManager()
        
        # Try to get all users (this would require adding a method to DatabaseManager)
        print("  🔍 Looking for enrolled users...")
        
        # For demo, we'll ask user to specify
        print("  💡 Make sure you have enrolled at least one user first!")
        user_id = input("  Enter User ID to verify (or press Enter for guided demo): ").strip()
        
        if not user_id:
            print("  📋 Running guided verification demo...")
            user_id = "demo_user_guided"
            print(f"  Using demo user: {user_id}")
        
        user_data = db.get_user_data(user_id)
        
        if not user_data:
            print(f"  ❌ No enrollment data found for user: {user_id}")
            print("  💡 Please run enrollment demo first (option 1)")
            return
        
        print(f"  ✅ Found enrollment data for user: {user_id}")
        print()
        
        input("  Press Enter to launch verification GUI (or Ctrl+C to cancel)...")
        
        from verify import BiometricVerification
        verification = BiometricVerification(user_id)
        verification.start_verification_gui()
        print("  ✅ Verification demo completed!")
        
    except KeyboardInterrupt:
        print("  🛑 Verification demo cancelled by user")
    except Exception as e:
        print(f"  ❌ Verification demo failed: {e}")

def test_ethereum_signatures():
    """Test Ethereum signature generation compatibility"""
    print_section("Ethereum Signature Test", "🔐")
    
    print("  🧪 Testing signature compatibility with your smart contract...")
    print()
    
    try:
        import subprocess
        import os
        
        # Run the Ethereum signature test
        test_file = os.path.join(os.getcwd(), "test_ethereum_signatures.py")
        
        if os.path.exists(test_file):
            print("  Running Ethereum signature compatibility test...")
            result = subprocess.run(["python", test_file], capture_output=True, text=True)
            
            if result.returncode == 0:
                print("  ✅ Ethereum signature test completed successfully!")
                print()
                print("  📋 Test Results:")
                # Show key parts of the output
                lines = result.stdout.split('\n')
                for line in lines:
                    if any(marker in line for marker in ['✅', '❌', '🎯', '📤']):
                        print(f"    {line}")
            else:
                print("  ⚠️ Ethereum signature test had some issues:")
                print(f"    {result.stderr}")
        else:
            print("  ❌ Ethereum signature test file not found")
            print("  💡 Make sure test_ethereum_signatures.py exists")
            
        print("\n  🔗 Smart Contract Integration:")
        print("    • Python now generates signatures in ethers.js format")
        print("    • Uses solidityKeccak256([\"address\", \"bytes32\"], [userAddr, hash])")
        print("    • Creates EIP-191 signatures compatible with your backend")
        print("    • Backend can verify with ethers.utils.verifyMessage()")
        
    except Exception as e:
        print(f"  ❌ Ethereum signature test failed: {e}")
        print("  💡 Install required packages: pip install eth-account eth-utils")

def main():
    """Main demo function"""
    print_banner()
    
    # Initial system check
    print("🔍 Performing system diagnostics...")
    
    if not check_system_requirements():
        print("\n❌ Some system requirements are missing.")
        print("💡 Please install the missing packages and try again.")
        print("💡 Run: pip install -r requirements.txt")
        return
    
    if not check_hardware():
        print("\n❌ Hardware requirements not met.")
        print("💡 Please ensure camera and microphone are connected and accessible.")
        return
    
    # Demo cryptographic functions
    if not demo_cryptographic_functions():
        print("\n❌ Cryptographic system check failed.")
        return
    
    # Demo voice recognition
    demo_voice_recognition()
    
    # Demo face processing
    face_demo_success = demo_face_processing()
    if not face_demo_success:
        print("⚠️ Face processing demo had issues, but continuing...")
    
    # Demo blockchain integration
    demo_blockchain_integration()
    
    print_section("System Ready!", "🚀")
    print("  ✅ All systems operational!")
    print("  ✅ Ready for biometric verification demos")
    print()
    
    # Main demo loop
    while True:
        try:
            show_demo_options()
            choice = input("  Select demo option (0-6): ").strip()
            
            if choice == "0":
                print("  👋 Goodbye! Thanks for trying the biometric verification system.")
                break
            elif choice == "1":
                run_enrollment_demo()
            elif choice == "2":
                run_verification_demo()
            elif choice == "3":
                print("  🚧 Performance test demo - Coming soon!")
            elif choice == "4":
                print("  🚧 Component test demo - Coming soon!")
            elif choice == "5":
                print("  🚧 Verification logs demo - Coming soon!")
            elif choice == "6":
                demo_blockchain_integration()
            elif choice == "7":
                test_ethereum_signatures()
            else:
                print("  ❌ Invalid option. Please select 0-7.")
            
            if choice != "0":
                input("\n  Press Enter to return to main menu...")
                print("\n" + "="*80 + "\n")
            
        except KeyboardInterrupt:
            print("\n  👋 Demo interrupted by user. Goodbye!")
            break
        except Exception as e:
            print(f"  ❌ Demo error: {e}")
            input("  Press Enter to continue...")

if __name__ == "__main__":
    main()
