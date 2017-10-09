//
//  CAMetalLayer+RenderPipelineOutput.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 9/20/17.
//

import UIKit
import Metal
import QuartzCore

public class RenderPipelineMetalView: UIView {
    override public static var layerClass: AnyClass {
        return RenderPipelineMetalLayer.self
    }

    public override var layer: RenderPipelineMetalLayer {
        return super.layer as! RenderPipelineMetalLayer
    }
}

public class RenderPipelineMetalLayer: CAMetalLayer, RenderPipelineOutput {
    public var underlyingContext: MTLDevice? {
        return device
    }

    var cachedCommandQueue: MTLCommandQueue?

    var commandQueue: MTLCommandQueue? {
        if let cachedCommandQueue = cachedCommandQueue {
            return cachedCommandQueue
        }

        if let device = device {
            let commandQueue = device.makeCommandQueue()
            cachedCommandQueue = commandQueue
            return commandQueue
        }

        return nil
    }

    let dispatchSemaphore = DispatchSemaphore(value: 3)

    public func render(image: CIImage, context: CIContext) {
        guard let commandQueue = commandQueue else { return }

        autoreleasepool {
            guard let drawable = nextDrawable() else {
                return
            }

            let waitTime = dispatchSemaphore.wait(timeout: DispatchTime.now())
            if waitTime != .success {
                return
            }

            let commandBuffer = commandQueue.makeCommandBuffer()

            let commandCompletionSemaphore = dispatchSemaphore
            commandBuffer.addCompletedHandler{ _ in
                commandCompletionSemaphore.signal()
            }

            let scaledImage = image.applying(CGAffineTransform.aspectFill(from: image.extent, to: CGRect(origin: CGPoint.zero, size: drawableSize)))
            context.render(scaledImage, to: drawable.texture, commandBuffer: commandBuffer, bounds: scaledImage.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

