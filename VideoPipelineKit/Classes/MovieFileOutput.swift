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

    let captureOutputs: [AVCaptureOutput]

    let size: CGSize

    let sourcePixelBufferAttributes: [String: Any]?

    var videoSourceFormatHint: CMFormatDescription?

    lazy var adapters: [MovieFileOutputAdapter] = {
        guard self.videoSourceFormatHint != nil else {
            assertionFailure()
            return [MovieFileOutputAdapter]()
        }

        let videoOutputSettings: [String: Any]? = [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoHeightKey: self.size.height,
            AVVideoWidthKey: self.size.width
        ]

        let audioOutputSettings: [String: Any]? = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128000,
            AVNumberOfChannelsKey: 2
        ]

        return self.captureOutputs.flatMap { captureOutput -> MovieFileOutputAdapter? in
            if let audioCaptureOutput = captureOutput as? AVCaptureAudioDataOutput {
                let assetWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioOutputSettings)
                assetWriterInput.expectsMediaDataInRealTime = true
                return MovieFileOutputAdapter.audio(captureOutput: audioCaptureOutput, assetWriterInput: assetWriterInput)
            }

            if let videoCaptureOutput = captureOutput as? AVCaptureVideoDataOutput {
                let assetWriterInput: AVAssetWriterInput
                assetWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoOutputSettings, sourceFormatHint: nil)
                assetWriterInput.expectsMediaDataInRealTime = true

                let pixelBufferAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: self.sourcePixelBufferAttributes)
                return MovieFileOutputAdapter.video(captureOutput: videoCaptureOutput, assetWriterInput: assetWriterInput, pixelBufferAdapter: pixelBufferAdapter)
            }

            return nil
        }
    }()

    var renderPipeline: RenderPipeline

    public var outputURL: URL {
        return assetWriter.outputURL
    }

    convenience init(outputURL: URL, renderPipeline: RenderPipeline, sourcePixelBufferAttributes: [String : Any]? = nil, captureOutputs: [AVCaptureOutput], metadata: [AVMetadataItem]) throws {
        try self.init(outputURL: outputURL, size: renderPipeline.size, sourcePixelBufferAttributes: sourcePixelBufferAttributes, captureOutputs: captureOutputs, metadata: metadata)
        self.renderPipeline = renderPipeline
    }

    init(outputURL: URL, size: CGSize, sourcePixelBufferAttributes: [String : Any]? = nil, captureOutputs: [AVCaptureOutput], metadata: [AVMetadataItem]) throws {
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mp4)

        assetWriter.metadata = metadata
        assetWriter.shouldOptimizeForNetworkUse = true

        self.size = size
        self.sourcePixelBufferAttributes = sourcePixelBufferAttributes
        self.captureOutputs = captureOutputs
        self.renderPipeline = RenderPipeline(config: RenderPipeline.Config.defaultConfig, size: size)
    }

    var isWriting: Bool {
        return assetWriter.status == .writing
    }

    func startWriting(orientationTransform: CGAffineTransform) {
        renderPipeline.orientationTransform = orientationTransform

        for adapter in adapters {
            guard assetWriter.canAdd(adapter.assetWriterInput) else {
                assertionFailure()
                break
            }
            assetWriter.add(adapter.assetWriterInput)
        }

        assetWriter.startWriting()

        guard isWriting else {
            return assertionFailure(assetWriter.error?.localizedDescription ?? "Unknown error")
        }

        if startTime != kCMTimeInvalid {
            assetWriter.startSession(atSourceTime: startTime)
        }
    }

    func finishWriting(completionHandler handler: @escaping () -> Swift.Void) {
        assetWriter.finishWriting {
            self.startTime = kCMTimeInvalid
            handler()
        }
    }

    var startTime: CMTime = kCMTimeInvalid {
        didSet {
            if oldValue == kCMTimeInvalid, startTime != kCMTimeInvalid, isWriting {
                assetWriter.startSession(atSourceTime: startTime)
            }
        }
    }
    
    public var mirrorVideo: Bool {
        get {
            return renderPipeline.mirrorVideo
        }

        set {
            renderPipeline.mirrorVideo = newValue
        }
    }

    func append(sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
         if connection.output is AVCaptureVideoDataOutput, videoSourceFormatHint == nil {
            self.videoSourceFormatHint = CMSampleBufferGetFormatDescription(sampleBuffer)
        }

        guard isWriting else {
            return
        }

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

            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return assertionFailure()
            }

            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            self.append(image: ciImage, from: connection, time: time, pixelBufferAdapter: pixelBufferAdapter, to: assetWriterInput)
        }
    }

    func append(image: CIImage, from connection: AVCaptureConnection, time: CMTime, pixelBufferAdapter: AVAssetWriterInputPixelBufferAdaptor, to assetWriterInput: AVAssetWriterInput) {
        guard let pixelBufferPool = pixelBufferAdapter.pixelBufferPool else {
            return assertionFailure()
        }

        var pixelBuffer: CVPixelBuffer?

        guard CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer) == kCVReturnSuccess else {
            return assertionFailure()
        }

        if let pixelBuffer = pixelBuffer {
            renderPipeline.render(image: image, to: pixelBuffer)
            pixelBufferAdapter.append(pixelBuffer, withPresentationTime: time)
        } else {
            return assertionFailure()
        }
    }
}
