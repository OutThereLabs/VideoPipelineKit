//
//  CaptureSession.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 10/24/17.
//

import AVKit

public class CaptureSession {

    public var photoFlashMode = AVCaptureDevice.FlashMode.auto {
        didSet {
            self.currentPhotoOutout?.flashMode = photoFlashMode
        }
    }
    
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

    var videoInputs: [AVCaptureDeviceInput] {
        return videoCaptureSession.inputs.flatMap{ $0 as? AVCaptureDeviceInput }
    }
    
    public var currentVideoDevice: AVCaptureDevice? {
        get {
            return videoInputs.filter { $0.device.hasMediaType(AVMediaTypeVideo) }.first?.device
        }

        set {
            do {
                if let currentVideoDeviceInput = videoInputs.first(where: { $0.device.hasMediaType(AVMediaTypeVideo) }) {
                   try videoCaptureSession.removeInput(currentVideoDeviceInput)
                }

                if let currentVideoDevice = newValue {
                    configure(videoDevice: currentVideoDevice)
                    let currentVideoDeviceInput = try AVCaptureDeviceInput(device: currentVideoDevice)
                    videoCaptureSession.addInput(currentVideoDeviceInput)
                }
            } catch {
                print("Error adding camera: \(error)")
            }
        }
    }

    func configure(videoDevice: AVCaptureDevice) {
        do {
            try videoDevice.lockForConfiguration()
            if videoDevice.isSmoothAutoFocusSupported {
                videoDevice.isSmoothAutoFocusEnabled = true
            }

            if videoDevice.isLowLightBoostSupported {
                videoDevice.automaticallyEnablesLowLightBoostWhenAvailable = true
            }

            videoDevice.isSubjectAreaChangeMonitoringEnabled = true
            videoDevice.unlockForConfiguration()
        } catch {
            print("Couldn't configure new video device: \(error.localizedDescription)")
        }
    }
    
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

        if let firstVideoDevice = self.videoDeviceDiscoverySession?.devices.first {
            do {
                let currentVideoDeviceInput = try AVCaptureDeviceInput(device: firstVideoDevice)
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
        var transform = CGAffineTransform.identity

        if currentVideoDevice?.position == .front {
            transform = transform.scaledBy(x: -1, y: 1)
        }

        return transform.rotated(by: -CGFloat.pi / 2)
    }

    var audioSession = AVAudioSession.sharedInstance()
    
    public func prepare() throws {
        if let currentVideoDevice = currentVideoDevice {
            configure(videoDevice: currentVideoDevice)
        }
        try initializeRecordingSession()
        try initializePhotoOutput()
    }
    
    public func unprepare() {
        
    }

    // MARK: - Photo Capture

    var currentPhotoOutout: PhotoOutput?

    func initializePhotoOutput() throws -> PhotoOutput {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")

        let photoOutput = try PhotoOutput(captureSession: self.videoCaptureSession, renderPipeline: renderPipeline, outputURL: url)
        photoOutput.flashMode = photoFlashMode

        currentPhotoOutout = photoOutput
        return photoOutput
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

    public func snapshotOfLastVideoBuffer() -> UIImage? {
        return currentRecordingSession?.snapshotOfLastVideoBuffer()
    }

    public func takePhoto(completionHandler handler: @escaping (UIImage?, Error?) -> Void) {
        do {
            let photoOutput = try currentPhotoOutout ?? initializePhotoOutput()
            photoOutput.takePhoto(completionHandler: handler)
        } catch {
            handler(nil, error)
        }
    }
}
