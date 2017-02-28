//
//  HTACollectionViewLayout.m
//  How To Adult
//
//  Created by Nathan Fennel on 2/23/17.
//  Copyright © 2017 Nathan Fennel. All rights reserved.
//

#import "HTACollectionViewLayout.h"

static const CGFloat cellPadding = 6.0f;

@interface HTACollectionViewLayout ()

@property (nonatomic) CGFloat contentHeight;
@property (nonatomic) CGFloat contentWidth;

@property (nonatomic, strong) NSMutableArray *cache;

@end

@implementation HTACollectionViewLayout

- (instancetype)init {
    self = [super init];

    if (self) {
        self.cache = @[].mutableCopy;
    }

    return self;
}

- (void)prepareLayout {
    if (self.cache.count == 0) {
        NSUInteger numberOfColumns = 1;
        if ([self.delegate respondsToSelector:@selector(numberOfColumns)]) {
            numberOfColumns = [self.delegate numberOfColumns];
        }

        CGFloat columnWidth = self.contentWidth / (CGFloat)numberOfColumns;
        NSMutableArray <NSNumber *> *xOffsets = @[].mutableCopy;
        NSMutableArray <NSNumber *> *yOffsets = @[].mutableCopy;
        for (NSUInteger column = 0; column < numberOfColumns; column++) {
            [xOffsets addObject:@(column * columnWidth)];
            [yOffsets addObject:@(0)];
        }

        NSUInteger column = 0;

        for (NSUInteger itemNumber = 0; itemNumber < [self.collectionView numberOfItemsInSection:0]; itemNumber++) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:itemNumber
                                                        inSection:0];

            CGFloat height = cellPadding * 2.0f;
            if ([self.delegate respondsToSelector:@selector(heightForCollectionViewCellAtIndexPath:)]) {
                height += [self.delegate heightForCollectionViewCellAtIndexPath:indexPath];
            }

            CGFloat width = columnWidth - cellPadding * 2;

            CGRect frame = CGRectMake(xOffsets[column].integerValue + cellPadding, yOffsets[column].integerValue, width, height);
            CGRect insetFrame = CGRectInset(frame, cellPadding, cellPadding);

            UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
            attributes.frame = insetFrame;
            [self.cache addObject:attributes];

            self.contentHeight = MAX(self.contentHeight, CGRectGetMaxY(frame));
            yOffsets[column] = @(yOffsets[column].integerValue + height);

            column = column >= (numberOfColumns - 1) ? 0 : ++column;
        }
    }
}

- (CGSize)collectionViewContentSize {
    return CGSizeMake(self.contentWidth, self.contentHeight);
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    NSMutableArray<UICollectionViewLayoutAttributes *> *layoutAttributes = @[].mutableCopy;

    for (UICollectionViewLayoutAttributes *attributes in self.cache) {
        if (CGRectIntersectsRect(attributes.frame, rect)) {
            [layoutAttributes addObject:attributes];
        }
    }
    
    return layoutAttributes;
}

- (CGFloat)contentWidth {
    UIEdgeInsets insets = self.collectionView.contentInset;
    return CGRectGetWidth(self.collectionView.bounds) - (insets.left + insets.right);
}

@end
