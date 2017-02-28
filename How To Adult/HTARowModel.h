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

@end
