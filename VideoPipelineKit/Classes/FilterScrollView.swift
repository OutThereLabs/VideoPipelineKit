//
//  FilterScrollView.swift
//  VideoPipelineKit
//
//  Created by Patrick Tescher on 9/22/17.
//

import UIKit

public protocol FilterScrollViewDelegate: class {
    func scrolledTo(visibleFilters: [(CIFilter, CGRect)])
}

public class FilterScrollView: UIView, UIScrollViewDelegate {

    public weak var delegate: FilterScrollViewDelegate?

    public var filters = [(CIFilter, String?)]()

    lazy var scrollView: InfiniteScrollView = {
        let scrollView = InfiniteScrollView()
        scrollView.decelerationRate = UIScrollViewDecelerationRateFast
        scrollView.isPagingEnabled = true
        scrollView.debug = false
        return scrollView
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        scrollView.frame = bounds
        addSubview(scrollView)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        scrollView.frame = bounds
        addSubview(scrollView)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
    }

    var sortedVisibleSubviews: [UIView] {
        return scrollView.visibleSubviews.flatMap { $0 as? UIView }.sorted(by: { (firstView, secondView) -> Bool in
            return firstView.tag < secondView.tag
        })
    }

    public var currentFilters: [(CIFilter, CGRect, String?)] {
        guard filters.count > 0 else {
            return [(CIFilter, CGRect, String?)]()
        }

        return sortedVisibleSubviews.flatMap { view -> (CIFilter, CGRect, String?)? in
            let rect = view.convert(view.bounds, to: self)

            guard bounds.intersects(rect) else {
                return nil
            }

            var filterIndex = (view.tag % filters.count)

            if filterIndex < 0 {
                filterIndex += filters.count
            }

            let (filter, name) = filters[filterIndex]

            return (filter, rect, name)
        }
    }
}

