//
//  Utils.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 10/20/17.
//

import Foundation

let timeIntervalFormatter: DateComponentsFormatter = {
    let timeIntervalFormatter = DateComponentsFormatter()
    timeIntervalFormatter.unitsStyle = .full
    timeIntervalFormatter.allowedUnits = [.nanosecond, .second]
    return timeIntervalFormatter
}()
