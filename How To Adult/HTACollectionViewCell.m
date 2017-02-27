//
//  HTACollectionViewCell.m
//  How To Adult
//
//  Created by Nathan Fennel on 2/23/17.
//  Copyright © 2017 Nathan Fennel. All rights reserved.
//

#import "HTACollectionViewCell.h"

@implementation HTACollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.layer.borderColor = UIColor.greenColor.CGColor;
        self.layer.borderWidth = 6.0f;
    }

    return self;
}

@end
