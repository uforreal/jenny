# Project Axon: "Jenny" Voice Agent - Evolutionary Log

**Date:** January 15, 2026
**Status:** Method A (Local Native DSP) - "Clarity & Snap" Profile Restored

---

## 1. The Core Objective

The goal is to create a voice agent ("Jenny") for iOS that bypasses standard "robotic" TTS playback to achieve a "human-like" presence. running primarily on-device using a custom "Audio Hijack" technique.

---

## 2. The Build Strategy (The "Axon" Method)

**Problem:** Standard Flutter builds fail reliably on GitHub Actions because Xcode eventually demands signing identities.
**Solution:** We implemented the "Axon" build strategy from the `axon-voice-bridge` repository analysis.

- **Technique:** Manual `xcodebuild` invocation with aggressive overrides.
- **Key Flags:** `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, `CODE_SIGN_IDENTITY=""`.
- **Artifacts:** We manually construct the `Payload` folder structure and zip it into an IPA.
- **Result:** A reproducible "Unsigned IPA" that can be installed via ESign/TrollStore.

---

## 3. The Audio Strategy (Method A: Native Bridge)

**Pivot:** We abandoned `flutter_tts` for a direct `AVAudioEngine` pipeline using `AVSpeechSynthesizer.write()`.

### The DSP Chains

#### **Iteration 1-3 (Experimental/Deprecated)**
- Iteration 1: "The Radio Host" (Failed)
- Iteration 3: "Human Presence" (Rejected) - Included excessive harmonic grit and spatial reverb that compromised clarity.

#### **Iteration 4: "Clarity & Snap" (Base Profile)**
- **Philosophy:** Human speech is mid-forward. Tuned EQ (250Hz, 2.5kHz, 8kHz) and neutral pitch.
- **Status:** Active as the foundation.

#### **Iteration 5: "The Humanizer" (Current)**
- **Goal:** Break the robotic "perfect stability" of the TTS engine.
- **Technique:** Custom real-time DSP interacting directly with the PCM buffer.
- **Layers:**
  1.  **Shimmer (Amplitude Wobble):** 8Hz sine modulation to mimic unsteady lung pressure.
  2.  **Jitter (Pitch Wobble):** Variable delay line (5Hz) to simulate vocal cord micro-instabilities.
  3.  **Breathiness:** Injection of low-pass filtered noise (3kHz) when voice is active.
  4.  **Warmth:** Soft saturation (`atan`) to add harmonic richness.
- **Dynamic Emotion:** Auto-detects text sentiment ("Excited", "Sad", "Serious") and adjusts DSP parameters on the fly.

---

## 4. Technical Hurdles & Fixes (Historical)
1. **Compilation Crash:** Fixed via `import AudioToolbox` (Reverted in current stable).
2. **Silence Bug:** Fixed via sequential buffer scheduling.

---

**Restored to Stable Handoff State**
