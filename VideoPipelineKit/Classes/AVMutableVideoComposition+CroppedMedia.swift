//
//  AVMutableVideoComposition+CroppedMedia.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 10/2/17.
//

import AVFoundation

public extension AVMutableVideoComposition {
    convenience init(propertiesOf asset: AVAsset, croppedTo cropRectangle: CGRect) {
        self.init()
        customVideoCompositorClass = RenderPipelineCompositor.self
        renderSize = cropRectangle.size
        frameDuration = CMTime(seconds: 1, preferredTimescale: 600)

        for assetTrack in asset.tracks {
            if assetTrack.mediaType == AVMediaTypeVideo {
                let cropInstruction = self.cropInstruction(for: assetTrack, croppedTo: cropRectangle, duration: assetTrack.timeRange.duration)
                instructions.append(cropInstruction)
                frameDuration = max(CMTime(seconds: Double(1 / assetTrack.nominalFrameRate), preferredTimescale: 600), frameDuration)
            }
        }
    }

    func cropInstruction(for track: AVAssetTrack, croppedTo cropRectangle: CGRect, duration: CMTime) -> AVVideoCompositionInstruction {
        let instruction = AVMutableVideoCompositionInstruction()

        let trackRange = CMTimeRange(start: kCMTimeZero, duration: duration)

        let layerInstruction = RenderPipelineLayerInstruction(assetTrack: track)

        layerInstruction.setTransform(track.preferredTransform, at: kCMTimeZero)
        layerInstruction.setPostTransformCropRectangle(cropRectangle, at: kCMTimeZero)

        instruction.timeRange = trackRange
        instruction.layerInstructions = [layerInstruction]

        return instruction
    }
}

