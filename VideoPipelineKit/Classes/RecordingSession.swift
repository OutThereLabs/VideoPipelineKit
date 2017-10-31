//
//  RecordingSession.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 10/23/17.
//

import AVKit

enum RecordingSessionState {
    case ready
    case recording
    case finishing
    case finished
}

public class RecordingSession: NSObject {

    var state: RecordingSessionState

    let movieFileOutput: MovieFileOutput

    let captureSessions: [AVCaptureSession]

    let captureOutputs: [(AVCaptureSession, AVCaptureOutput)]

    public var outputURL: URL {
        return movieFileOutput.outputURL
    }

    let renderPipeline: RenderPipeline

    public init(captureSessions: [AVCaptureSession], renderPipeline: RenderPipeline, outputURL: URL, metadata: [AVMetadataItem] = [AVMetadataItem]()) throws {
        self.captureSessions = captureSessions
        self.renderPipeline = renderPipeline

        let captureOutputs = captureSessions.flatMap { captureSession -> [(AVCaptureSession, AVCaptureOutput)] in
            let allMediaTypes = captureSession.inputs.flatMap { $0 as? AVCaptureInput }.flatMap { $0.ports.flatMap { $0 as? AVCaptureInput.Port } }.flatMap { $0.mediaType }

            return allMediaTypes.flatMap { mediaType -> (AVCaptureSession, AVCaptureOutput)? in
                switch mediaType {
                case AVMediaTypeAudio:
                    let output = AVCaptureAudioDataOutput()
                    return (captureSession, output)
                case AVMediaTypeVideo:
                    let output = AVCaptureVideoDataOutput()
                    return (captureSession, output)
                default:
                    return nil
                }
            }
        }

        self.captureOutputs = captureOutputs

        movieFileOutput = try MovieFileOutput(outputURL: outputURL, renderPipeline: renderPipeline, captureOutputs: captureOutputs.map { $0.1 }, metadata: metadata)
        state = .ready

        super.init()

        self.createRoutes()
    }

    let sampleBufferQueue = DispatchQueue(label: "RecordingSession")

    var ports: [AVCaptureInput.Port] {
        return captureSessions.flatMap { $0.inputs.flatMap { $0 as? AVCaptureInput }}.flatMap { $0.ports.flatMap { $0 as? AVCaptureInput.Port } }
    }

    func createRoutes() {
        for (captureSession, captureOutput) in captureOutputs {
            if let captureOutput = captureOutput as? AVCaptureAudioDataOutput {
                captureOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
            } else if let captureOutput = captureOutput as? AVCaptureVideoDataOutput {
                captureOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
            } else {
                assertionFailure()
            }

            if captureSession.canAddOutput(captureOutput) {
                captureSession.addOutput(captureOutput)
            } else {
                captureSession.addOutput(captureOutput)
                assertionFailure()
            }
        }
    }

    public func start(transform: CGAffineTransform) {
        guard state == .ready else {
            return assertionFailure()
        }

        movieFileOutput.startWriting(transform: transform)
        state = .recording
    }

    public func finish(completionHandler handler: @escaping () -> Swift.Void) {
        state = .finishing
        sampleBufferQueue.async {
            self.movieFileOutput.finishWriting {
                self.state = .finished
                handler()
            }
        }
    }

    func destroyRoutes() {
        for (captureSession, captureOutput) in captureOutputs {
            captureSession.removeOutput(captureOutput)
        }
    }

    public func cleanup() {
        destroyRoutes()
    }

    var lastSampledVideoBuffer: CMSampleBuffer?

    public func snapshotOfLastVideoBuffer() -> UIImage? {
        guard let lastSampledBuffer = lastSampledVideoBuffer, let cvPixelBuffer = CMSampleBufferGetImageBuffer(lastSampledBuffer) else { return nil }
        let transform = movieFileOutput.transform ?? CGAffineTransform.identity
        let ciImage = CIImage(cvPixelBuffer: cvPixelBuffer).applying(transform)

        guard let cgImage = renderPipeline.imageContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}

extension RecordingSession: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    public func captureOutput(_ output: AVCaptureOutput!, didDrop sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {

    }

    public func captureOutput(_ output: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        if output.connection(withMediaType: AVMediaTypeVideo) != nil {
            lastSampledVideoBuffer = sampleBuffer
        }

        switch state {
        case .ready, .recording:
            let processedSampleBuffer = renderPipeline.process(sampleBuffer: sampleBuffer)
            movieFileOutput.append(sampleBuffer: processedSampleBuffer, from: connection)
        case .finishing, .finished:
            break
        }
    }
}
