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
    UIColor *_textColor;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.layer.cornerRadius = 5.0f;
        self.clipsToBounds = YES;
        [self.contentView addSubview:self.titleLabel];
    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.titleLabel.text = self.title;
    self.titleLabel.frame = self.titleLabelFrame;

    self.titleLabel.textColor = self.textColor;
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

- (UIColor *)textColor {
    return _textColor;
}

- (void)setTextColor:(UIColor *)textColor {
    if ([textColor isEqual:_textColor]) {
        return;
    }

    _textColor = textColor;
    [self layoutSubviews];
}

@end
