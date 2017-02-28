//
//  HTARowModel.h
//  How To Adult
//
//  Created by Nathan Fennel on 2/27/17.
//  Copyright © 2017 Nathan Fennel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface HTARowModel : NSObject

@property (nonatomic, strong) NSString *title;

@property (nonatomic, strong) UIViewController *representativeViewController;

@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, strong) UIColor *textColor;

/// Height relative to screen's maximum dimension.
/// Default is 0.3f
@property CGFloat proportionalHeight;
/// Maximum height the cell can be, regardless of proportional height.
/// Default is screen's minimum dimension
@property CGFloat maxHeight;
/// Minimum height the cell can be. Overrides maxHeight if maxHeight < minHeight
/// Default is 0.0f
@property CGFloat minHeight;


@end
