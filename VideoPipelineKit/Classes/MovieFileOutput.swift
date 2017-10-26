//
//  MovieFileOutput.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 10/23/17.
//

import AVKit
import CoreImage

enum MovieFileOutputAdapter {
    case audio(captureOutput: AVCaptureAudioDataOutput, assetWriterInput: AVAssetWriterInput)
    case video(captureOutput: AVCaptureVideoDataOutput, assetWriterInput: AVAssetWriterInput, pixelBufferAdapter: AVAssetWriterInputPixelBufferAdaptor)

    var captureOutput: AVCaptureOutput {
        switch self {
        case .audio(let captureOutput, _):
            return captureOutput
        case .video(let captureOutput, _, _):
            return captureOutput
        }
    }

    var assetWriterInput: AVAssetWriterInput {
        switch self {
        case .audio(_, let assetWriterInput):
            return assetWriterInput
        case .video(_, let assetWriterInput, _):
            return assetWriterInput
        }
    }

    var pixelBufferAdapter: AVAssetWriterInputPixelBufferAdaptor? {
        switch self {
        case .audio(_, _):
            return nil
        case .video(_, _, let pixelBufferAdapter):
            return pixelBufferAdapter
        }
    }
}

class MovieFileOutput {
    let assetWriter: AVAssetWriter

    let adapters: [MovieFileOutputAdapter]

    var renderPipeline: RenderPipeline?

    public var outputURL: URL {
        return assetWriter.outputURL
    }

    convenience init(outputURL: URL, renderPipeline: RenderPipeline, sourcePixelBufferAttributes: [String : Any]? = nil, captureOutputs: [AVCaptureOutput]) throws {
        try self.init(outputURL: outputURL, size: renderPipeline.size, sourcePixelBufferAttributes: sourcePixelBufferAttributes, captureOutputs: captureOutputs)
        self.renderPipeline = renderPipeline
    }

    init(outputURL: URL, size: CGSize, sourcePixelBufferAttributes: [String : Any]? = nil, captureOutputs: [AVCaptureOutput]) throws {
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: AVFileTypeQuickTimeMovie)

        adapters = captureOutputs.flatMap { captureOutput -> MovieFileOutputAdapter? in
            if let audioCaptureOutput = captureOutput as? AVCaptureAudioDataOutput {
                let assetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: nil)
                assetWriterInput.expectsMediaDataInRealTime = true
                return MovieFileOutputAdapter.audio(captureOutput: audioCaptureOutput, assetWriterInput: assetWriterInput)
            }

            if let videoCaptureOutput = captureOutput as? AVCaptureVideoDataOutput {
                let assetWriterInput: AVAssetWriterInput
                if #available(iOS 11.0, *) {
                    assetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: [AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoHeightKey: size.height, AVVideoWidthKey: size.width])
                } else {
                    assetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: nil)
                }
                assetWriterInput.expectsMediaDataInRealTime = true

                let pixelBufferAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
                return MovieFileOutputAdapter.video(captureOutput: videoCaptureOutput, assetWriterInput: assetWriterInput, pixelBufferAdapter: pixelBufferAdapter)
            }

            return nil
        }
    }

    func startWriting(transform: CGAffineTransform) {
        for adapter in adapters {
            adapter.assetWriterInput.transform = transform

            guard assetWriter.canAdd(adapter.assetWriterInput) else {
                return assertionFailure()
            }
            assetWriter.add(adapter.assetWriterInput)
        }

        assetWriter.startWriting()
    }

    func finishWriting(completionHandler handler: @escaping () -> Swift.Void) {
        assetWriter.finishWriting(completionHandler: handler)
        startTime = kCMTimeInvalid
    }

    var startTime: CMTime = kCMTimeInvalid {
        didSet {
            if oldValue == kCMTimeInvalid, startTime != kCMTimeInvalid {
                assetWriter.startSession(atSourceTime: startTime)
            }
        }
    }

    func append(sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let adapter = adapters.first(where: { $0.captureOutput == connection.output }) else {
            return
        }

        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if startTime == kCMTimeInvalid {
            startTime = time
        }

        switch adapter {
        case .audio(_, let assetWriterInput):
            guard assetWriterInput.isReadyForMoreMediaData else {
                return
            }

            assetWriterInput.append(sampleBuffer)
        case .video(_, let assetWriterInput, let pixelBufferAdapter):
            guard assetWriterInput.isReadyForMoreMediaData else {
                return
            }

            guard let imageContext = renderPipeline?.imageContext else {
                assetWriterInput.append(sampleBuffer)
                return
            }

            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return assertionFailure()
            }

            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            self.append(image: ciImage, from: connection, imageContext: imageContext, time: time, pixelBufferAdapter: pixelBufferAdapter, to: assetWriterInput)
        }
    }

    func append(image: CIImage, from connection: AVCaptureConnection, imageContext: CIContext, time: CMTime, pixelBufferAdapter: AVAssetWriterInputPixelBufferAdaptor, to assetWriterInput: AVAssetWriterInput) {
        guard let pixelBufferPool = pixelBufferAdapter.pixelBufferPool else {
            return assertionFailure()
        }

        var pixelBuffer: CVPixelBuffer?

        guard CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer) == kCVReturnSuccess else {
            return assertionFailure()
        }

        if let pixelBuffer = pixelBuffer {
            imageContext.render(image, to: pixelBuffer)
            pixelBufferAdapter.append(pixelBuffer, withPresentationTime: time)
        } else {
            return assertionFailure()
        }
    }
}
