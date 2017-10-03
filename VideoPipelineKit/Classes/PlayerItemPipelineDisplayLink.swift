//
//  PlayerItemPipelineDisplayLink.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 10/3/17.
//

import AVKit

public extension AVPlayerItem {
    public func addDisplayLink(for renderPipeline: RenderPipeline) -> PlayerItemPipelineDisplayLink {
        let output = AVPlayerItemVideoOutput()
        add(output)
        return PlayerItemPipelineDisplayLink(videoOutput: output, renderPipeline: renderPipeline)
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

    public init(videoOutput: AVPlayerItemVideoOutput, renderPipeline: RenderPipeline) {
        self.videoOutput = videoOutput
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

    let dispatchSemaphore = DispatchSemaphore(value: 1)

    @objc func displayLinkFired(_ displayLink: CADisplayLink) {
        let waitTime = dispatchSemaphore.wait(timeout: DispatchTime.now())
        if waitTime != .success {
            return
        }

        defer {
            dispatchSemaphore.signal()
        }

        let nextFrameTime = displayLink.timestamp + displayLink.duration
        let time = videoOutput.itemTime(forHostTime: nextFrameTime)

        if videoOutput.hasNewPixelBuffer(forItemTime: time), let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) {
            let image = CIImage(cvPixelBuffer: pixelBuffer)
            delegate?.willRender(image, through: renderPipeline)
            renderPipeline.render(image: image)
        }
    }
}
