//
//  CaptureSession.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 10/24/17.
//

import AVKit

public class CaptureSession {
    
    public var audioEnabled = true
    
    public var automaticallyConfiguresApplicationAudioSession = true

    public var isRunning: Bool = false {
        didSet {
            guard isRunning != oldValue else { return }

            if isRunning {
                videoCaptureSession.startRunning()
            } else {
                videoCaptureSession.stopRunning()
            }
        }
    }

    let renderPipeline: RenderPipeline

    public init(renderPipeline: RenderPipeline) {
        self.renderPipeline = renderPipeline
    }

    // MARK: - Capture

    let audioDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone], mediaType: AVMediaTypeAudio, position: .unspecified)

    let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: .unspecified)
    
    public lazy var currentVideoDevice: AVCaptureDevice? = {
        return self.videoDeviceDiscoverySession?.devices.first
    }()
    
    public var videoDevices: [AVCaptureDevice] {
        return self.videoDeviceDiscoverySession?.devices ?? [AVCaptureDevice]()
    }

    lazy var audioCaptureSession: AVCaptureSession = {
        let audioCaptureSession = AVCaptureSession()
        audioCaptureSession.automaticallyConfiguresApplicationAudioSession = false

        if let builtInMicrophone = self.audioDeviceDiscoverySession?.devices.first {
            do {
                let builtInMicrophoneInput = try AVCaptureDeviceInput(device: builtInMicrophone)
                audioCaptureSession.addInput(builtInMicrophoneInput)
            } catch {
                print("Error adding microphone: \(error)")
            }
        }

        return audioCaptureSession
    }()

    private(set) public lazy var videoCaptureSession: AVCaptureSession = {
        let videoCaptureSession = AVCaptureSession()
        videoCaptureSession.automaticallyConfiguresApplicationAudioSession = false

        if let currentVideoDevice = self.currentVideoDevice {
            do {
                let currentVideoDeviceInput = try AVCaptureDeviceInput(device: currentVideoDevice)
                videoCaptureSession.addInput(currentVideoDeviceInput)
            } catch {
                print("Error adding camera: \(error)")
            }
        }

        return videoCaptureSession
    }()

    public lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        let previewLayer = AVCaptureVideoPreviewLayer(session: self.videoCaptureSession)
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        return previewLayer
    }()

    var transform: CGAffineTransform {
        var transform = CGAffineTransform.identity.rotated(by: -CGFloat.pi / 2)

        if self.videoDeviceDiscoverySession?.devices.first?.position == .front {
            transform = transform.scaledBy(x: -1, y: 0)
        }

        return transform
    }

    var audioSession = AVAudioSession.sharedInstance()
    
    public func prepare() throws {
        try initializeRecordingSession()
    }
    
    public func unprepare() {
        
    }

    // MARK: - Recording

    var currentRecordingSession: RecordingSession?

    public var outputURL: URL? {
        return currentRecordingSession?.outputURL
    }

    func initializeRecordingSession() throws -> RecordingSession {
        currentRecordingSession?.cleanup()

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        let recordingSession = try RecordingSession(captureSessions: [self.audioCaptureSession, self.videoCaptureSession], renderPipeline: renderPipeline, outputURL: url)
        currentRecordingSession = recordingSession
        return recordingSession
    }
    
    public var isRecording: Bool {
        return (currentRecordingSession?.state == .recording) ?? false
    }

    public func startRecording() throws {
        if currentRecordingSession?.state == .finished {
            currentRecordingSession = nil
        }

        if audioEnabled {
            if automaticallyConfiguresApplicationAudioSession {
                if AVAudioSession.sharedInstance().isOtherAudioPlaying {
                    try AVAudioSession.sharedInstance().setActive(false, with: .notifyOthersOnDeactivation)
                }
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: [.mixWithOthers, .defaultToSpeaker])
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
                try AVAudioSession.sharedInstance().setActive(true)
            }
            
            audioCaptureSession.startRunning()
        }

        let recordingSession = try currentRecordingSession ?? initializeRecordingSession()
        recordingSession.start(transform: transform)
    }

    public func stopRecording(completionHandler handler: @escaping () -> Swift.Void) {
        if let recordingSession = currentRecordingSession {
            recordingSession.finish(completionHandler: handler)
        }
        
        if audioEnabled {
            audioCaptureSession.stopRunning()
            
            if automaticallyConfiguresApplicationAudioSession {
                do {
                    try audioSession.setActive(false, with: .notifyOthersOnDeactivation)
                    try audioSession.setCategory(AVAudioSessionCategoryAmbient)
                    try audioSession.overrideOutputAudioPort(.none)
                } catch {
                    print("Error switching audio: \(error)")
                }
            }
        }
    }
}
