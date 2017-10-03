/*
 File: InfiniteScrollView.m
 Abstract: This view tiles UIView instances to give the effect of infinite scrolling side to side.
 Version: 1.2

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (C) 2013 Apple Inc. All Rights Reserved.

 */

#import "InfiniteScrollView.h"

@interface InfiniteScrollView ()

@property (nonatomic, strong) NSMutableArray *visibleSubviews;
@property (nonatomic, strong) UIView *subviewContainerView;

@end


@implementation InfiniteScrollView

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder]))
    {
        self.contentSize = CGSizeMake(CGFLOAT_MAX, self.frame.size.height);

        _visibleSubviews = [[NSMutableArray alloc] init];

        _subviewContainerView = [[UIView alloc] init];
        self.subviewContainerView.frame = CGRectMake(0, 0, self.contentSize.width, self.contentSize.height);
        [self addSubview:self.subviewContainerView];

        [self.subviewContainerView setUserInteractionEnabled:NO];

        // hide horizontal scroll indicator so our recentering trick is not revealed
        [self setShowsHorizontalScrollIndicator:NO];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.contentSize = CGSizeMake(CGFLOAT_MAX, self.frame.size.height);

        _visibleSubviews = [[NSMutableArray alloc] init];

        _subviewContainerView = [[UIView alloc] init];
        self.subviewContainerView.frame = CGRectMake(0, 0, self.contentSize.width, self.contentSize.height);
        [self addSubview:self.subviewContainerView];

        [self.subviewContainerView setUserInteractionEnabled:NO];

        // hide horizontal scroll indicator so our recentering trick is not revealed
        [self setShowsHorizontalScrollIndicator:NO];
    }
    return self;
}


#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    self.contentSize = CGSizeMake(CGFLOAT_MAX, self.frame.size.height);
    self.subviewContainerView.frame = CGRectMake(0, 0, self.contentSize.width, self.contentSize.height);

    // tile content in visible bounds
    CGRect visibleBounds = [self convertRect:[self bounds] toView:self.subviewContainerView];
    CGFloat minimumVisibleX = CGRectGetMinX(visibleBounds);
    CGFloat maximumVisibleX = CGRectGetMaxX(visibleBounds);

    [self tileViewsFromMinX:minimumVisibleX toMaxX:maximumVisibleX];
}


#pragma mark - Label Tiling

- (UIView *)insertView:(NSInteger)tag {
    UIView *view = [[UIView alloc] initWithFrame:self.bounds];
    view.tag = tag;
    if (self.debug) {
        view.layer.borderColor = [UIColor redColor].CGColor;
        view.layer.borderWidth = 2;
        view.layer.cornerRadius = 4;

        UILabel *label = [[UILabel alloc] initWithFrame:view.bounds];
        label.text = [NSString stringWithFormat:@"%@", @(tag)];
        label.font = [UIFont systemFontOfSize:48];
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = [UIColor redColor];
        [view addSubview:label];
    }
    [self.subviewContainerView addSubview:view];

    return view;
}

- (CGFloat)placeNewViewOnRight:(CGFloat)rightEdge
{
    NSInteger tag = self.visibleSubviews.lastObject.tag;
    UIView *view = [self insertView:tag + 1];
    [self.visibleSubviews addObject:view]; // add rightmost label at the end of the array

    CGRect frame = [view frame];
    frame.origin.x = rightEdge;
    frame.origin.y = [self.subviewContainerView bounds].size.height - frame.size.height;
    [view setFrame:frame];

    return CGRectGetMaxX(frame);
}

- (CGFloat)placeNewLabelOnLeft:(CGFloat)leftEdge {
    NSInteger tag = self.visibleSubviews.firstObject.tag;
    UIView *view = [self insertView:tag - 1];
    [self.visibleSubviews insertObject:view atIndex:0]; // add leftmost label at the beginning of the array

    CGRect frame = [view frame];
    frame.origin.x = leftEdge - frame.size.width;
    frame.origin.y = [self.subviewContainerView bounds].size.height - frame.size.height;
    [view setFrame:frame];

    return CGRectGetMinX(frame);
}

- (void)tileViewsFromMinX:(CGFloat)minimumVisibleX toMaxX:(CGFloat)maximumVisibleX {
    // the upcoming tiling logic depends on there already being at least one view in the visibleViewss array, so
    // to kick off the tiling we need to make sure there's at least one view
    if ([self.visibleSubviews count] == 0)
    {
        [self placeNewViewOnRight:minimumVisibleX];
    }

    // add views that are missing on right side
    UIView *lastView = [self.visibleSubviews lastObject];
    CGFloat rightEdge = CGRectGetMaxX([lastView frame]);
    while (rightEdge < maximumVisibleX)
    {
        rightEdge = [self placeNewViewOnRight:rightEdge];
    }

    // add labels that are missing on left side
    UIView *firstView = self.visibleSubviews[0];
    CGFloat leftEdge = CGRectGetMinX([firstView frame]);
    while (leftEdge > minimumVisibleX)
    {
        leftEdge = [self placeNewLabelOnLeft:leftEdge];
    }

    // remove labels that have fallen off right edge
    lastView = [self.visibleSubviews lastObject];
    while ([lastView frame].origin.x > maximumVisibleX)
    {
        [lastView removeFromSuperview];
        [self.visibleSubviews removeLastObject];
        lastView = [self.visibleSubviews lastObject];
    }

    // remove views that have fallen off left edge
    firstView = self.visibleSubviews[0];
    while (CGRectGetMaxX([firstView frame]) < minimumVisibleX)
    {
        [firstView removeFromSuperview];
        [self.visibleSubviews removeObjectAtIndex:0];
        firstView = self.visibleSubviews[0];
    }
}

@end

