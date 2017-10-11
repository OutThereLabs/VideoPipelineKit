//
//  AVAssetExportSession+CroppedMedia.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 10/9/17.
//

import AVFoundation
import CoreImage

extension AVAssetExportSession {
    public convenience init?(asset: AVAsset, presetName: String, croppedTo cropRectangle: CGRect?, filter: CIFilter? = nil, overlay: UIImage? = nil) throws {
        let composition = AVMutableComposition()
        try composition.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: asset.duration), of: asset, at: kCMTimeZero)

        self.init(asset: composition, presetName: presetName)

        if cropRectangle == nil, filter == nil, overlay == nil {
            return
        }

        let videoComposition = AVMutableVideoComposition(propertiesOf: asset, croppedTo: cropRectangle, filter: filter, overlay: overlay)
        videoComposition.customVideoCompositorClass = RenderPipelineCompositor.self

        if let renderSize = cropRectangle?.size {
            videoComposition.renderSize = renderSize
        } else {
            videoComposition.renderSize = composition.naturalSize.applying(composition.preferredTransform)
        }

        self.videoComposition = videoComposition
    }
}
