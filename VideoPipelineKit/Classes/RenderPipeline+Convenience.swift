//
//  RenderPipeline+Convenience.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 9/21/17.
//

import Foundation
import QuartzCore

extension RenderPipeline {
    public func createPreviewLayer(withSize size: CGSize? = nil) -> CALayer {
        switch config {
        case .metal(let device):
            let layer = RenderPipelineMetalLayer()
            layer.framebufferOnly = false
            layer.device = device
            if let size = size {
                layer.drawableSize = size
            }
            add(output: layer)
            return layer
        }
    }
}
