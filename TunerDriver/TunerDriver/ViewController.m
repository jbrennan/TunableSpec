//
//  ViewController.m
//  TunerDriver
//
//  Created by Ken Ferry on 4/29/13.
//  Copyright (c) 2013 Ken Ferry.
//  See LICENSE for details.
//

#import "ViewController.h"
#import "TunableSpec.h"

@interface ViewController ()
@property (strong, nonatomic) IBOutlet UILabel *label;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *yConstraint;

@end

@implementation ViewController

- (void)viewDidLoad
{
    TunableSpec *spec = [TunableSpec specNamed:@"MainSpec"];
    [spec withBoolForKey:@"RightAlignLabel" owner:self maintain:^(id owner, BOOL flag) {
        [[owner label] setTextAlignment:flag ? NSTextAlignmentRight : NSTextAlignmentLeft];
    }];
    
    [[self view] addGestureRecognizer:[spec twoFingerTripleTapGestureRecognizer]];

    [super viewDidLoad];
}


- (IBAction)handlePan:(UIPanGestureRecognizer *)reco {
    TunableSpec *spec = [TunableSpec specNamed:@"MainSpec"];
    switch ([reco state]) {
        case UIGestureRecognizerStateBegan: {
        }
            break;
            
        case UIGestureRecognizerStateChanged: {
            CGPoint translation = [reco translationInView:[self view]];
            [[self yConstraint] setConstant:translation.y];
        }
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            CGFloat vel = [reco velocityInView:[self view]].y;
            CGFloat dist = [reco translationInView:[self view]].y;
            CGFloat distMadeSafeForDivision = MAX(abs(dist), 0.1) * ((dist < 0) ? -1 : 1);
            
            CGFloat velInUnitSpace = vel / distMadeSafeForDivision * -1 /* positive velInUnitSpace is always toward final loc. So should be negative whenever raw velocity and distance are of the same sign. For example, above resting pos and moving up should be a negative number in unit space. */;
            
            [UIView animateWithDuration:[spec doubleForKey:@"SpringDuration"]
                                  delay:0
                 usingSpringWithDamping:[spec doubleForKey:@"SpringDamping"]
                  initialSpringVelocity:velInUnitSpace
                                options:0
                             animations:^{
                                 [[self yConstraint] setConstant:0];
                                 [[self view] layoutIfNeeded];
                             } completion:NULL];
        }
            break;
        case UIGestureRecognizerStatePossible:
        case UIGestureRecognizerStateFailed:
            break;
    }

}

@end
