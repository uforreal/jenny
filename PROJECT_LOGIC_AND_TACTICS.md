# Project Axon: "Jenny" Voice Agent - Evolutionary Log

**Date:** January 15, 2026
**Status:** Method A (Local Native DSP) - "Clarity & Snap" Profile Active

---

## 1. The Core Objective

The goal is to create a voice agent ("Jenny") for iOS that bypasses standard "robotic" TTS playback to achieve a "human-like" presence similar to Microsoft's Neural Jenny or the referenced YouTube demo. The constraint is to do this without a complex backend (for now), running primarily on-device using a custom "Audio Hijack" technique.

---

## 2. The Build Strategy (The "Axon" Method)

**Problem:** Standard Flutter builds (`flutter build ios --no-codesign`) fail reliably on GitHub Actions because Xcode eventually demands signing identities.
**Solution:** We implemented the "Axon" build strategy derived from the `axon-voice-bridge` repository analysis.

- **Technique:** Manual `xcodebuild` invocation with aggressive overrides.
- **Key Flags:** `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, `CODE_SIGN_IDENTITY=""`.
- **Artifacts:** We manually construct the `Payload` folder structure and zip it into an IPA, bypassing the `xcarchive` process entirely.
- **Result:** A reproducible "Unsigned IPA" that can be installed via ESign/TrollStore without a developer account.

---

## 3. The Audio Strategy (Method A: Native Bridge)

**Pivot:** We abandoned `flutter_tts` because it only offers standard playback APIs.
**New Architecture:**

1.  **Flutter Side:** Sends text via MethodChannel `com.uforreal.jenny/audio`.
2.  **Swift Side:** We do _not_ play the text directly. We use `AVSpeechSynthesizer.write()` to intercept the raw PCM audio buffer.
3.  **The Hijack:** This buffer is fed into a custom `AVAudioEngine` pipeline before touching the speakers. This allows for Real-time Digital Signal Processing (DSP).

### The DSP Chains (Evolution of Sound)

#### **Iteration 1: "The Radio Host" (Failed)**

- **Profile:** Heavy V-Shape EQ.
- **Settings:** +6dB at 300Hz (Chest), -4dB at 900Hz (Cut), +4dB at 5000Hz (Air).
- **Result:** "Uncanny Valley." Sounded muddy, hollow, and robotic. The low-end boost overwhelmed the tiny iPhone speakers.

#### **Iteration 2: "Clarity & Snap" (Deprecated)**

- **Philosophy:** Human speech is mid-forward, not bass-heavy. We need presence, not mud.
- **Node 1 (Warmth):** Frequency **250Hz**, Gain **+2.0dB**, Width **1.5**. (Gentle warmth, no mud).
- **Node 2 (Presence):** Frequency **2500Hz**, Gain **+3.0dB**, Width **1.0**. (Brings the voice "forward" out of the device).
- **Node 3 (Air):** Frequency **8000Hz**, Gain **+2.0dB**. (Targeting "S" sounds and breath, rather than general hiss).
- **Pitch/Rate:** Pitch **0 (Neutral)**, Rate **1.03** (Subtle snap/intelligence).
- **Dynamics:** Compressor enabled to level out the volume, creating intimacy.

#### **Iteration 3: "Human Presence" (Current/Success)**

- **Philosophy:** Kill the "Clean Computer" vibe. Add harmonic grit and acoustic density to mimic physical vocal cords and air.
- **Node 0 (Texture):** `AVAudioUnitDistortion`. PreGain **2.0**, Wet/Dry **8%**. (Adds harmonic saturation/grit).
- **Node 1 (Resonance):** `AVAudioUnitEQ`. Frequency **250Hz**, Gain **+2.5dB**. (Chest resonance).
- **Node 2 (Intelligence):** `AVAudioUnitEQ`. Frequency **2800Hz**, Gain **+3.5dB**. (Targeted ear sensitivity zone).
- **Node 3 (Air):** `AVAudioUnitEQ`. Frequency **8500Hz**, Gain **+1.5dB**. (High-end air).
- **Node 4 (The Glue):** `AVAudioUnitDynamicsProcessor`. Threshold **-24dB**, Headroom **4dB**, Master Gain **2dB**. (Dense, intimate "broadcast" sound).
- **Pitch/Rate:** Pitch **-0.5** (Subtle depth), Rate **1.04** (Intelligent pacing).

---

## 4. Technical Hurdles & Fixes

1.  **The Compilation Crash:**
    - _Issue:_ `AVAudioUnitDynamicsProcessor` not found in scope.
    - _Fix:_ Added `import AudioToolbox` and fully qualified `AVFoundation.AVAudioUnitDynamicsProcessor`.
2.  **The Silence Bug:**
    - _Issue:_ Packets were canceling each other out because we used `.interrupts` scheduling.
    - _Fix:_ Removed `.interrupts` flag to allow sequential queuing of audio buffers. Added explicit volume forcing.
3.  **The Android Crash:**
    - _Issue:_ `flutter_launcher_icons` tried to build Android icons for an iOS-only project.
    - _Fix:_ Explicitly disabled Android in `pubspec.yaml`.

---

## 5. Next Steps (Roadmap)

1.  **Breath Injection:** Manually play a 100ms "breath" sample before the TTS buffer starts to trick the brain into hearing a human.
2.  **Reverb Layer:** Add an `AVAudioUnitReverb` (Small Room, 2% Wet) to remove the "digital vacuum" silence.
3.  **Method B (The Endgame):** Transition from local iOS synthesis to streaming Azure/ElevenLabs Neural PCM data through the existing Axon WebSocket bridge for 100% human emotive prosody.

---

**Saved by Antigravity**
