//
//  RenderPipelineCompositor.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 9/27/17.
//

import AVFoundation

public class RenderPipelineLayerInstruction: AVMutableVideoCompositionLayerInstruction {
    public init(assetTrack: AVAssetTrack) {
        super.init()
        self.trackID = assetTrack.trackID
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var cropInstructions = [(CGRect, CGRect, CMTimeRange)]()

    public func getPostTransformCropRectangleRamp(for time: CMTime, startCropRectangle: UnsafeMutablePointer<CGRect>?, endCropRectangle: UnsafeMutablePointer<CGRect>?, timeRange: UnsafeMutablePointer<CMTimeRange>?) -> Bool {
        guard let cropInstruction = cropInstructions.first(where: { cropInstruction -> Bool in
            return CMTimeRangeContainsTime(cropInstruction.2, time)
        }) else {
            return false
        }

        startCropRectangle?.pointee = cropInstruction.0
        endCropRectangle?.pointee = cropInstruction.1
        timeRange?.pointee = cropInstruction.2

        return true
    }

    public func setPostTransformCropRectangleRamp(fromStartCropRectangle startCropRectangle: CGRect, toEndCropRectangle endCropRectangle: CGRect, timeRange: CMTimeRange) {
        cropInstructions.append((startCropRectangle, endCropRectangle, timeRange))
    }

    public func setPostTransformCropRectangle(_ cropRectangle: CGRect, at time: CMTime) {
        let endTime = CMTime.init(seconds: Double.infinity, preferredTimescale: time.timescale)
        let timeRange = CMTimeRange(start: time, end: endTime)
        setPostTransformCropRectangleRamp(fromStartCropRectangle: cropRectangle, toEndCropRectangle: cropRectangle, timeRange: timeRange)
    }
}

public class RenderPipelineCompositor: NSObject, AVVideoCompositing {

    public let supportsWideColorSourceFrames = true

    var renderContext: AVVideoCompositionRenderContext?

    lazy var imageContext: CIContext = {
        return CIContext()
    }()

    var pixelBufferPixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange

    public var sourcePixelBufferAttributes: [String : Any]? {
        return [kCVPixelBufferPixelFormatTypeKey as String: pixelBufferPixelFormatType]
    }

    public var requiredPixelBufferAttributesForRenderContext: [String : Any] {
        return [kCVPixelBufferPixelFormatTypeKey as String: pixelBufferPixelFormatType]
    }

    public func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        renderContext = newRenderContext
    }

    public func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        let startedAt = Date()

        guard asyncVideoCompositionRequest.sourceTrackIDs.count > 0 else {
            let error = NSError(domain: "com.outtherelabs.video", code: 500, userInfo: [NSLocalizedDescriptionKey: "No source track IDs"])
            asyncVideoCompositionRequest.finish(with: error)
            return
        }

        guard let videoCompositionInstruction = asyncVideoCompositionRequest.videoCompositionInstruction as? AVVideoCompositionInstruction else {
            let error = NSError(domain: "com.outtherelabs.video", code: 500, userInfo: [NSLocalizedDescriptionKey: "Can't render instruction: \(asyncVideoCompositionRequest.videoCompositionInstruction), unknown instruction type"])
            asyncVideoCompositionRequest.finish(with: error)
            return
        }

        guard let pixelBuffer = asyncVideoCompositionRequest.renderContext.newPixelBuffer() else {
            let error = NSError(domain: "com.outtherelabs.video", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not render video frame"])
            asyncVideoCompositionRequest.finish(with: error)
            return
        }

        let backgroundColor = CIColor(cgColor: videoCompositionInstruction.backgroundColor ?? UIColor.clear.cgColor)
        let contextExtent = CGRect(origin: CGPoint.zero, size: asyncVideoCompositionRequest.renderContext.size)
        let backgroundImage = CIImage(color: backgroundColor).cropping(to: contextExtent)

        let composedImage = videoCompositionInstruction.layerInstructions.reduce(backgroundImage, { (composedImage, instruction) -> CIImage in
            guard let layerImageBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: instruction.trackID) else {
                let error = NSError(domain: "com.outtherelabs.video", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not get image for layer \(instruction.trackID)"])
                asyncVideoCompositionRequest.finish(with: error)
                return composedImage
            }

            let layerImage = CIImage(cvPixelBuffer: layerImageBuffer)

            var cropRectangle = layerImage.extent
            instruction.getCropRectangleRamp(for: asyncVideoCompositionRequest.compositionTime, startCropRectangle: &cropRectangle, endCropRectangle: nil, timeRange: nil)
            let croppedImage = layerImage.cropping(to: cropRectangle)

            var transform = CGAffineTransform.identity
            instruction.getTransformRamp(for: asyncVideoCompositionRequest.compositionTime, start: &transform, end: nil, timeRange: nil)
            let transformedImage = croppedImage.applying(transform)

            guard let instruction = instruction as? RenderPipelineLayerInstruction else {
                return transformedImage.compositingOverImage(composedImage)
            }

            var postTransformCropRectangle = transformedImage.extent
            _ = instruction.getPostTransformCropRectangleRamp(for: asyncVideoCompositionRequest.compositionTime, startCropRectangle: &postTransformCropRectangle, endCropRectangle: nil, timeRange: nil)
            let postTransformCropTranslation = CGAffineTransform(translationX: -postTransformCropRectangle.origin.x, y: -postTransformCropRectangle.origin.y)
            let postTransformCroppedImage = transformedImage.cropping(to: postTransformCropRectangle).applying(postTransformCropTranslation)

            return postTransformCroppedImage.compositingOverImage(composedImage)
        })

        let transformedImage = composedImage.applying(asyncVideoCompositionRequest.renderContext.renderTransform)

        imageContext.render(transformedImage, to: pixelBuffer)
        asyncVideoCompositionRequest.finish(withComposedVideoFrame: pixelBuffer)
        let duration = Date().timeIntervalSince(startedAt)
        print("Rendered a frame in \(duration) seconds")
    }
}
