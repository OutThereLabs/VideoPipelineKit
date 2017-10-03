//
//  CAMetalLayer+RenderPipelineOutput.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 9/20/17.
//

import UIKit
import Metal
import QuartzCore

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

    let dispatchSemaphore = DispatchSemaphore(value: 1)

    public func render(image: CIImage, context: CIContext) {
        guard let commandQueue = commandQueue else { return }

        guard let drawable = nextDrawable() else {
            return
        }

        let waitTime = dispatchSemaphore.wait(timeout: DispatchTime.now())
        if waitTime != .success {
            return
        }

        autoreleasepool {
            let commandCompletionSemaphore = dispatchSemaphore

            let commandBuffer = commandQueue.makeCommandBuffer()

            commandBuffer.addCompletedHandler{ _ in
                commandCompletionSemaphore.signal()
            }

            let texture = drawable.texture
            let scaledImage = image.applying(CGAffineTransform.aspectFill(from: image.extent, to: CGRect(origin: CGPoint.zero, size: drawableSize)))
            context.render(scaledImage, to: texture, commandBuffer: commandBuffer, bounds: scaledImage.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

