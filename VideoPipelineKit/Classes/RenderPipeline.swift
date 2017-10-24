//
//  RenderPipeline.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 9/20/17.
//

import AVKit
import SceneKit

public protocol RenderPipelineOutput {
    func render(image: CIImage, context: CIContext, pipeline: RenderPipeline)
}

public protocol RenderPipelineListener {
    func renderPipelineDidChangeFilters(_ renderPipeline: RenderPipeline)
}

public class RenderPipeline: NSObject {
    static let shareGroup: EAGLSharegroup = {
        return EAGLSharegroup()
    }()

    public enum Config {
        case metal(device: MTLDevice)
        case eagl(context: EAGLContext)

        public static var defaultConfig: Config {
            if let device = MTLCreateSystemDefaultDevice() {
                return .metal(device: device)
            }

            let eaglContext = EAGLContext(api: EAGLRenderingAPI.openGLES2, sharegroup: shareGroup)!
            return .eagl(context: eaglContext)
        }
    }

    var pixelBufferPixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange

    public let config: Config
    public let imageContext: CIContext

    public init(config: Config, size: CGSize) {
        self.config = config
        self.size = size

        switch config {
        case .metal(let device):
            self.imageContext = CIContext(mtlDevice: device)
        case .eagl(let context):
            self.imageContext = CIContext(eaglContext: context)
        }
    }

    public lazy var commandQueue: MTLCommandQueue? = {
        switch self.config {
        case .metal(let device):
            return device.makeCommandQueue()
        case .eagl:
            return nil
        }
    }()

    public var size: CGSize {
        didSet {
            if size != oldValue {
                cachedScaledOverlay = nil
            }
        }
    }

    // MARK: - Overlay

    public var overlay: UIImage? {
        didSet {
            if overlay != oldValue {
                cachedScaledOverlay = nil
            }
        }
    }

    private var cachedScaledOverlay: CIImage?

    var scaledOverlay: CIImage? {
        if let cachedScaledOverlay = cachedScaledOverlay {
            return cachedScaledOverlay
        }

        guard let overlay = overlay?.cgImage else {
            return nil
        }

        let fullSizeRect = CGRect(origin: CGPoint.zero, size: size)

        let overlayCIImage = CIImage(cgImage: overlay)
        let overlayScaleTransform = CGAffineTransform.aspectFill(from: overlayCIImage.extent, to: fullSizeRect)
        let scaledOverlay = overlayCIImage.applying(overlayScaleTransform)
        self.cachedScaledOverlay = scaledOverlay
        return scaledOverlay
    }

    // MARK: - Pipeline

    public var filters = [CIFilter]()

    func rendererdImage(image: CIImage) -> CIImage {
        return self.filters.reduce(image) { (lastImage, filter) -> CIImage in
            filter.setValue(lastImage, forKey: kCIInputImageKey)
            guard let outputImage = filter.outputImage else {
                assertionFailure()
                return lastImage
            }
            return outputImage
        }
    }

    public func process(sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        guard filters.count > 0 else {
            return sampleBuffer
        }

        assertionFailure("Can't filter sample buffers yet")
        return sampleBuffer
    }

    public func process(image: UIImage) throws -> UIImage {
        guard let inputImage = CIImage(image: image) else {
            throw NSError(domain: "com.outtherelabs.videopipelinekit", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not process image"])
        }

        let renderedImage = self.rendererdImage(image: inputImage)

        return UIImage(ciImage: renderedImage)
    }

    public func render(uiImage image: UIImage) throws {
        guard let inputImage = CIImage(image: image) else {
            throw NSError(domain: "com.outtherelabs.videopipelinekit", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not process image"])
        }

        render(ciImage: inputImage)
    }

    let renderSemaphore = DispatchSemaphore(value: 1)

    public func render(ciImage image: CIImage) {
        if renderSemaphore.wait(timeout: DispatchTime.now()) == .timedOut {
            return
        }

        defer {
            renderSemaphore.signal()
        }

        let preferredSize = CGRect(origin: CGPoint.zero, size: size)
        let scaleTransform = CGAffineTransform.aspectFill(from: image.extent, to: preferredSize)
        let scaledImage = image.applying(scaleTransform)

        var renderedImage = rendererdImage(image: scaledImage)

        if let scaledOverlay = scaledOverlay {
            renderedImage = scaledOverlay.compositingOverImage(renderedImage)
        }

        forwardToOutputs(image: renderedImage)
    }

    func forwardToOutputs(image: CIImage) {
        for output in outputs {
            output.render(image: image, context: imageContext, pipeline: self)
        }
    }

    // MARK: Output

    var outputs = [RenderPipelineOutput]()

    public func add(output: RenderPipelineOutput) {
        outputs.append(output)
    }
}

extension CGAffineTransform {
    static func aspectFill(from: CGRect, to: CGRect) -> CGAffineTransform {
        let horizontalRatio = to.width / from .width
        let verticalRatio = to.height / from.height
        let scale = max(horizontalRatio, verticalRatio)
        let translationX = horizontalRatio < verticalRatio ? (to.width - from.width * scale) * 0.5 : 0
        let translationY = horizontalRatio > verticalRatio ? (to.height - from.height * scale) * 0.5 : 0
        return CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: translationX, y: translationY)
    }
}

