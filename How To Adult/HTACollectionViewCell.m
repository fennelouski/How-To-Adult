//
//  HTACollectionViewCell.m
//  How To Adult
//
//  Created by Nathan Fennel on 2/23/17.
//  Copyright © 2017 Nathan Fennel. All rights reserved.
//

#import "HTACollectionViewCell.h"

@interface HTACollectionViewCell ()

@property (nonatomic, strong) UILabel *titleLabel;

@end

@implementation HTACollectionViewCell {
    NSString *_title;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.layer.borderColor = UIColor.greenColor.CGColor;
        self.layer.borderWidth = 6.0f;

        [self.contentView addSubview:self.titleLabel];
    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.titleLabel.text = self.title;
    self.titleLabel.frame = self.titleLabelFrame;
}

- (UILabel *)titleLabel {
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] initWithFrame:self.titleLabelFrame];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
    }

    return _titleLabel;
}

- (CGRect)titleLabelFrame {
    CGRect frame = self.contentView.bounds;

    frame.size.height = 25.0f;

    return frame;
}

- (NSString *)title {
    return _title;
}

- (void)setTitle:(NSString *)title {
    _title = title;
    [self layoutSubviews];
}

@end
