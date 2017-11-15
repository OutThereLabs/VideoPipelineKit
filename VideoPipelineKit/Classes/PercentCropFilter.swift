//
//  PercentCropFilter.swift
//  VideoPipelineKit_Example
//
//  Created by Patrick Tescher on 9/25/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import CoreImage

public class PercentCropFilter: CIFilter {
    public var inputImage: CIImage?

    public var inputFirstFilter: CIFilter

    public var inputSecondFilter: CIFilter?

    public var inputPercent: CGFloat

    public init(firstFilter: CIFilter, secondFilter: CIFilter?, percent: CGFloat = 0) {
        inputFirstFilter = firstFilter
        inputSecondFilter = secondFilter
        inputPercent = percent
        super.init()
    }

    required public init?(coder aDecoder: NSCoder) {
        inputFirstFilter = aDecoder.decodeObject(forKey: "inputFirstFilter") as! CIFilter
        inputSecondFilter = aDecoder.decodeObject(forKey: "inputSecondFilter") as? CIFilter
        inputPercent = CGFloat(aDecoder.decodeDouble(forKey: "inputPercent"))
        super.init(coder: aDecoder)
    }

    public override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(inputFirstFilter, forKey: "inputFirstFilter")
        aCoder.encode(inputSecondFilter, forKey: "inputSecondFilter")
        aCoder.encode(inputPercent, forKey: "inputPercent")
    }

    override public var outputImage: CIImage? {
        guard let inputImage = inputImage else {
            return nil
        }

        inputFirstFilter.setValue(inputImage, forKey: kCIInputImageKey)

        guard let firstFilteredImage = inputFirstFilter.outputImage else {
            return inputImage
        }

        guard let secondFilter = inputSecondFilter, inputPercent > 0 else {
            return firstFilteredImage
        }

        secondFilter.setValue(inputImage, forKey: kCIInputImageKey)

        guard let secondFilteredImage = secondFilter.outputImage else {
            return firstFilteredImage
        }

        if inputPercent >= 1 {
            return secondFilteredImage
        }

        var secondCropRect = inputImage.extent
        let secondCropWidth = inputImage.extent.width * inputPercent
        secondCropRect.size.width = secondCropWidth
        secondCropRect.origin.x = (inputImage.extent.width - secondCropWidth)

        let croppedSecondFilterImage = secondFilteredImage.cropped(to: secondCropRect)

        let combinedImage = croppedSecondFilterImage.composited(over: firstFilteredImage)

        return combinedImage
    }
}
