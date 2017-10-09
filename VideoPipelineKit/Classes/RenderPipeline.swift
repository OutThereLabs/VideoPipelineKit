//
//  RenderPipeline.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 9/20/17.
//

import AVKit
import SceneKit

public protocol RenderPipelineOutput {
    func render(image: CIImage, context: CIContext)
}

public protocol RenderPipelineListener {
    func renderPipelineDidChangeFilters(_ renderPipeline: RenderPipeline)
}

public class RenderPipeline: NSObject {
    public enum Config {
        case metal(device: MTLDevice)
    }

    var pixelBufferPixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange

    public let config: Config
    public let imageContext: CIContext

    public init(config: Config) {
        self.config = config

        switch config {
        case .metal(let device):
            self.imageContext = CIContext(mtlDevice: device)
        }
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

    public var size = CGSize(width: 1920, height: 1080)

    public func render(image: CIImage) {
        let preferredSize = CGRect(origin: CGPoint.zero, size: size)
        let scaleTransform = CGAffineTransform.aspectFill(from: image.extent, to: preferredSize)
        let scaledImage = image.applying(scaleTransform)
        let renderedImage = rendererdImage(image: scaledImage)
        forwardToOutputs(image: renderedImage)
    }

    func forwardToOutputs(image: CIImage) {
        for output in outputs {
            output.render(image: image, context: imageContext)
        }
    }

    // MARK: Output

    var outputs = [RenderPipelineOutput]()

    public func add(output: RenderPipelineOutput) {
        outputs.append(output)
    }
}

extension UIDevice {
    func imagePropertyOrientation(from value: UIDeviceOrientation) -> CGImagePropertyOrientation {
        switch (value) {
        case .portrait:
            return .right
        case .landscapeLeft:
            return .down
        case .landscapeRight:
            return .up
        default:
            return .left
        }
    }

    var imagePropertyOrientation: CGImagePropertyOrientation {
        return imagePropertyOrientation(from: orientation)
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

