//
//  HTADataManager.h
//  How To Adult
//
//  Created by Nathan Fennel on 2/27/17.
//  Copyright © 2017 Nathan Fennel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTARowModel.h"

@interface HTADataManager : NSObject

+ (NSMutableArray <HTARowModel *> *)rows;

@end
