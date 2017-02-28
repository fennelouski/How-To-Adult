//
//  HTARowModel.m
//  How To Adult
//
//  Created by Nathan Fennel on 2/27/17.
//  Copyright © 2017 Nathan Fennel. All rights reserved.
//

#import "HTARowModel.h"

@implementation HTARowModel

- (instancetype)init {
    self = [super init];

    if (self) {
        CGFloat hue = arc4random_uniform(1000) * 0.001f;
        self.backgroundColor = [UIColor colorWithHue:hue
                                          saturation:1.0f
                                          brightness:0.3f
                                               alpha:1.0f];
        self.textColor = [UIColor colorWithHue:hue
                                    saturation:0.3f
                                    brightness:1.0f
                                         alpha:1.0f];

        self.proportionalHeight = 0.3f;
        self.maxHeight = MIN(CGRectGetHeight(UIScreen.mainScreen.bounds), CGRectGetWidth(UIScreen.mainScreen.bounds));
    }

    return self;
}

- (NSString *)description {
    NSMutableString *description = [super description].mutableCopy;

    [description appendFormat:@"\n%@", self.title];

    return description;
}

@end
