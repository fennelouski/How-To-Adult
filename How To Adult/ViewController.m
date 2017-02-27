//
//  ViewController.m
//  How To Adult
//
//  Created by Nathan Fennel on 2/23/17.
//  Copyright © 2017 Nathan Fennel. All rights reserved.
//

#import "ViewController.h"
#import "HTACollectionViewCell.h"
#import "HTACollectionViewLayout.h"

typedef NS_ENUM(NSUInteger, HTAItems) {
    HTAItemsLaundry,
    HTAItemsCompliments,
    HTAItemsCount = 5000,
};

@interface ViewController () <UICollectionViewDataSource, UICollectionViewDelegate, HTACollectionViewLayoutDelegate>

@property (nonatomic, strong) UICollectionView *collectionView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    [self.view addSubview:self.collectionView];
}

- (UICollectionView *)collectionView {
    if (!_collectionView) {
        HTACollectionViewLayout *layout = [[HTACollectionViewLayout alloc] init];
        layout.delegate = self;

        _collectionView = [[UICollectionView alloc] initWithFrame:self.collectionViewFrame
                                             collectionViewLayout:layout];
        _collectionView.dataSource = self;
        _collectionView.delegate = self;

        [_collectionView registerClass:HTACollectionViewCell.class
            forCellWithReuseIdentifier:HTACollectionViewCell.class.description];
        _collectionView.backgroundColor = [UIColor clearColor];
    }

    return _collectionView;
}

- (CGRect)collectionViewFrame {
    CGRect frame = self.view.bounds;

    frame.origin.y = CGRectGetMaxY(UIApplication.sharedApplication.statusBarFrame);
    frame.size.height -= CGRectGetMaxY(UIApplication.sharedApplication.statusBarFrame);

    return frame;
}






#pragma mark - Collection View Data Source

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    NSInteger numberOfSections = 0;

    if ([collectionView isEqual:self.collectionView]) {
        numberOfSections = 1;
    }

    return numberOfSections;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    NSInteger numberOfItems = 0;

    if ([collectionView isEqual:self.collectionView]) {
        numberOfItems = HTAItemsCount;
    }

    return numberOfItems;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    HTACollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:HTACollectionViewCell.class.description
                                                                            forIndexPath:indexPath];

    if (!cell) {
        cell = [[HTACollectionViewCell alloc] init];
        cell.layer.borderWidth = 5.0f;
        cell.layer.borderColor = UIColor.whiteColor.CGColor;
    }

    return cell;
}





#pragma mark - Layout Delegate

- (CGFloat)heightForCollectionViewCellAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height = 0.0f;

    switch (indexPath.row) {
        case HTAItemsLaundry:
            height = 100.0f;
            break;

        case HTAItemsCompliments:
            height = 50.0f;
            break;

        default:
            height = arc4random()%3 * 50 + 50;
            break;
    }

    return height;
}






#pragma mark - Memory Warning

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
