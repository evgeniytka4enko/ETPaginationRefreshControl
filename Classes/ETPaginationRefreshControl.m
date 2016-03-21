// Copyright (c) 2016 Evgeniy Tkachenko (https://github.com/evgeniytka4enko/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "ETPaginationRefreshControl.h"
#import <objc/runtime.h>

@interface UIScrollView (ETPaginationRefreshControlAdditions)

@property (strong, nonatomic) NSArray<ETPaginationRefreshControl *> *allPaginationRefreshControls;

@end

@implementation UIScrollView (ETPaginationRefreshControlAdditions)

#pragma mark - Overrides

+ (void)load
{
    Method original, swizzled;
    
    original = class_getInstanceMethod(self, @selector(setContentOffset:));
    swizzled = class_getInstanceMethod(self, @selector(swizzleSetContentOffset:));
    method_exchangeImplementations(original, swizzled);
    
    original = class_getInstanceMethod(self, @selector(setContentInset:));
    swizzled = class_getInstanceMethod(self, @selector(swizzleSetContentInset:));
    method_exchangeImplementations(original, swizzled);
    
    original = class_getInstanceMethod(self, @selector(setContentSize:));
    swizzled = class_getInstanceMethod(self, @selector(swizzleSetContentSize:));
    method_exchangeImplementations(original, swizzled);
}

- (void)didAddSubview:(UIView *)subview
{
    if([subview isKindOfClass:[ETPaginationRefreshControl class]])
    {
        self.allPaginationRefreshControls = nil;
    }
}

- (void)swizzleSetContentOffset:(CGPoint)contentOffset
{
    for(ETPaginationRefreshControl *paginationRefreshControl in self.allPaginationRefreshControls)
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        [paginationRefreshControl performSelector:@selector(beginRefreshingIfNeeded)];
#pragma clang diagnostic pop
    }
    
    [self swizzleSetContentOffset:contentOffset];
}

- (void)swizzleSetContentInset:(UIEdgeInsets)contentInset
{
    for(ETPaginationRefreshControl *paginationRefreshControl in self.allPaginationRefreshControls)
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        [paginationRefreshControl performSelector:@selector(updateFrame)];
#pragma clang diagnostic pop
    }
    
    [self swizzleSetContentInset:contentInset];
}

- (void)swizzleSetContentSize:(CGSize)contentSize
{
    for(ETPaginationRefreshControl *paginationRefreshControl in self.allPaginationRefreshControls)
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        [paginationRefreshControl performSelector:@selector(updateFrame)];
#pragma clang diagnostic pop
    }
    
    [self swizzleSetContentSize:contentSize];
}

#pragma mark - Custom accessors

- (void)setAllPaginationRefreshControls:(NSArray<ETPaginationRefreshControl *> *)allPaginationRefreshControls
{
    objc_setAssociatedObject(self, @selector(allPaginationRefreshControls), allPaginationRefreshControls, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<ETPaginationRefreshControl *> *)allPaginationRefreshControls
{
    NSMutableArray<ETPaginationRefreshControl *> *allPaginationRefreshControls = objc_getAssociatedObject(self, @selector(allPaginationRefreshControls));
    
    if(!allPaginationRefreshControls)
    {
        allPaginationRefreshControls = [NSMutableArray array];
        
        for(ETPaginationRefreshControl *paginationRefreshControl in self.subviews)
        {
            if([paginationRefreshControl isKindOfClass:[ETPaginationRefreshControl class]])
            {
                [allPaginationRefreshControls addObject:paginationRefreshControl];
            }
        }
        
        objc_setAssociatedObject(self, @selector(allPaginationRefreshControls), allPaginationRefreshControls, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return allPaginationRefreshControls;
}

@end

@interface ETPaginationRefreshControl ()

@property (assign, nonatomic) ETPaginationRefreshControlType type;

@property (strong, nonatomic) UIActivityIndicatorView *activityIndicatorView;
@property (assign, nonatomic) BOOL refreshing;

@property (weak, nonatomic) UIScrollView *scrollView;

@end

@implementation ETPaginationRefreshControl

#pragma mark - Initialization

- (instancetype)initWithType:(ETPaginationRefreshControlType)type
{
    self = [super init];
    if(self)
    {
        self.type = type;
        [self setupAutoRefreshControl];
    }
    return self;
}

- (void)setupAutoRefreshControl
{
    self.refreshInset = 300.0f;
    self.backgroundColor = [UIColor clearColor];
    [self addSubview:self.activityIndicatorView];
    
    self.userInteractionEnabled = NO;
}

#pragma mark - Overrides

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.activityIndicatorView.center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    self.scrollView = nil;
}

- (void)didMoveToSuperview
{
    if([self.superview isKindOfClass:[UIScrollView class]])
    {
        self.scrollView = (UIScrollView *)self.superview;
        [self updateFrame];
    }
}

- (void)setTintColor:(UIColor *)tintColor
{
    [super setTintColor:tintColor];
    
    self.activityIndicatorView.color = tintColor;
}

#pragma mark - Custom accessors

- (UIActivityIndicatorView *)activityIndicatorView
{
    if(!_activityIndicatorView)
    {
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _activityIndicatorView.hidden = YES;
    }
    return _activityIndicatorView;
}

#pragma mark - Public

- (void)beginRefreshing
{
    if(!self.enabled)
    {
        self.enabled = YES;
    }
    self.refreshing = YES;
    
    self.activityIndicatorView.hidden = NO;
    [self.activityIndicatorView startAnimating];
    
    UIEdgeInsets insets = self.scrollView.contentInset;
    
    if(self.type == ETPaginationRefreshControlTypeHeader)
    {
        insets.top += self.bounds.size.height;
    }
    else
    {
        insets.bottom += self.bounds.size.height;
    }
    
    [UIView animateWithDuration:0.3 delay:0.0 options:(UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState) animations:^{
        
        self.scrollView.contentInset = insets;
        
    } completion:nil];
}

- (void)endRefreshing
{
    if(!self.enabled)
    {
        self.enabled = YES;
    }
    if(self.refreshing)
    {
        UIEdgeInsets insets = self.scrollView.contentInset;
        
        if(self.type == ETPaginationRefreshControlTypeHeader)
        {
            insets.top -= self.bounds.size.height;
        }
        else
        {
            insets.bottom -= self.bounds.size.height;
        }
        
        [UIView animateWithDuration:0.3 delay:0.0 options:(UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState) animations:^{
            
            self.scrollView.contentInset = insets;
            
        } completion:^(BOOL finished) {
            
            if(finished)
            {
                self.activityIndicatorView.hidden = YES;
                [self.activityIndicatorView stopAnimating];
            }
            
        }];
        
        self.refreshing = NO;
    }
}

#pragma mark - Private

- (void)updateFrame
{
    CGRect frame = CGRectZero;
    frame.origin.x = self.scrollView.contentInset.left;
    frame.size.width = (self.scrollView.bounds.size.width - self.scrollView.contentInset.left - self.scrollView.contentInset.right);
    frame.size.height = (self.activityIndicatorView.bounds.size.height * 2);
    
    if(self.type == ETPaginationRefreshControlTypeHeader)
    {
        CGFloat sizeThatFitsHeight = [self.scrollView sizeThatFits:CGSizeMake(self.scrollView.bounds.size.width, CGFLOAT_MAX)].height;
        if(sizeThatFitsHeight == 0.0f)
        {
            frame.origin.y = (self.scrollView.bounds.size.height - self.scrollView.contentInset.top - self.scrollView.contentInset.bottom) - frame.size.height;
        }
        else
        {
            frame.origin.y = -frame.size.height;
        }
    }
    else
    {
        frame.origin.y = [self.scrollView sizeThatFits:CGSizeMake(self.scrollView.bounds.size.width, CGFLOAT_MAX)].height;
        
        if([self.scrollView isKindOfClass:[UICollectionView class]])
        {
            UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *)((UICollectionView *)self.scrollView).collectionViewLayout;
            if([flowLayout respondsToSelector:@selector(collectionViewContentSize)])
            {
                CGSize contentSize = flowLayout.collectionViewContentSize;
                frame.origin.y = contentSize.height;
            }
        }
    }
    
    self.frame = frame;
}

- (void)beginRefreshingIfNeeded
{
    if(!self.scrollView.dragging)
    {
        return;
    }
    
    if((self.scrollView.contentOffset.y + self.scrollView.contentInset.top) <= self.refreshInset && self.type == ETPaginationRefreshControlTypeHeader)
    {
        if(self.enabled && !self.refreshing)
        {
            [self beginRefreshing];
            [self sendActionsForControlEvents:UIControlEventValueChanged];
        }
    }
    
    if((self.scrollView.contentOffset.y + self.scrollView.bounds.size.height + self.scrollView.contentInset.top) >= self.scrollView.contentSize.height - self.bounds.size.height - self.refreshInset && self.type == ETPaginationRefreshControlTypeFooter)
    {
        if(self.enabled && !self.refreshing)
        {
            [self beginRefreshing];
            [self sendActionsForControlEvents:UIControlEventValueChanged];
        }
    }
}

@end
