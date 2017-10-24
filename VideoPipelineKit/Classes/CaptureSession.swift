//
//  CaptureSession.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 10/24/17.
//

import AVKit

public class CaptureSession {
    public var automaticallyConfiguresApplicationAudioSession = true

    public var running: Bool = false {
        didSet {
            guard running != oldValue else { return }

            if running {
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

    lazy var videoCaptureSession: AVCaptureSession = {
        let videoCaptureSession = AVCaptureSession()
        videoCaptureSession.automaticallyConfiguresApplicationAudioSession = false

        if let builtInCamera = self.videoDeviceDiscoverySession?.devices.first {
            do {
                let buitInCameraInput = try AVCaptureDeviceInput(device: builtInCamera)
                videoCaptureSession.addInput(buitInCameraInput)
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

    public func startRecording() throws {
        if automaticallyConfiguresApplicationAudioSession {
            if AVAudioSession.sharedInstance().isOtherAudioPlaying {
                try AVAudioSession.sharedInstance().setActive(false, with: .notifyOthersOnDeactivation)
            }
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: [.mixWithOthers, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
            try AVAudioSession.sharedInstance().setActive(true)
        }

        audioCaptureSession.startRunning()

        let recordingSession = try currentRecordingSession ?? initializeRecordingSession()
        recordingSession.start(transform: transform)
    }

    public func stopRecording(completionHandler handler: @escaping () -> Swift.Void) {
        if let recordingSession = currentRecordingSession {
            recordingSession.finish(completionHandler: handler)
        }

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
