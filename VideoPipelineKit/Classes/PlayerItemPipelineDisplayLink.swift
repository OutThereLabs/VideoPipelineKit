//
//  PlayerItemPipelineDisplayLink.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 10/3/17.
//

import AVKit

public extension AVPlayerItem {
    public func addDisplayLink(for renderPipeline: RenderPipeline) -> PlayerItemPipelineDisplayLink {
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: renderPipeline.pixelBufferPixelFormatType])
        add(output)

        let preferredTrackTransform = asset.tracks(withMediaType: AVMediaTypeVideo).first?.preferredTransform ?? CGAffineTransform.identity

        return PlayerItemPipelineDisplayLink(videoOutput: output, preferredTrackTransform: preferredTrackTransform, renderPipeline: renderPipeline)
    }
}

public protocol PlayerItemPipelineDisplayLinkDelegate: class {
    func willRender(_ image: CIImage, through pipeline: RenderPipeline)
}

public class PlayerItemPipelineDisplayLink {
    var displayLink: CADisplayLink?

    public weak var delegate: PlayerItemPipelineDisplayLinkDelegate?

    public let videoOutput: AVPlayerItemVideoOutput

    let renderPipeline: RenderPipeline

    let preferredTrackTransform: CGAffineTransform

    public init(videoOutput: AVPlayerItemVideoOutput, preferredTrackTransform: CGAffineTransform, renderPipeline: RenderPipeline) {
        self.videoOutput = videoOutput
        self.preferredTrackTransform = preferredTrackTransform
        self.renderPipeline = renderPipeline
    }

    var running = false

    public func start() {
        running = true
        let displayLink = CADisplayLink(target: self, selector: #selector(PlayerItemPipelineDisplayLink.displayLinkFired(_:)))
        displayLink.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
        self.displayLink = displayLink
    }

    public func end() {
        running = false
        self.displayLink?.remove(from: RunLoop.main, forMode: RunLoopMode.commonModes)
        self.displayLink = nil
    }

    deinit {
        if running {
            end()
        }
    }

    @objc func displayLinkFired(_ displayLink: CADisplayLink) {
        let nextFrameTime = displayLink.timestamp
        let time = videoOutput.itemTime(forHostTime: nextFrameTime)

        autoreleasepool {
            if videoOutput.hasNewPixelBuffer(forItemTime: time), let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) {
                let image = CIImage(cvPixelBuffer: pixelBuffer).applying(preferredTrackTransform)

                delegate?.willRender(image, through: renderPipeline)
                renderPipeline.render(ciImage: image)
            }
        }
    }
}
