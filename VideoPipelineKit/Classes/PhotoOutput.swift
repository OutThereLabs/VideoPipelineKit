//
//  PhotoOutput.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 10/31/17.
//

import AVKit

class PhotoOutput: NSObject, AVCapturePhotoCaptureDelegate {
    let capturePhotoOutput = AVCapturePhotoOutput()

    let outputURL: URL
    let renderPipeline: RenderPipeline

    public init(captureSession: AVCaptureSession, renderPipeline: RenderPipeline, outputURL: URL) throws {
        self.renderPipeline = renderPipeline
        self.outputURL = outputURL

        if captureSession.canAddOutput(capturePhotoOutput) {
            captureSession.addOutput(capturePhotoOutput)
        } else {
            throw NSError(domain: "com.outtherelabs.videopipelinekit", code: 500, userInfo: [NSLocalizedDescriptionKey: "Can't add photo capture output."])
        }
    }

    var handler: ((UIImage?, Error?) -> Void)?
    
    public var flashMode = AVCaptureDevice.FlashMode.auto

    private var settings: AVCapturePhotoSettings {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        return settings
    }

    public func takePhoto(completionHandler handler: @escaping (UIImage?, Error?) -> Void) {
        self.handler = handler
        if let connection = capturePhotoOutput.connection(withMediaType: AVMediaTypeVideo), connection.isVideoMirroringSupported {
            connection.isVideoMirrored = renderPipeline.mirrorVideo
        }
        capturePhotoOutput.capturePhoto(with: settings, delegate: self)
    }

    func handleCapture(data: Data) {
        let image = UIImage(data: data)
        handler?(image, nil)
    }

    func handleCapture(sampleBuffer: CMSampleBuffer) {
        guard let jpegData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer) else {
            let error = NSError(domain: "com.outtherelabs.videopipelinekit", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not create photo from captured data."])
            handler?(nil, error)
            return
        }
        let image = UIImage(data: jpegData)
        handler?(image, nil)
    }

    // MARK: AVCapturePhotoCaptureDelegate

    func capture(_ output: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if let photoSampleBuffer = photoSampleBuffer {
            handleCapture(sampleBuffer: photoSampleBuffer)
        } else if let error = error {
            handler?(nil, error)
        }
    }

    @available(iOS 11.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let fileDataRepresentation = photo.fileDataRepresentation() {
            handleCapture(data: fileDataRepresentation)
        } else if let error = error {
            handler?(nil, error)
        }
    }
}
