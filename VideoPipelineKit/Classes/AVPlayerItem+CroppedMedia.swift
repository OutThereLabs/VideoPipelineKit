//
//  AVPlayerItem+CroppedMedia.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 10/4/17.
//

import AVFoundation

extension AVPlayerItem {
    public convenience init(asset: AVAsset, croppedTo cropRectangle: CGRect) throws {
        let composition = AVMutableComposition()
        try composition.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: asset.duration), of: asset, at: kCMTimeZero)

        let videoComposition = AVMutableVideoComposition(propertiesOf: asset, croppedTo: cropRectangle)
        videoComposition.customVideoCompositorClass = RenderPipelineCompositor.self
        videoComposition.renderSize = cropRectangle.size

        self.init(asset: composition)
        self.videoComposition = videoComposition
    }
}
