//
//  HTACollectionViewLayout.h
//  How To Adult
//
//  Created by Nathan Fennel on 2/23/17.
//  Copyright © 2017 Nathan Fennel. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol HTACollectionViewLayoutDelegate <NSObject>

- (CGFloat)heightForCollectionViewCellAtIndexPath:(NSIndexPath *)indexPath;

@end

@interface HTACollectionViewLayout : UICollectionViewLayout

@property id <HTACollectionViewLayoutDelegate> delegate;

@end
