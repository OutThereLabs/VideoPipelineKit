//
//  AVPlayerItem+CroppedMedia.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 10/4/17.
//

import AVFoundation

extension AVPlayerItem {
    public convenience init(asset: AVAsset, croppedTo cropRectangle: CGRect?) throws {
        let composition = AVMutableComposition()
        try composition.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: asset.duration), of: asset, at: kCMTimeZero)

        self.init(asset: composition)

        if let cropRectangle = cropRectangle {
            let videoComposition = AVMutableVideoComposition(propertiesOf: asset, croppedTo: cropRectangle)
            videoComposition.customVideoCompositorClass = RenderPipelineCompositor.self
            videoComposition.renderSize = cropRectangle.size

            self.videoComposition = videoComposition
        }
    }

    public convenience init(assets: [AVAsset], croppedTo cropRectangle: CGRect?) throws {
        let composition = AVMutableComposition()

        let assetTracks = assets.flatMap { $0.tracks }

        for assetTrack in assetTracks {
            let compositionTrack = composition.addMutableTrack(withMediaType: assetTrack.mediaType, preferredTrackID: kCMPersistentTrackID_Invalid)
            try compositionTrack?.insertTimeRange(assetTrack.timeRange, of: assetTrack, at: kCMTimeZero)
        }

        self.init(asset: composition)

        guard let firstVideoAsset = assets.first(where: {asset in
            return asset.tracks(withMediaType:AVMediaType.video).count > 0
        }) else {
            return
        }

        if let cropRectangle = cropRectangle {
            let videoComposition = AVMutableVideoComposition(propertiesOf: firstVideoAsset, croppedTo: cropRectangle)
            videoComposition.customVideoCompositorClass = RenderPipelineCompositor.self
            videoComposition.renderSize = cropRectangle.size
            self.videoComposition = videoComposition
        } else {
            self.videoComposition = AVVideoComposition(propertiesOf: firstVideoAsset)
        }
    }
}
