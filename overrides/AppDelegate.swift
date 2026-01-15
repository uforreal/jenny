import UIKit
import Flutter
import AVFoundation
import AudioToolbox

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
    var engine: AVAudioEngine!
    var playerNode: AVAudioPlayerNode!
    var eqNode: AVAudioUnitEQ!
    var pitchNode: AVAudioUnitTimePitch!
    var distortionNode: AVAudioUnitDistortion!
    var dynamicsNode: AVFoundation.AVAudioUnitDynamicsProcessor!
    var reverbNode: AVAudioUnitReverb!
    
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
            try session.setCategory(.playback, mode: .videoChat, options: [.mixWithOthers, .duckOthers, .defaultToSpeaker])
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
        distortionNode = AVAudioUnitDistortion()
        dynamicsNode = AVFoundation.AVAudioUnitDynamicsProcessor()
        reverbNode = AVAudioUnitReverb()
        
        // --- DSP Settings: "Human Presence" Profile ---
        
        // 1. HARMONIC DENSITY
        distortionNode.preGain = 2.0
        distortionNode.wetDryMix = 8.0 
        
        // 2. EQUALIZATION
        let band1 = eqNode.bands[0]
        band1.filterType = .parametric
        band1.frequency = 250.0
        band1.bandwidth = 1.0
        band1.gain = 2.5 
        
        let band2 = eqNode.bands[1]
        band2.filterType = .parametric
        band2.frequency = 2800.0
        band2.bandwidth = 0.8
        band2.gain = 3.5 
        
        let band3 = eqNode.bands[2]
        band3.filterType = .highShelf
        band3.frequency = 8500.0
        band3.gain = 1.5 
        
        // 3. SPATIAL GLUE (The "Vacuum" Fix)
        // A very subtle reverb to simulate a physical room.
        reverbNode.loadFactoryPreset(.smallRoom)
        reverbNode.wetDryMix = 7.0 // Barely there tail
        
        // 4. GLUE COMPRESSION
        dynamicsNode.threshold = -24.0
        dynamicsNode.headroom = 4.0
        dynamicsNode.expansionRatio = 3.0
        dynamicsNode.masterGain = 2.0 
        
        // 5. PITCH & RATE
        pitchNode.pitch = -0.5
        pitchNode.rate = 1.04 
        
        // Attach Nodes
        engine.attach(playerNode)
        engine.attach(pitchNode)
        engine.attach(distortionNode)
        engine.attach(eqNode)
        engine.attach(reverbNode)
        engine.attach(dynamicsNode)
        
        // Connect Chain: Player -> Pitch -> Distortion -> EQ -> Reverb -> Dynamics -> Output
        engine.connect(playerNode, to: pitchNode, format: format)
        engine.connect(pitchNode, to: distortionNode, format: format)
        engine.connect(distortionNode, to: eqNode, format: format)
        engine.connect(eqNode, to: reverbNode, format: format)
        engine.connect(reverbNode, to: dynamicsNode, format: format)
        engine.connect(dynamicsNode, to: engine.mainMixerNode, format: format)
        
        playerNode.volume = 1.0
        engine.mainMixerNode.outputVolume = 1.0
        
        do {
            engine.prepare()
            try engine.start()
            isEngineSetup = true
            print("Jenny Engine: 'Human Presence' active")
        } catch {
            print("Jenny Engine: Start Error: \(error)")
        }
    }
    
    func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        if let voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.samantha-premium") {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        if #available(iOS 13.0, *) {
            synthesizer.write(utterance) { [weak self] (buffer: AVAudioBuffer) in
                guard let self = self, let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }
                
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
}
