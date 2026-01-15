import UIKit
import Flutter
import AVFoundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
    var engine: AVAudioEngine!
    var playerNode: AVAudioPlayerNode!
    var eqNode: AVAudioUnitEQ!
    var pitchNode: AVAudioUnitTimePitch!
    
    let synthesizer = AVSpeechSynthesizer()
    var isEngineSetup = false
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        setupAudioSession()
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(name: "com.uforreal.jenny/audio",
                                           binaryMessenger: controller.binaryMessenger)
        
        channel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if call.method == "speak" {
                if let args = call.arguments as? [String: Any],
                   let text = args["text"] as? String {
                    self?.speak(text: text)
                    result(nil)
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        })
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .voicePrompt, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            print("Jenny Audio Session Error: \(error)")
        }
    }
    
    func setupEngine(with format: AVAudioFormat) {
        if isEngineSetup { return }
        
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        eqNode = AVAudioUnitEQ(numberOfBands: 3)
        pitchNode = AVAudioUnitTimePitch()
        
        // --- DSP Settings: "Clarity & Snap" Profile ---
        
        // 1. Subtle Warmth (Not Muddy) - 250Hz
        let band1 = eqNode.bands[0]
        band1.filterType = .parametric
        band1.frequency = 250.0
        band1.bandwidth = 1.5
        band1.gain = 2.0 // Gentle warmth, not boomy
        band1.bypass = false
        
        // 2. Presence Restoration - 2500Hz (The "Clarity" Zone)
        let band2 = eqNode.bands[1]
        band2.filterType = .parametric
        band2.frequency = 2500.0
        band2.bandwidth = 1.0
        band2.gain = 3.0 // Brings voice forward, adds intelligibility
        band2.bypass = false
        
        // 3. Breath/Air (The "S" sounds) - 8000Hz
        let band3 = eqNode.bands[2]
        band3.filterType = .highShelf
        band3.frequency = 8000.0
        band3.gain = 2.0 // Subtle air, not harsh
        band3.bypass = false
        
        // No pitch manipulation - keep it natural
        pitchNode.pitch = 0.0
        // Slight speed increase for natural human rhythm
        pitchNode.rate = 1.03
        
        engine.attach(playerNode)
        engine.attach(eqNode)
        engine.attach(pitchNode)
        
        // Connect Chain
        engine.connect(playerNode, to: pitchNode, format: format)
        engine.connect(pitchNode, to: eqNode, format: format)
        engine.connect(eqNode, to: engine.mainMixerNode, format: format)
        
        // Ensure volume is up
        playerNode.volume = 1.0
        engine.mainMixerNode.outputVolume = 1.0
        
        do {
            engine.prepare()
            try engine.start()
            isEngineSetup = true
            print("Jenny Engine: Started successfully")
        } catch {
            print("Jenny Engine: Start Error: \(error)")
        }
    }
    
    func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        // Try to get a high-quality voice if available
        if let voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.samantha-premium") {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        // --- EMOTION DETECTION & DSP PRESET ---
        let emotion = detectEmotion(from: text)
        humanizer.applyEmotion(preset: emotion)
        print("Jenny: Emotion detected -> \(emotion)")

        if #available(iOS 13.0, *) {
            synthesizer.write(utterance) { [weak self] (buffer: AVAudioBuffer) in
                guard let self = self, let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }
                
                // --- HUMANIZER DSP INJECTION ---
                // Process the buffer in-place to add shimmer, jitter, breath, and warmth
                self.humanizer.process(buffer: pcmBuffer)
                
                DispatchQueue.main.async {
                    if !self.isEngineSetup {
                        self.setupEngine(with: pcmBuffer.format)
                    }
                    
                    guard self.isEngineSetup else { return }
                    
                    self.playerNode.scheduleBuffer(pcmBuffer, at: nil, options: [], completionHandler: nil)
                    
                    if !self.playerNode.isPlaying {
                        self.playerNode.play()
                    }
                }
            }
        } else {
            synthesizer.speak(utterance)
        }
    }
    
    // --- EMOTION LOGIC ---
    func detectEmotion(from text: String) -> String {
        let t = text.lowercased()
        if t.contains("!") || t.contains("wow") || t.contains("amazing") || t.contains("yes") {
            return "excited"
        } else if t.contains("sorry") || t.contains("sad") || t.contains("unfortunately") {
            return "warm" // Use warm for empathetic/sad
        } else if t.contains("relax") || t.contains("deep breath") || t.contains("calm") {
            return "calm"
        } else if t.contains("important") || t.contains("listen") || t.contains("focus") {
            return "serious"
        }
        return "neutral"
    }
    
    private let humanizer = HumanizerDSP()
}

// --- HUMANIZER DSP ENGINE ---
class HumanizerDSP {
    // Parameters (Default: Neutral)
    var shimmerDepth: Float = 0.0
    var jitterDepth: Float = 0.0
    var jitterSpeed: Float = 5.0
    var breathiness: Float = 0.0
    var warmthDrive: Float = 1.0
    
    // State
    private var phaseShimmer: Float = 0
    private var phaseJitter: Float = 0
    private var phaseDrift: Float = 0
    private var delayBuffer: [Float] = Array(repeating: 0, count: 4096)
    private var delayHead: Int = 0
    private var lastNoise: Float = 0
    
    func applyEmotion(preset: String) {
        switch preset {
        case "warm":
            shimmerDepth = 0.08
            jitterDepth = 0.015
            jitterSpeed = 4.0
            breathiness = 0.05
            warmthDrive = 1.5
        case "excited":
            shimmerDepth = 0.12
            jitterDepth = 0.025
            jitterSpeed = 6.0
            breathiness = 0.02
            warmthDrive = 1.4
        case "calm":
            shimmerDepth = 0.04
            jitterDepth = 0.008
            jitterSpeed = 3.0
            breathiness = 0.04
            warmthDrive = 1.3
        case "serious":
            shimmerDepth = 0.02
            jitterDepth = 0.005
            jitterSpeed = 5.0
            breathiness = 0.01
            warmthDrive = 1.2
        default: // Neutral
            shimmerDepth = 0.06 // +/- 6%
            jitterDepth = 0.015 // +/- 1.5%
            jitterSpeed = 5.0
            breathiness = 0.03
            warmthDrive = 1.4
        }
    }
    
    func process(buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)
        
        // Constants for modulation
        let shimmerFreq: Float = 8.0
        let driftFreq: Float = 0.3
        let twoPi = 2.0 * Float.pi
        
        for frame in 0..<frameCount {
            // Update Phases
            phaseShimmer += (twoPi * shimmerFreq) / sampleRate
            if phaseShimmer > twoPi { phaseShimmer -= twoPi }
            
            phaseJitter += (twoPi * jitterSpeed) / sampleRate
            if phaseJitter > twoPi { phaseJitter -= twoPi }
            
            phaseDrift += (twoPi * driftFreq) / sampleRate
            if phaseDrift > twoPi { phaseDrift -= twoPi }
            
            // 1. Shimmer (Amplitude Wobble)
            // Sine (8Hz) +/- Depth + Random +/- 3%
            let sineShimmer = sin(phaseShimmer) * shimmerDepth
            let randShimmer = Float.random(in: -0.03...0.03)
            let ampMod = 1.0 + sineShimmer + randShimmer
            
            // 2. Jitter (Pitch Wobble) -> Delay Modulation
            // Sine +/- Depth + Drift +/- 0.8% + Random +/- 0.5%
            // Depth 1.5% means 0.015 modulation.
            // Target delay modulation in samples. ~22 samples @ 44.1k for 1.5% pitch shift at 5Hz.
            let pitchModScaler: Float = 25.0 // Hand-tuned for audible but subtle drift
            let jitterSig = (sin(phaseJitter) * jitterDepth) + (sin(phaseDrift) * 0.008) + Float.random(in: -0.005...0.005)
            let delayMod = jitterSig * pitchModScaler
            let targetDelay = 200.0 + delayMod // Base delay 200 samples (~4.5ms)
            
            // 3. Breathiness (LPF Noise)
            // Simple 1-pole LPF approx 3000Hz (Alpha ~0.3 at 44.1k)
            let rawNoise = Float.random(in: -1.0...1.0)
            let lpfAlpha: Float = 0.3
            let filteredNoise = lastNoise + lpfAlpha * (rawNoise - lastNoise)
            lastNoise = filteredNoise
            
            // Apply to all channels
            for channel in 0..<channelCount {
                let pData = data[channel]
                let cleanSample = pData[frame]
                
                // Write to delay buffer for Jitter
                // (Simple mono delay logic replicated for channels to keep phase coherent or independent?
                //  Let's share buffer state index but maintain separate buffer arrays if stereo...
                //  For simplicity/performance in this block, we'll use one buffer for Voice Prompt (usually Mono).
                //  If stereo, we mix or just process ch0. Let's assume Mono for TTS usually.)
                
                // Safety clamp
                if delayHead >= delayBuffer.count { delayHead = 0 }
                delayBuffer[delayHead] = cleanSample
                
                // Read from Delay (Linear Interpolation)
                var readPos = Float(delayHead) - targetDelay
                if readPos < 0 { readPos += Float(delayBuffer.count) }
                
                let readIdxA = Int(readPos)
                let readIdxB = (readIdxA + 1) % delayBuffer.count
                let frac = readPos - Float(readIdxA)
                
                let delayedSample = delayBuffer[readIdxA] * (1.0 - frac) + delayBuffer[readIdxB] * frac
                
                // Apply Shimmer
                var processed = delayedSample * ampMod
                
                // Apply Breathiness (Gated by signal energy to avoid noise in silence)
                // Rudimentary gate: if sample is loud enough
                if abs(processed) > 0.01 {
                    processed += filteredNoise * breathiness
                }
                
                // 4. Warmth (Soft Saturation)
                // (2/pi) * atan(x * drive)
                processed = (2.0 / Float.pi) * atan(processed * warmthDrive)
                
                pData[frame] = processed
            }
            
            delayHead += 1
            if delayHead >= delayBuffer.count { delayHead = 0 }
        }
    }
}
