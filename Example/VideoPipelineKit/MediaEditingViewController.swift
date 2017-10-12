//
//  MediaEditingViewController.swift
//  VideoPipelineKit_Example
//
//  Created by Patrick Tescher on 9/21/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit
import AVKit
import MetalKit
import GLKit
import VideoPipelineKit

class MediaEditingViewController: UIViewController, PlayerItemPipelineDisplayLinkDelegate {

    var playerObserver: Any?

    var displayLink: PlayerItemPipelineDisplayLink?

    lazy var player: AVQueuePlayer = {
        let player = AVQueuePlayer()
        self.playerObserver = player.observe(\.currentItem, changeHandler: { [weak self] (player, change) in
            if let displayLink = self?.displayLink {
                displayLink.end()
                if let item = change.oldValue, item?.outputs.contains(displayLink.videoOutput) == true {
                    item?.remove(displayLink.videoOutput)
                }
            }

            if let item = player.currentItem, let renderPipeline = self?.renderPipeline {
                let displayLink = item.addDisplayLink(for: renderPipeline)
                displayLink.delegate = self
                displayLink.start()
                self?.displayLink = displayLink
            }
        })
        return player
    }()

    let instantFilter: CIFilter = {
        let filter = CIFilter(name: "CIPhotoEffectInstant")!
        return filter
    }()

    let monoFilter: CIFilter = {
        let filter = CIFilter(name: "CIPhotoEffectMono")!
        return filter
    }()

    let skinFilter: CIFilter = {
        let filter = CIFilter(name: "YUCIHighPassSkinSmoothing")!
        return filter
    }()

    lazy var initialSwipeFilter: PercentCropFilter = {
        let swipeFilter = PercentCropFilter(firstFilter: self.monoFilter, secondFilter: self.skinFilter)
        return swipeFilter
    }()

    func updateSwipeFilterBasedOnScrollView() {
        let currentFilters = filterScrollView.currentFilters

        guard let firstFilter = currentFilters.first?.0 else { return assertionFailure() }

        let inputPercent: CGFloat

        if let rectTwo = currentFilters.last?.1, currentFilters.count > 1 {
            let visibleSecondRect = filterScrollView.bounds.intersection(rectTwo)
            inputPercent = visibleSecondRect.size.width / view.bounds.width
        } else {
            inputPercent = 0
        }

        if inputPercent >= 1 {
            assertionFailure()
        }

        let swipeFilter = PercentCropFilter(firstFilter: firstFilter, secondFilter: currentFilters.last?.0, percent: inputPercent)
        renderPipeline.filters = [swipeFilter]
    }

    lazy var renderPipeline: RenderPipeline = {
        let config = RenderPipeline.Config.defaultConfig
        let renderPipeline = RenderPipeline(config: config, size: cropRect.size)
        renderPipeline.filters.append(self.initialSwipeFilter)
        renderPipeline.size = self.cropRect.size
        return renderPipeline
    }()

    @IBOutlet weak var metalOutput: MTKView!
    @IBOutlet weak var eaglOutput: GLKView!

    @IBOutlet weak var filterScrollView: FilterScrollView!

    var looper: AVPlayerLooper?

    var cropRect = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 607.5, height: 1080))

    var asset: AVURLAsset? {
        didSet {
            guard let asset = asset else {
                looper = nil
                player.removeAllItems()
                return
            }

            do {
                let playerItem = try AVPlayerItem(asset: asset, croppedTo: cropRect)
                looper = AVPlayerLooper(player: player, templateItem: playerItem)
            } catch {
                print("Error cropping asset item: \(error)")
                let playerItem = AVPlayerItem(asset: asset)
                looper = AVPlayerLooper(player: player, templateItem: playerItem)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        switch renderPipeline.config {
        case .metal:
            eaglOutput.isHidden = true
            metalOutput.isHidden = false
            renderPipeline.add(output: metalOutput)
        case .eagl(let context):
            eaglOutput.isHidden = false
            metalOutput.isHidden = true
            let output = GLKViewRenderPipelineOutput(glkView: eaglOutput, context: renderPipeline.imageContext)
            renderPipeline.add(output: output)
            eaglOutput.context = context
        }

        filterScrollView.filters = [(instantFilter, "Instant"), (monoFilter, "Mono"), (skinFilter, "Skin")]
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        player.play()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player.pause()
    }

    // MARK: - PlayerItemPipelineDisplayLinkDelegate

    func willRender(_ image: CIImage, through pipeline: RenderPipeline) {
        updateSwipeFilterBasedOnScrollView()
    }
}
