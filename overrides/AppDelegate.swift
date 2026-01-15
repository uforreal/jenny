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
        
        // Neural voices usually have a different pitch/rate profile, we'll keep it standard
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        if #available(iOS 13.0, *) {
            synthesizer.write(utterance) { [weak self] (buffer: AVAudioBuffer) in
                guard let self = self, let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }
                
                DispatchQueue.main.async {
                    if !self.isEngineSetup {
                        self.setupEngine(with: pcmBuffer.format)
                    }
                    
                    guard self.isEngineSetup else { return }
                    
                    // CRITICAL: Removed .interrupts. This allows buffers to queue sequentially.
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
}
