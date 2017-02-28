//
//  HTADataManager.m
//  How To Adult
//
//  Created by Nathan Fennel on 2/27/17.
//  Copyright © 2017 Nathan Fennel. All rights reserved.
//

#import "HTADataManager.h"

@implementation HTADataManager {
    NSMutableArray *_rows;
}

+ (instancetype)sharedManager {
    static HTADataManager *sharedManager;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = HTADataManager.new;
    });

    return sharedManager;
}

+ (NSMutableArray<HTARowModel *> *)rows {
    return HTADataManager.sharedManager.rows;
}

- (NSMutableArray <HTARowModel *> *)rows {

    if (!_rows) {
        _rows = @[].mutableCopy;
        [HTADataManager calculatePrimes];
    }

    return _rows;
}





+ (void)calculatePrimes {
    NSMutableArray <NSNumber *> * potentialValues = @[].mutableCopy;
    NSMutableArray <NSNumber *> * primes = @[].mutableCopy;
    for (int i = 0; i < 1000; i++) {
        [potentialValues addObject:@YES];
    }

    for (int i = 2; i < potentialValues.count; i++) {
        BOOL iIsPrime = potentialValues[i].boolValue;

        if (iIsPrime) {
            [primes addObject:@(i)];
            for (int composite = i; composite < potentialValues.count; composite += i) {
                potentialValues[composite] = @NO;
            }
        }
    }

    NSLog(@"%@", primes);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"HTADataManager rows: %@", HTADataManager.rows);
    });

    for (NSNumber *prime in primes) {
        HTARowModel *row = HTARowModel.new;
        row.title = prime.description;
        [HTADataManager.sharedManager.rows addObject:row];
    }

}

@end
