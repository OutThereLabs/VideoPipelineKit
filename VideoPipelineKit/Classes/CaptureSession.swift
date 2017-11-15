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

    let audioDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone], mediaType: AVMediaType.audio, position: .unspecified)

    let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)

    var videoInputs: [AVCaptureDeviceInput] {
        return videoCaptureSession.inputs.flatMap{ $0 as? AVCaptureDeviceInput }
    }
    
    public var currentVideoDevice: AVCaptureDevice? {
        get {
            return videoInputs.filter { $0.device.hasMediaType(AVMediaType.video) }.first?.device
        }

        set {
            videoCaptureSession.beginConfiguration()
            do {
                if let currentVideoDeviceInput = videoInputs.first(where: { $0.device.hasMediaType(AVMediaType.video) }) {
                   videoCaptureSession.removeInput(currentVideoDeviceInput)
                }

                if let currentVideoDevice = newValue {
                    configure(videoDevice: currentVideoDevice)

                    let currentVideoDeviceInput = try AVCaptureDeviceInput(device: currentVideoDevice)
                    videoCaptureSession.addInput(currentVideoDeviceInput)

                    if let currentRecordingSession = currentRecordingSession {
                        currentRecordingSession.mirrorVideo = currentVideoDevice.position == .front
                        currentRecordingSession.configureConnections(captureSession: videoCaptureSession)
                    }
                }
            } catch {
                print("Error adding camera: \(error)")
            }
            videoCaptureSession.commitConfiguration()
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
        return self.videoDeviceDiscoverySession.devices
    }

    lazy var audioCaptureSession: AVCaptureSession = {
        let audioCaptureSession = AVCaptureSession()
        audioCaptureSession.automaticallyConfiguresApplicationAudioSession = false

        if let builtInMicrophone = self.audioDeviceDiscoverySession.devices.first {
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
        return videoCaptureSession
    }()

    public lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        let previewLayer = AVCaptureVideoPreviewLayer(session: self.videoCaptureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        return previewLayer
    }()

    var orientationTransform: CGAffineTransform {
        let transform = CGAffineTransform.identity
        return transform.rotated(by: -CGFloat.pi / 2)
    }

    var audioSession = AVAudioSession.sharedInstance()
    
    public func prepare() throws {
        if let currentVideoDevice = currentVideoDevice ?? videoDevices.first {
            self.currentVideoDevice = currentVideoDevice
        }

        _ = try initializeRecordingSession()
        _ = try initializePhotoOutput()
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

    var currentRecordingSession: RecordingSession? {
        didSet {
            oldValue?.cleanup()
        }
    }


    public var outputURL: URL? {
        return currentRecordingSession?.outputURL
    }


    func initializeRecordingSession() throws -> RecordingSession {
        currentRecordingSession = nil

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        let recordingSession = try RecordingSession(captureSessions: [self.audioCaptureSession, self.videoCaptureSession], renderPipeline: renderPipeline, outputURL: url)

        if let currentVideoDevice = currentVideoDevice {
            recordingSession.mirrorVideo = currentVideoDevice.position == .front
        }

        currentRecordingSession = recordingSession
        return recordingSession
    }
    
    public var isRecording: Bool {
        return (currentRecordingSession?.state == .recording)
    }

    public func startRecording() throws {
        if let currentRecordingSession = currentRecordingSession, currentRecordingSession.state == .finished {
            self.currentRecordingSession = nil
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
        recordingSession.start(orientationTransform: orientationTransform)
    }

    public func stopRecording(completionHandler handler: @escaping () -> Swift.Void) {
        if let recordingSession = currentRecordingSession {
            recordingSession.finish {
                handler()
                _ = try? self.initializeRecordingSession()
            }
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
