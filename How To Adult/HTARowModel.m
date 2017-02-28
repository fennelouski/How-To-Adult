//
//  HTARowModel.m
//  How To Adult
//
//  Created by Nathan Fennel on 2/27/17.
//  Copyright © 2017 Nathan Fennel. All rights reserved.
//

#import "HTARowModel.h"

@implementation HTARowModel

- (NSString *)description {
    NSMutableString *description = [super description].mutableCopy;

    [description appendFormat:@"\n%@", self.title];

    return description;
}

@end
