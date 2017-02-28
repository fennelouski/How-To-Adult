//
//  HTALaundryRowModel.m
//  How To Adult
//
//  Created by Nathan Fennel on 2/28/17.
//  Copyright © 2017 Nathan Fennel. All rights reserved.
//

#import "HTALaundryRowModel.h"
#import "HTALaundryViewController.h"

@implementation HTALaundryRowModel

- (instancetype)init {
    self = [super init];

    if (self) {
        self.representativeViewController = [[HTALaundryViewController alloc] init];
    }

    return self;
}

@end
