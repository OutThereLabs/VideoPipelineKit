//
//  GLKView+RenderPipelineOutput.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 10/12/17.
//

import GLKit

public class GLKViewRenderPipelineOutput: NSObject, GLKViewDelegate, RenderPipelineVideoOutput {
    let glkView: GLKView
    let context: CIContext

    var imageToDraw: CIImage?

    public init(glkView: GLKView, context: CIContext) {
        assert(glkView.delegate == nil, "GLKViewRenderPipelineOutput must be the delegate for its GLKView")
        self.glkView = glkView
        self.context = context
        super.init()
        glkView.delegate = self
    }

    // MARK: - RenderPipelineOutput

    public func render(image: CIImage, context: CIContext, pipeline: RenderPipeline) {
        imageToDraw = image
        glkView.setNeedsDisplay()
    }

    // MARK: - GLKViewDelegate

    public func glkView(_ view: GLKView, drawIn rect: CGRect) {
        guard let imageToDraw = imageToDraw else {
            return
        }

        let startTime = Date()
        context.draw(imageToDraw, in: rect, from: imageToDraw.extent)
        let duration = Date().timeIntervalSince(startTime)
        let durationString = timeIntervalFormatter.string(from: duration) ?? "too long"
        print("It took \(durationString) to draw in GLKView")
    }
}
