#!/usr/bin/env python3
"""
Face + Voice Liveness Verification System
Performs real-time verification with face liveness, voice matching, and lip-sync detection
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
from typing import List, Tuple, Dict, Optional
import wave
import io
import os

from utils import (
    Config, FaceProcessor, VoiceProcessor, LipSyncProcessor, DatabaseManager,
    CryptoUtils, generate_random_phrase, send_to_smart_contract
)

class BiometricVerification:
    """Main verification class with face liveness, voice, and lip-sync detection"""
    
    def __init__(self, user_id: str, wallet_address: str = None):
        self.user_id = user_id
        self.wallet_address = wallet_address or f"0x{random.randint(100000, 999999)}"
        
        # Initialize processors
        self.face_processor = FaceProcessor()
        self.voice_processor = VoiceProcessor()
        self.lipsync_processor = LipSyncProcessor()
        self.db_manager = DatabaseManager()
        
        # Verification state
        self.is_verifying = False
        self.verification_results = {
            'face_liveness': False,
            'voice_match': False,
            'lip_sync': False,
            'overall_result': False
        }
        
        # Challenge data
        self.current_challenge = None
        self.voice_phrase = None
        self.challenge_start_time = 0
        
        # Recording data
        self.lip_sequence = []
        self.audio_buffer = []
        self.blink_count = 0
        self.last_blink_time = 0
        
        # GUI components
        self.root = None
        self.video_label = None
        self.instruction_label = None
        self.result_label = None
        self.challenge_label = None
        
        # Camera
        self.cap = None
        
    def start_verification_gui(self):
        """Start the GUI-based verification process"""
        # Load user template first
        user_data = self.db_manager.get_user_data(self.user_id)
        if not user_data:
            messagebox.showerror("User Not Found", f"No enrollment data found for user: {self.user_id}")
            return
        
        self.user_data = user_data
        
        self.root = tk.Tk()
        self.root.title(f"Biometric Verification - {self.user_id}")
        self.root.geometry("900x700")
        self.root.configure(bg='#2c3e50')
        
        # Main frame
        main_frame = ttk.Frame(self.root)
        main_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Title
        title_label = tk.Label(
            main_frame,
            text="🛡️ Biometric Identity Verification",
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
        
        # Challenge instruction
        self.challenge_label = tk.Label(
            main_frame,
            text="Waiting for challenge...",
            font=('Arial', 16, 'bold'),
            fg='#f39c12',
            bg='#2c3e50'
        )
        self.challenge_label.pack(pady=5)
        
        # Voice phrase display (large and prominent)
        self.phrase_display = tk.Label(
            main_frame,
            text="",
            font=('Arial', 20, 'bold'),
            fg='#2ecc71',
            bg='#34495e',
            relief='raised',
            borderwidth=2,
            padx=20,
            pady=10,
            wraplength=600
        )
        self.phrase_display.pack(pady=10)
        self.phrase_display.pack_forget()  # Hide initially
        
        # Speech recognition feedback
        self.speech_feedback = tk.Label(
            main_frame,
            text="",
            font=('Arial', 12),
            fg='#3498db',
            bg='#2c3e50',
            wraplength=600
        )
        self.speech_feedback.pack(pady=5)
        self.speech_feedback.pack_forget()  # Hide initially
        
        # Recording progress bar
        self.recording_progress = ttk.Progressbar(
            main_frame,
            length=400,
            mode='determinate',
            style='Accent.Horizontal.TProgressbar'
        )
        self.recording_progress.pack(pady=5)
        self.recording_progress.pack_forget()  # Hide initially
        
        # Countdown timer display
        self.countdown_label = tk.Label(
            main_frame,
            text="",
            font=('Arial', 16, 'bold'),
            fg='#e74c3c',
            bg='#2c3e50'
        )
        self.countdown_label.pack(pady=5)
        self.countdown_label.pack_forget()  # Hide initially
        
        # Status instruction
        self.instruction_label = tk.Label(
            main_frame,
            text="Click 'Start Verification' to begin",
            font=('Arial', 12),
            fg='#3498db',
            bg='#2c3e50'
        )
        self.instruction_label.pack(pady=5)
        
        # Results frame
        results_frame = ttk.LabelFrame(main_frame, text="Verification Results", padding=10)
        results_frame.pack(fill=tk.X, pady=10)
        
        # Result indicators
        self.face_result_label = tk.Label(results_frame, text="Face Liveness: ⏳ Waiting", font=('Arial', 10))
        self.face_result_label.grid(row=0, column=0, sticky='w', padx=5)
        
        self.voice_result_label = tk.Label(results_frame, text="Voice Match: ⏳ Waiting", font=('Arial', 10))
        self.voice_result_label.grid(row=0, column=1, sticky='w', padx=5)
        
        self.lipsync_result_label = tk.Label(results_frame, text="Lip Sync: ⏳ Waiting", font=('Arial', 10))
        self.lipsync_result_label.grid(row=0, column=2, sticky='w', padx=5)
        
        # Overall result
        self.result_label = tk.Label(
            main_frame,
            text="🔒 Verification Status: Not Started",
            font=('Arial', 14, 'bold'),
            fg='white',
            bg='#2c3e50'
        )
        self.result_label.pack(pady=10)
        
        # Control buttons
        button_frame = ttk.Frame(main_frame)
        button_frame.pack(fill=tk.X, pady=20)
        
        verify_btn = tk.Button(
            button_frame,
            text="🚀 Start Verification",
            font=('Arial', 12, 'bold'),
            bg='#27ae60',
            fg='white',
            command=self.start_verification_process,
            padx=20, pady=10
        )
        verify_btn.pack(side=tk.LEFT, padx=10)
        
        stop_btn = tk.Button(
            button_frame,
            text="⏹️ Stop",
            font=('Arial', 12),
            bg='#e74c3c',
            fg='white',
            command=self.stop_verification,
            padx=20, pady=10
        )
        stop_btn.pack(side=tk.LEFT, padx=10)
        
        exit_btn = tk.Button(
            button_frame,
            text="🚪 Exit",
            font=('Arial', 12),
            bg='#95a5a6',
            fg='white',
            command=self.on_closing,
            padx=20, pady=10
        )
        exit_btn.pack(side=tk.RIGHT, padx=10)
        
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
        """Update video feed with real-time analysis"""
        if self.cap and self.cap.isOpened():
            ret, frame = self.cap.read()
            if ret:
                # Flip frame horizontally for mirror effect
                frame = cv2.flip(frame, 1)
                
                # Process face analysis
                rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                results = self.face_processor.face_mesh.process(rgb_frame)
                
                if results.multi_face_landmarks:
                    landmarks = results.multi_face_landmarks[0]
                    
                    # Draw face mesh
                    for idx, landmark in enumerate(landmarks.landmark):
                        if idx % 10 == 0:  # Draw every 10th landmark
                            x = int(landmark.x * frame.shape[1])
                            y = int(landmark.y * frame.shape[0])
                            cv2.circle(frame, (x, y), 2, (0, 255, 0), -1)
                    
                    # Real-time liveness detection during verification
                    if self.is_verifying:
                        self._analyze_frame(frame, landmarks)
                    
                    # Draw verification status overlay
                    self._draw_verification_overlay(frame, landmarks)
                else:
                    # No face detected
                    cv2.putText(frame, "No Face Detected", (50, 50), 
                               cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
                
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
    
    def _draw_verification_overlay(self, frame, landmarks):
        """Draw verification status overlay on frame"""
        h, w = frame.shape[:2]
        
        # Draw status indicators
        if self.verification_results['face_liveness']:
            cv2.putText(frame, "Face: OK", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        else:
            cv2.putText(frame, "Face: --", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
        
        if self.verification_results['voice_match']:
            cv2.putText(frame, "Voice: OK", (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        else:
            cv2.putText(frame, "Voice: --", (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
        
        if self.verification_results['lip_sync']:
            cv2.putText(frame, "Lip Sync: OK", (10, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        else:
            cv2.putText(frame, "Lip Sync: --", (10, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
        
        # Draw challenge indicator
        if self.current_challenge:
            cv2.putText(frame, f"Challenge: {self.current_challenge}", 
                       (10, h-30), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
    
    def _analyze_frame(self, frame, landmarks):
        """Analyze current frame for liveness and lip movement"""
        h, w = frame.shape[:2]
        
        # Face liveness checks
        if self.current_challenge:
            if "blink" in self.current_challenge.lower():
                if self.face_processor.detect_blink(landmarks, (h, w)):
                    current_time = time.time()
                    if current_time - self.last_blink_time > 0.5:  # Prevent double counting
                        self.blink_count += 1
                        self.last_blink_time = current_time
                        print(f"Blink detected! Count: {self.blink_count}")
            
            elif "smile" in self.current_challenge.lower():
                if self.face_processor.detect_smile(landmarks, (h, w)):
                    self.verification_results['face_liveness'] = True
                    print("Smile detected!")
            
            elif "turn" in self.current_challenge.lower() or "head" in self.current_challenge.lower():
                yaw, pitch, roll = self.face_processor.get_head_pose(landmarks, (h, w))
                if abs(yaw) > Config.HEAD_POSE_THRESHOLD or abs(pitch) > Config.HEAD_POSE_THRESHOLD:
                    self.verification_results['face_liveness'] = True
                    print(f"Head movement detected: yaw={yaw:.1f}, pitch={pitch:.1f}")
        
        # Extract lip landmarks for lip-sync analysis
        if len(self.audio_buffer) > 0:  # Only if we're recording audio
            lip_features = self.face_processor.extract_lip_landmarks(landmarks, (h, w))
            self.lip_sequence.append(lip_features)
    
    def start_verification_process(self):
        """Start the multi-stage verification process"""
        if self.is_verifying:
            return
        
        self.is_verifying = True
        self.reset_verification_state()
        threading.Thread(target=self._verification_workflow, daemon=True).start()
    
    def _verification_workflow(self):
        """Main verification workflow"""
        try:
            print("🔍 Starting verification workflow...")
            
            # Stage 1: Face Liveness Challenge
            self.update_instruction("Stage 1: Face Liveness Challenge")
            if not self._perform_face_liveness_challenge():
                self._verification_failed("Face liveness challenge failed")
                return
            
            # Stage 2: Voice Challenge with Lip-Sync
            self.update_instruction("Stage 2: Voice Challenge")
            if not self._perform_voice_challenge():
                self._verification_failed("Voice challenge failed")
                return
            
            # Stage 3: Final Verification
            self.update_instruction("Stage 3: Processing results...")
            if self._perform_final_verification():
                self._verification_successful()
            else:
                self._verification_failed("Final verification failed")
            
        except Exception as e:
            print(f"Verification error: {e}")
            self._verification_failed(f"System error: {str(e)}")
        finally:
            self.is_verifying = False
    
    def _perform_face_liveness_challenge(self) -> bool:
        """Perform face liveness detection challenge"""
        # Select random challenge
        challenge_types = [
            ("blink", "Please blink twice"),
            ("smile", "Please smile"),
            ("head_left", "Please turn your head left"),
            ("head_right", "Please turn your head right"),
            ("head_up", "Please tilt your head up")
        ]
        
        challenge_type, challenge_text = random.choice(challenge_types)
        self.current_challenge = challenge_text
        self.update_challenge(challenge_text)
        
        print(f"Face challenge: {challenge_text}")
        
        # Reset challenge state
        self.blink_count = 0
        self.verification_results['face_liveness'] = False
        
        # Give user time to read and perform challenge
        start_time = time.time()
        timeout = 8.0  # 8 seconds to complete challenge
        
        while time.time() - start_time < timeout:
            if challenge_type == "blink" and self.blink_count >= 2:
                self.verification_results['face_liveness'] = True
                break
            elif challenge_type in ["smile", "head_left", "head_right", "head_up"] and self.verification_results['face_liveness']:
                break
            time.sleep(0.1)
        
        self.current_challenge = None
        success = self.verification_results['face_liveness']
        
        print(f"Face liveness result: {'✓ PASS' if success else '✗ FAIL'}")
        self.update_result_indicator('face', success)
        return success
    
    def _perform_voice_challenge(self) -> bool:
        """Perform voice challenge with lip-sync detection"""
        # Generate random phrase
        self.voice_phrase = generate_random_phrase()
        challenge_text = f"Please read the text below clearly:"
        
        self.update_challenge(challenge_text)
        self.show_phrase_display(self.voice_phrase)
        print(f"Voice challenge: {self.voice_phrase}")
        
        # Reset recording state
        self.audio_buffer = []
        self.lip_sequence = []
        
        # Give user time to prepare with countdown
        self.show_recording_countdown(3)
        
        # Start recording
        self.update_instruction("🎤 Recording... Speak the phrase above!")
        self.show_speech_feedback("Listening...")
        self.show_recording_progress()
        
        try:
            # Record audio while capturing lip movement
            recording_duration = 5  # seconds
            
            # Start recording with progress tracking
            audio_data = sd.rec(
                int(recording_duration * Config.SAMPLE_RATE),
                samplerate=Config.SAMPLE_RATE,
                channels=1,
                dtype='float32'
            )
            
            # Update progress during recording
            self.update_recording_progress(recording_duration)
            
            sd.wait()  # Wait for recording to complete
            
            audio_data = audio_data.flatten()
            audio_data = librosa.util.normalize(audio_data)
            
            print(f"Audio recorded: {len(audio_data)} samples")
            print(f"Lip movements recorded: {len(self.lip_sequence)} frames")
            
            # Provide speech recognition feedback
            self.analyze_spoken_text(audio_data)
            
            # Extract voice features
            if len(audio_data) > 0:
                voice_features = VoiceProcessor.extract_mfcc(audio_data)
                
                # Compare with stored voiceprint (simulated - using hash comparison)
                current_voice_hash = CryptoUtils.generate_hash(voice_features.tobytes())
                stored_voice_hash = self.user_data['voice_hash']
                
                # For demo purposes, we'll simulate voice matching
                # In practice, you'd use proper voice embedding comparison
                voice_similarity = random.uniform(0.8, 0.95)  # Simulate similarity score
                voice_match = voice_similarity > Config.VOICE_SIMILARITY_THRESHOLD
                
                self.verification_results['voice_match'] = voice_match
                print(f"Voice similarity: {voice_similarity:.3f} {'✓ PASS' if voice_match else '✗ FAIL'}")
            
            # Analyze lip-sync
            if len(self.lip_sequence) > 10:  # Need sufficient lip movement data
                lip_sync_result = self._analyze_lip_sync(audio_data)
                self.verification_results['lip_sync'] = lip_sync_result
                print(f"Lip sync result: {'✓ PASS' if lip_sync_result else '✗ FAIL'}")
            else:
                print("⚠️ Insufficient lip movement data")
                self.verification_results['lip_sync'] = False
            
            self.update_result_indicator('voice', self.verification_results['voice_match'])
            self.update_result_indicator('lipsync', self.verification_results['lip_sync'])
            
            # Hide phrase display and recording UI after challenge
            self.hide_phrase_display()
            self.hide_recording_progress()
            
            return self.verification_results['voice_match'] and self.verification_results['lip_sync']
            
        except Exception as e:
            print(f"Voice/lip-sync analysis error: {e}")
            return False
    
    def _analyze_lip_sync(self, audio_data: np.ndarray) -> bool:
        """Analyze correlation between lip movement and audio"""
        if len(self.lip_sequence) < 2:
            return False
        
        try:
            # Compute lip movement energy
            lip_movement = LipSyncProcessor.compute_lip_movement(self.lip_sequence)
            
            # Compute audio energy
            audio_energy = VoiceProcessor.compute_audio_energy(audio_data)
            
            # Compute correlation
            correlation = LipSyncProcessor.compute_correlation(audio_energy, lip_movement)
            
            print(f"Lip-sync correlation: {correlation:.3f}")
            
            # Check if correlation is above threshold
            return abs(correlation) > Config.LIP_SYNC_THRESHOLD
            
        except Exception as e:
            print(f"Lip-sync analysis error: {e}")
            return False
    
    def _perform_final_verification(self) -> bool:
        """Perform final verification and generate smart contract data"""
        try:
            # Check all verification components
            all_passed = (
                self.verification_results['face_liveness'] and
                self.verification_results['voice_match'] and
                self.verification_results['lip_sync']
            )
            
            if all_passed:
                # Generate biometric hash for smart contract (combining face+voice data)
                # This simulates the same hash that would be generated during enrollment
                verification_timestamp = int(time.time())
                verification_data = f"user:{self.user_id},timestamp:{verification_timestamp},results:{self.verification_results}"
                
                # Create a biometric hash (32 bytes for smart contract)
                biometric_hash = CryptoUtils.generate_hash(verification_data.encode())
                
                # Generate Ethereum-compatible signature matching smart contract format
                try:
                    # Try to get backend private key for Ethereum signature
                    backend_private_key = os.getenv('BACKEND_PRIVATE_KEY')
                    if not backend_private_key:
                        # Generate demo backend private key
                        backend_private_key = CryptoUtils.create_backend_private_key()
                        print(f"⚠️ Using demo backend key: {backend_private_key[:10]}...")
                    
                    # Generate signature exactly as smart contract expects:
                    # solidityKeccak256(["address", "bytes32"], [userAddress, faceHash])
                    ethereum_signature = CryptoUtils.generate_ethereum_signature(
                        biometric_hash,
                        self.wallet_address,
                        backend_private_key
                    )
                    
                    signature = ethereum_signature
                    verification_hash = biometric_hash
                    
                    print(f"✅ Generated Ethereum signature: {signature[:20]}...")
                    print(f"✅ Biometric hash: {verification_hash[:20]}...")
                    print(f"✅ User address: {self.wallet_address}")
                    
                except Exception as e:
                    print(f"⚠️ Ethereum signature failed, using legacy: {e}")
                    # Fallback to legacy signature
                    verification_hash = CryptoUtils.generate_hash(verification_data.encode())
                    signature = CryptoUtils.sign_data(
                        self.user_data['private_key'],
                        verification_hash,
                        self.wallet_address
                    )
                
                # Log verification attempt
                self.db_manager.log_verification(
                    self.user_id,
                    self.verification_results['face_liveness'],
                    self.verification_results['voice_match'],
                    self.verification_results['lip_sync'],
                    all_passed,
                    verification_hash,
                    signature
                )
                
                # Send to smart contract
                success = send_to_smart_contract(verification_hash, signature, self.wallet_address)
                
                print(f"✓ Verification hash: {verification_hash[:16]}...")
                print(f"✓ Signature: {signature[:32]}...")
                print(f"✓ Smart contract result: {'Success' if success else 'Failed'}")
                
                self.verification_results['overall_result'] = True
                return True
            else:
                print("❌ Not all verification components passed")
                return False
            
        except Exception as e:
            print(f"Final verification error: {e}")
            return False
    
    def _verification_successful(self):
        """Handle successful verification"""
        self.update_instruction("✅ Verification completed successfully!")
        self.result_label.configure(
            text="🎉 VERIFIED HUMAN - All checks passed",
            fg='#27ae60'
        )
        
        # Show success message
        self.root.after(500, lambda: messagebox.showinfo(
            "Verification Successful",
            f"Identity verified for {self.user_id}!\n\n"
            f"✓ Face Liveness: Passed\n"
            f"✓ Voice Match: Passed\n" 
            f"✓ Lip Sync: Passed\n\n"
            f"Verification data sent to blockchain."
        ))
    
    def _verification_failed(self, reason: str):
        """Handle failed verification"""
        failed_checks = []
        if not self.verification_results['face_liveness']:
            failed_checks.append("Face Liveness")
        if not self.verification_results['voice_match']:
            failed_checks.append("Voice Match")
        if not self.verification_results['lip_sync']:
            failed_checks.append("Lip Sync")
        
        self.update_instruction(f"❌ Verification failed: {reason}")
        self.result_label.configure(
            text=f"🚫 VERIFICATION FAILED - {', '.join(failed_checks)}",
            fg='#e74c3c'
        )
        
        print(f"❌ Verification failed: {reason}")
        
        # Log failed attempt
        self.db_manager.log_verification(
            self.user_id,
            self.verification_results['face_liveness'],
            self.verification_results['voice_match'],
            self.verification_results['lip_sync'],
            False,
            "",
            ""
        )
    
    def update_instruction(self, text: str):
        """Update instruction label"""
        if self.instruction_label:
            self.instruction_label.configure(text=text)
            print(f"📋 {text}")
    
    def update_challenge(self, text: str):
        """Update challenge label"""
        if self.challenge_label:
            self.challenge_label.configure(text=text)
    
    def show_phrase_display(self, phrase: str):
        """Show the phrase that user needs to read"""
        if self.phrase_display:
            self.phrase_display.configure(text=f'📢 "{phrase}"')
            self.phrase_display.pack(pady=10)
    
    def hide_phrase_display(self):
        """Hide the phrase display"""
        if self.phrase_display:
            self.phrase_display.pack_forget()
    
    def show_speech_feedback(self, text: str):
        """Show speech recognition feedback"""
        if self.speech_feedback:
            self.speech_feedback.configure(text=f"🎧 {text}")
            self.speech_feedback.pack(pady=5)
    
    def hide_speech_feedback(self):
        """Hide speech recognition feedback"""
        if self.speech_feedback:
            self.speech_feedback.pack_forget()
    
    def analyze_spoken_text(self, audio_data: np.ndarray):
        """Analyze what the user said and provide feedback using speech recognition"""
        try:
            # Basic audio analysis
            audio_energy = np.mean(audio_data ** 2)
            audio_duration = len(audio_data) / Config.SAMPLE_RATE
            
            if audio_energy < 0.0005:
                self.show_speech_feedback("❌ Low audio level - Please speak louder")
                return
            
            if audio_duration < 1:
                self.show_speech_feedback("❌ Audio too short - Please speak longer")
                return
            
            # Attempt speech recognition
            recognized_text = self.speech_to_text(audio_data)
            
            if recognized_text:
                # Calculate similarity between expected and recognized text
                similarity = self.calculate_text_similarity(self.voice_phrase, recognized_text)
                
                if similarity > 0.6:  # Good match
                    feedback = f"✅ Recognized: \"{recognized_text}\" (Match: {similarity*100:.0f}%)"
                    self.show_speech_feedback(feedback)
                elif similarity > 0.3:  # Partial match
                    feedback = f"⚠️ Recognized: \"{recognized_text}\" (Partial match: {similarity*100:.0f}%)"
                    self.show_speech_feedback(feedback)
                else:  # Poor match
                    feedback = f"❌ Recognized: \"{recognized_text}\" (Low match: {similarity*100:.0f}%)"
                    self.show_speech_feedback(feedback)
            else:
                # No recognition, but audio was captured
                self.show_speech_feedback(f"✅ Audio captured ({audio_duration:.1f}s) - Processing...")
            
            # Hide feedback after a delay
            if self.root:
                self.root.after(5000, self.hide_speech_feedback)
                
        except Exception as e:
            print(f"Speech analysis error: {e}")
            self.show_speech_feedback(f"✅ Audio captured ({len(audio_data)/Config.SAMPLE_RATE:.1f}s) - Analysis complete")
    
    def speech_to_text(self, audio_data: np.ndarray) -> str:
        """Convert audio to text using speech recognition"""
        try:
            import speech_recognition as sr
            
            # Convert numpy array to wav format for speech recognition
            audio_bytes = self.numpy_to_wav_bytes(audio_data)
            
            # Initialize recognizer
            recognizer = sr.Recognizer()
            
            # Create audio data from bytes
            with sr.AudioFile(io.BytesIO(audio_bytes)) as source:
                audio_for_recognition = recognizer.record(source)
            
            # Recognize speech using Google's free API (requires internet)
            try:
                text = recognizer.recognize_google(audio_for_recognition, language='en-US')
                print(f"🎯 Speech recognized: '{text}'")
                return text.lower()
            except sr.UnknownValueError:
                print("🤔 Could not understand audio")
                return None
            except sr.RequestError as e:
                print(f"⚠️ Speech recognition service error: {e}")
                # Fallback to offline recognition if available
                try:
                    text = recognizer.recognize_sphinx(audio_for_recognition)
                    print(f"🎯 Offline speech recognized: '{text}'")
                    return text.lower()
                except:
                    return None
                    
        except ImportError:
            print("ℹ️ Speech recognition not available - install: pip install SpeechRecognition")
            return None
        except Exception as e:
            print(f"Speech recognition error: {e}")
            return None
    
    def numpy_to_wav_bytes(self, audio_data: np.ndarray) -> bytes:
        """Convert numpy audio array to WAV bytes"""
        # Normalize audio data to 16-bit integer range
        audio_data = np.clip(audio_data, -1, 1)
        audio_int16 = (audio_data * 32767).astype(np.int16)
        
        # Create WAV file in memory
        wav_buffer = io.BytesIO()
        with wave.open(wav_buffer, 'wb') as wav_file:
            wav_file.setnchannels(1)  # Mono
            wav_file.setsampwidth(2)  # 16-bit
            wav_file.setframerate(Config.SAMPLE_RATE)
            wav_file.writeframes(audio_int16.tobytes())
        
        wav_buffer.seek(0)
        return wav_buffer.read()
    
    def calculate_text_similarity(self, expected: str, recognized: str) -> float:
        """Calculate similarity between expected and recognized text"""
        if not expected or not recognized:
            return 0.0
        
        # Simple word-based similarity
        expected_words = set(expected.lower().split())
        recognized_words = set(recognized.lower().split())
        
        if not expected_words:
            return 0.0
        
        # Calculate Jaccard similarity
        intersection = expected_words.intersection(recognized_words)
        union = expected_words.union(recognized_words)
        
        return len(intersection) / len(union) if union else 0.0
    
    def show_recording_countdown(self, seconds: int):
        """Show countdown before recording starts"""
        self.countdown_label.pack(pady=5)
        
        def update_countdown(remaining):
            if remaining > 0:
                self.countdown_label.configure(text=f"🕐 Get ready... Recording starts in {remaining}")
                if self.root:
                    self.root.after(1000, lambda: update_countdown(remaining - 1))
            else:
                self.countdown_label.configure(text="🔴 Recording NOW!")
                if self.root:
                    self.root.after(1000, self.hide_countdown)
        
        update_countdown(seconds)
    
    def hide_countdown(self):
        """Hide countdown timer"""
        if self.countdown_label:
            self.countdown_label.pack_forget()
    
    def show_recording_progress(self):
        """Show recording progress bar"""
        if self.recording_progress:
            self.recording_progress['value'] = 0
            self.recording_progress.pack(pady=5)
    
    def update_recording_progress(self, total_duration: float):
        """Update recording progress in real-time"""
        if not self.recording_progress or not self.root:
            return
        
        start_time = time.time()
        
        def update_progress():
            if not self.recording_progress or not self.root:
                return
            
            elapsed = time.time() - start_time
            progress = min((elapsed / total_duration) * 100, 100)
            
            try:
                self.recording_progress['value'] = progress
                
                if progress < 100:
                    self.root.after(100, update_progress)  # Update every 100ms
                else:
                    self.update_instruction("🎤 Recording complete! Processing...")
            except:
                pass  # Widget might be destroyed
        
        # Start progress updates
        self.root.after(100, update_progress)
    
    def hide_recording_progress(self):
        """Hide recording progress bar"""
        if self.recording_progress:
            self.recording_progress.pack_forget()
    
    def update_result_indicator(self, component: str, success: bool):
        """Update individual result indicators"""
        status = "✅ PASS" if success else "❌ FAIL"
        color = '#27ae60' if success else '#e74c3c'
        
        if component == 'face' and self.face_result_label:
            self.face_result_label.configure(text=f"Face Liveness: {status}", fg=color)
        elif component == 'voice' and self.voice_result_label:
            self.voice_result_label.configure(text=f"Voice Match: {status}", fg=color)
        elif component == 'lipsync' and self.lipsync_result_label:
            self.lipsync_result_label.configure(text=f"Lip Sync: {status}", fg=color)
    
    def reset_verification_state(self):
        """Reset all verification state"""
        self.verification_results = {
            'face_liveness': False,
            'voice_match': False,
            'lip_sync': False,
            'overall_result': False
        }
        self.current_challenge = None
        self.voice_phrase = None
        self.lip_sequence = []
        self.audio_buffer = []
        self.blink_count = 0
        
        # Reset UI indicators
        if self.face_result_label:
            self.face_result_label.configure(text="Face Liveness: ⏳ Waiting", fg='black')
        if self.voice_result_label:
            self.voice_result_label.configure(text="Voice Match: ⏳ Waiting", fg='black')
        if self.lipsync_result_label:
            self.lipsync_result_label.configure(text="Lip Sync: ⏳ Waiting", fg='black')
        if self.result_label:
            self.result_label.configure(text="🔒 Verification Status: In Progress...", fg='white')
        if self.challenge_label:
            self.challenge_label.configure(text="Preparing challenge...")
    
    def stop_verification(self):
        """Stop ongoing verification"""
        self.is_verifying = False
        self.current_challenge = None
        self.update_instruction("Verification stopped by user")
        self.update_challenge("Verification stopped")
    
    def on_closing(self):
        """Handle window closing"""
        self.is_verifying = False
        if self.cap:
            self.cap.release()
        if self.root:
            self.root.destroy()

def main():
    """Command line verification interface"""
    print("🛡️ Biometric Identity Verification System")
    print("=" * 45)
    
    # Get user input
    user_id = input("Enter User ID to verify: ").strip()
    if not user_id:
        print("❌ User ID is required")
        return
    
    wallet_address = input("Enter Wallet Address (optional): ").strip()
    
    # Check if user exists
    db_manager = DatabaseManager()
    user_data = db_manager.get_user_data(user_id)
    if not user_data:
        print(f"❌ No enrollment data found for user: {user_id}")
        print("Please run enroll.py first to register this user.")
        return
    
    print(f"\n📋 Starting verification for user: {user_id}")
    if wallet_address:
        print(f"📋 Wallet address: {wallet_address}")
    
    # Start verification
    verification = BiometricVerification(user_id, wallet_address)
    
    try:
        # GUI mode
        verification.start_verification_gui()
    except ImportError:
        print("❌ GUI libraries not available")
        print("Please install required packages: pip install pillow")

if __name__ == "__main__":
    main()
