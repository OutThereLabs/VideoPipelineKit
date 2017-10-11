//
//  AVMutableVideoComposition+CroppedMedia.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 10/2/17.
//

import AVFoundation

public extension AVMutableVideoComposition {
    convenience init(propertiesOf asset: AVAsset, croppedTo cropRectangle: CGRect?, filter: CIFilter? = nil, overlay: UIImage? = nil) {
        self.init()
        customVideoCompositorClass = RenderPipelineCompositor.self
        frameDuration = CMTime(seconds: 1, preferredTimescale: 600)


        for assetTrack in asset.tracks {
            if assetTrack.mediaType == AVMediaTypeVideo {
                renderSize = assetTrack.naturalSize.applying(assetTrack.preferredTransform)

                let cropInstruction = self.cropInstruction(for: assetTrack, croppedTo: cropRectangle, filter: filter, overlay: overlay, duration: assetTrack.timeRange.duration)
                instructions.append(cropInstruction)
                frameDuration = min(CMTime(seconds: Double(1 / assetTrack.nominalFrameRate), preferredTimescale: 600), frameDuration)
            }
        }

        if let cropRectangle = cropRectangle {
            renderSize = cropRectangle.size
        }
    }

    func cropInstruction(for track: AVAssetTrack, croppedTo cropRectangle: CGRect? = nil, filter: CIFilter? = nil, overlay: UIImage? = nil, duration: CMTime) -> AVVideoCompositionInstruction {
        let instruction = AVMutableVideoCompositionInstruction()

        let trackRange = CMTimeRange(start: kCMTimeZero, duration: duration)

        let renderPipeline = RenderPipeline(config: .defaultConfig, size: renderSize)
        renderPipeline.filters = [filter].flatMap { $0 }
        renderPipeline.overlay = overlay

        let layerInstruction = RenderPipelineLayerInstruction(assetTrack: track, renderPipeline: renderPipeline)
        layerInstruction.setTransform(track.preferredTransform, at: kCMTimeZero)
        
        if let cropRectangle = cropRectangle {
            layerInstruction.setPostTransformCropRectangle(cropRectangle, at: kCMTimeZero)
        }

        instruction.timeRange = trackRange
        instruction.layerInstructions = [layerInstruction]

        return instruction
    }
}

