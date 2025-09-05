#!/usr/bin/env python3
"""
Face + Voice Enrollment System
Captures user biometric templates and stores hashed versions for verification
"""

import cv2
import numpy as np
import sounddevice as sd
import librosa
import tkinter as tk
from tkinter import ttk, messagebox
import threading
import time
import random
from datetime import datetime
from PIL import Image, ImageTk

from utils import (
    Config, FaceProcessor, VoiceProcessor, DatabaseManager, 
    CryptoUtils, generate_random_phrase, send_to_smart_contract
)

class BiometricEnrollment:
    """Main enrollment class for capturing biometric templates"""
    
    def __init__(self, user_id: str, wallet_address: str = None):
        self.user_id = user_id
        self.wallet_address = wallet_address or f"0x{random.randint(100000, 999999)}"
        
        # Initialize processors
        self.face_processor = FaceProcessor()
        self.db_manager = DatabaseManager()
        
        # Enrollment data
        self.face_samples = []
        self.voice_samples = []
        self.enrollment_complete = False
        
        # GUI components
        self.root = None
        self.video_label = None
        self.instruction_label = None
        self.progress_var = None
        
        # Camera and audio
        self.cap = None
        self.recording_audio = False
        self.audio_data = []
        
    def start_enrollment_gui(self):
        """Start the GUI-based enrollment process"""
        self.root = tk.Tk()
        self.root.title(f"Biometric Enrollment - {self.user_id}")
        self.root.geometry("800x600")
        self.root.configure(bg='#2c3e50')
        
        # Main frame
        main_frame = ttk.Frame(self.root)
        main_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Title
        title_label = tk.Label(
            main_frame, 
            text="🔐 Biometric Identity Enrollment",
            font=('Arial', 18, 'bold'),
            fg='white',
            bg='#2c3e50'
        )
        title_label.pack(pady=10)
        
        # User info
        info_frame = ttk.Frame(main_frame)
        info_frame.pack(fill=tk.X, pady=10)
        
        tk.Label(info_frame, text=f"User ID: {self.user_id}", font=('Arial', 12)).pack(side=tk.LEFT)
        tk.Label(info_frame, text=f"Wallet: {self.wallet_address[:10]}...", font=('Arial', 12)).pack(side=tk.RIGHT)
        
        # Video frame
        self.video_label = tk.Label(main_frame, bg='black', width=640, height=480)
        self.video_label.pack(pady=10)
        
        # Instruction label
        self.instruction_label = tk.Label(
            main_frame,
            text="Click 'Start Enrollment' to begin",
            font=('Arial', 14),
            fg='#3498db',
            bg='#2c3e50'
        )
        self.instruction_label.pack(pady=10)
        
        # Progress bar
        self.progress_var = tk.DoubleVar()
        progress_bar = ttk.Progressbar(
            main_frame, 
            variable=self.progress_var, 
            maximum=100,
            length=400
        )
        progress_bar.pack(pady=10)
        
        # Control buttons
        button_frame = ttk.Frame(main_frame)
        button_frame.pack(fill=tk.X, pady=20)
        
        start_btn = tk.Button(
            button_frame,
            text="🚀 Start Enrollment",
            font=('Arial', 12, 'bold'),
            bg='#27ae60',
            fg='white',
            command=self.start_enrollment_process,
            padx=20, pady=10
        )
        start_btn.pack(side=tk.LEFT, padx=10)
        
        cancel_btn = tk.Button(
            button_frame,
            text="❌ Cancel",
            font=('Arial', 12),
            bg='#e74c3c',
            fg='white',
            command=self.cancel_enrollment,
            padx=20, pady=10
        )
        cancel_btn.pack(side=tk.RIGHT, padx=10)
        
        # Start video stream
        self.start_video_stream()
        
        # Handle window close
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
        
        self.root.mainloop()
    
    def start_video_stream(self):
        """Initialize camera and start video stream"""
        try:
            self.cap = cv2.VideoCapture(0)
            self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            self.update_video_feed()
        except Exception as e:
            messagebox.showerror("Camera Error", f"Failed to initialize camera: {e}")
    
    def update_video_feed(self):
        """Update video feed in GUI"""
        if self.cap and self.cap.isOpened():
            ret, frame = self.cap.read()
            if ret:
                # Flip frame horizontally for mirror effect
                frame = cv2.flip(frame, 1)
                
                # Process face detection for visualization
                rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                results = self.face_processor.face_mesh.process(rgb_frame)
                
                if results.multi_face_landmarks:
                    # Draw face mesh
                    for landmarks in results.multi_face_landmarks:
                        for idx, landmark in enumerate(landmarks.landmark):
                            if idx % 10 == 0:  # Draw every 10th landmark
                                x = int(landmark.x * frame.shape[1])
                                y = int(landmark.y * frame.shape[0])
                                cv2.circle(frame, (x, y), 2, (0, 255, 0), -1)
                
                # Convert to PIL format for Tkinter
                frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                image = Image.fromarray(frame)
                photo = ImageTk.PhotoImage(image)
                
                if self.video_label:
                    self.video_label.configure(image=photo)
                    self.video_label.image = photo
            
            # Schedule next update
            if self.root:
                self.root.after(30, self.update_video_feed)
    
    def start_enrollment_process(self):
        """Start the multi-stage enrollment process"""
        threading.Thread(target=self._enrollment_workflow, daemon=True).start()
    
    def _enrollment_workflow(self):
        """Main enrollment workflow"""
        try:
            # Stage 1: Face Template Capture
            self.update_instruction("📸 Face Template Capture - Please look at the camera")
            self.progress_var.set(10)
            
            if not self._capture_face_templates():
                self.update_instruction("❌ Face capture failed. Please try again.")
                return
            
            # Stage 2: Voice Template Capture  
            self.update_instruction("🎤 Voice Template Capture - Please speak the phrases")
            self.progress_var.set(50)
            
            if not self._capture_voice_templates():
                self.update_instruction("❌ Voice capture failed. Please try again.")
                return
            
            # Stage 3: Process and Store Templates
            self.update_instruction("⚙️ Processing biometric templates...")
            self.progress_var.set(80)
            
            if not self._process_and_store_templates():
                self.update_instruction("❌ Template processing failed.")
                return
            
            # Stage 4: Complete
            self.update_instruction("✅ Enrollment completed successfully!")
            self.progress_var.set(100)
            
            # Show success dialog
            self.root.after(1000, lambda: messagebox.showinfo(
                "Enrollment Complete", 
                f"Biometric enrollment completed for {self.user_id}\n"
                f"Templates have been securely hashed and stored."
            ))
            
        except Exception as e:
            self.update_instruction(f"❌ Enrollment error: {str(e)}")
            messagebox.showerror("Enrollment Error", str(e))
    
    def _capture_face_templates(self) -> bool:
        """Capture multiple face samples for template creation"""
        samples_needed = 5
        self.face_samples = []
        
        for i in range(samples_needed):
            self.update_instruction(f"📸 Capturing face sample {i+1}/{samples_needed}")
            time.sleep(2)  # Give user time to position
            
            if not self.cap or not self.cap.isOpened():
                return False
            
            ret, frame = self.cap.read()
            if not ret:
                continue
            
            # Extract face embedding
            embedding = self.face_processor.extract_face_embedding(frame)
            if embedding is not None:
                self.face_samples.append(embedding)
                print(f"✓ Face sample {i+1} captured ({len(embedding)} features)")
            else:
                print(f"⚠️ No face detected in sample {i+1}")
                i -= 1  # Retry this sample
        
        return len(self.face_samples) >= 3  # Need at least 3 good samples
    
    def _capture_voice_templates(self) -> bool:
        """Capture voice samples for template creation"""
        phrases_to_speak = [
            "Hello, this is my voice enrollment",
            "The quick brown fox jumps over the lazy dog", 
            "Pack my box with five dozen liquor jugs"
        ]
        
        self.voice_samples = []
        
        for i, phrase in enumerate(phrases_to_speak):
            self.update_instruction(f"🎤 Please say: '{phrase}'")
            time.sleep(1)
            
            # Record audio
            audio_data = self._record_audio_sample(duration=4)
            if audio_data is not None and len(audio_data) > 0:
                # Extract voice features
                mfcc_features = VoiceProcessor.extract_mfcc(audio_data)
                self.voice_samples.append(mfcc_features)
                print(f"✓ Voice sample {i+1} captured ({len(mfcc_features)} MFCC features)")
            else:
                print(f"⚠️ No audio captured for sample {i+1}")
        
        return len(self.voice_samples) >= 2  # Need at least 2 good samples
    
    def _record_audio_sample(self, duration: int = 4) -> np.ndarray:
        """Record audio sample from microphone"""
        try:
            self.update_instruction(f"🎤 Recording... (speak now)")
            
            # Record audio
            audio_data = sd.rec(
                int(duration * Config.SAMPLE_RATE), 
                samplerate=Config.SAMPLE_RATE, 
                channels=1,
                dtype='float32'
            )
            sd.wait()  # Wait for recording to complete
            
            # Flatten and normalize
            audio_data = audio_data.flatten()
            audio_data = librosa.util.normalize(audio_data)
            
            return audio_data
        except Exception as e:
            print(f"Audio recording error: {e}")
            return None
    
    def _process_and_store_templates(self) -> bool:
        """Process captured samples and store as secure templates"""
        try:
            # Create face template (average of samples)
            face_template = np.mean(self.face_samples, axis=0)
            print(f"Face template created: {face_template.shape}")
            
            # Create voice template (average of samples) 
            voice_template = np.mean(self.voice_samples, axis=0)
            print(f"Voice template created: {voice_template.shape}")
            
            # Generate cryptographic keys
            private_key, public_key = CryptoUtils.generate_keypair()
            
            # Save templates to database (as hashes)
            face_hash, voice_hash = self.db_manager.save_user_template(
                self.user_id, face_template, voice_template, private_key, public_key
            )
            
            print(f"✓ Face hash: {face_hash[:16]}...")
            print(f"✓ Voice hash: {voice_hash[:16]}...")
            
            # Create combined biometric hash for smart contract
            combined_data = face_template.tobytes() + voice_template.tobytes()
            biometric_hash = CryptoUtils.generate_hash(combined_data)
            
            # Generate signature
            signature = CryptoUtils.sign_data(private_key, biometric_hash, self.wallet_address)
            
            print(f"✓ Combined biometric hash: {biometric_hash[:16]}...")
            print(f"✓ Signature: {signature[:32]}...")
            
            # Send to smart contract (simulated)
            success = send_to_smart_contract(biometric_hash, signature, self.wallet_address)
            
            if success:
                print("✅ Biometric data successfully registered with smart contract")
            else:
                print("⚠️ Smart contract registration failed")
            
            return True
            
        except Exception as e:
            print(f"Template processing error: {e}")
            return False
    
    def update_instruction(self, text: str):
        """Update instruction label in GUI"""
        if self.instruction_label:
            self.instruction_label.configure(text=text)
            print(f"📋 {text}")
    
    def cancel_enrollment(self):
        """Cancel enrollment process"""
        if messagebox.askquestion("Cancel", "Are you sure you want to cancel enrollment?") == 'yes':
            self.on_closing()
    
    def on_closing(self):
        """Handle window closing"""
        if self.cap:
            self.cap.release()
        if self.root:
            self.root.destroy()

def main():
    """Command line enrollment interface"""
    print("🔐 Biometric Identity Enrollment System")
    print("=" * 40)
    
    # Get user input
    user_id = input("Enter User ID: ").strip()
    if not user_id:
        print("❌ User ID is required")
        return
    
    wallet_address = input("Enter Wallet Address (optional): ").strip()
    if not wallet_address:
        wallet_address = f"0x{random.randint(100000000000, 999999999999):012x}"
        print(f"Generated wallet address: {wallet_address}")
    
    print(f"\n📋 Starting enrollment for user: {user_id}")
    print(f"📋 Wallet address: {wallet_address}")
    
    # Start enrollment
    enrollment = BiometricEnrollment(user_id, wallet_address)
    
    try:
        # GUI mode
        enrollment.start_enrollment_gui()
    except ImportError:
        print("❌ GUI libraries not available, using console mode")
        # Console mode fallback
        console_enrollment(user_id, wallet_address)

def console_enrollment(user_id: str, wallet_address: str):
    """Console-based enrollment for systems without GUI"""
    print("\n🔧 Console enrollment mode")
    
    enrollment = BiometricEnrollment(user_id, wallet_address)
    
    # Initialize camera
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("❌ Failed to open camera")
        return
    
    print("\n📸 Face template capture (5 samples)")
    input("Press Enter when ready...")
    
    face_samples = []
    for i in range(5):
        print(f"Capturing sample {i+1}/5...")
        ret, frame = cap.read()
        if ret:
            embedding = enrollment.face_processor.extract_face_embedding(frame)
            if embedding is not None:
                face_samples.append(embedding)
                print(f"✓ Sample {i+1} captured")
        time.sleep(2)
    
    cap.release()
    
    print(f"\n🎤 Voice template capture (3 samples)")
    voice_samples = []
    phrases = [
        "Hello, this is my voice enrollment",
        "The quick brown fox jumps over the lazy dog",
        "Pack my box with five dozen liquor jugs"
    ]
    
    for i, phrase in enumerate(phrases):
        print(f"\nSay: '{phrase}'")
        input("Press Enter and speak...")
        
        try:
            audio_data = sd.rec(int(4 * Config.SAMPLE_RATE), samplerate=Config.SAMPLE_RATE, channels=1)
            sd.wait()
            audio_data = audio_data.flatten()
            
            mfcc_features = VoiceProcessor.extract_mfcc(audio_data)
            voice_samples.append(mfcc_features)
            print(f"✓ Voice sample {i+1} captured")
        except Exception as e:
            print(f"❌ Audio capture failed: {e}")
    
    # Process templates
    if len(face_samples) >= 3 and len(voice_samples) >= 2:
        enrollment.face_samples = face_samples
        enrollment.voice_samples = voice_samples
        
        if enrollment._process_and_store_templates():
            print("\n✅ Enrollment completed successfully!")
        else:
            print("\n❌ Template processing failed")
    else:
        print("\n❌ Insufficient samples captured")

if __name__ == "__main__":
    main()
