//
//  MTKView+RenderPipelineOutput.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 9/20/17.
//

import UIKit
import MetalKit
import QuartzCore

extension MTKView: RenderPipelineOutput {
    public func render(image: CIImage, context: CIContext, pipeline: RenderPipeline) {
        guard let commandQueue = pipeline.commandQueue else { return }

        autoreleasepool {
            guard let currentDrawable = currentDrawable else {
                return
            }

            #if arch(i386) || arch(x86_64)
                assertionFailure("Can't use MTKView as a render pipeline output on a Simulator, it doesn't support metal.")
            #else
                let commandBuffer = commandQueue.makeCommandBuffer()

                let scaledImage = image.applying(CGAffineTransform.aspectFill(from: image.extent, to: CGRect(origin: CGPoint.zero, size: drawableSize)))
                context.render(scaledImage, to: currentDrawable.texture, commandBuffer: commandBuffer, bounds: scaledImage.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
                commandBuffer.present(currentDrawable)
                commandBuffer.commit()
            #endif
        }
    }
}
