//
//  KFTunableSpec.m
//  TunableSpec
//
//  Created by Ken Ferry on 4/29/13.
//  Copyright (c) 2013 Ken Ferry.
//  See LICENSE for details.
//

#import "KFTunableSpec.h"
#import <QuartzCore/QuartzCore.h>

static UIImage *CloseImage();

@interface _KFSpecItem : NSObject {
    NSMapTable *_maintenanceBlocksByOwner;
    id _objectValue;
}
@property (nonatomic) NSString *key;
@property (nonatomic) NSString *label;

@property (nonatomic) id objectValue;
@property (nonatomic) id defaultValue;

- (void)withOwner:(id)weaklyHeldOwner maintain:(void (^)(id owner, id objValue))maintenanceBlock;

// override this
- (UIView *)tuningView;

@end

@implementation _KFSpecItem

+ (NSArray *)propertiesForJSONRepresentation {
    return @[@"key", @"label"];
}

- (id)initWithJSONRepresentation:(NSDictionary *)json {
    if (json[@"key"] == nil) return nil;
    
    self = [super init];
    if (self) {
        for (NSString *prop in [[self class] propertiesForJSONRepresentation]) {
            [self setValue:json[prop] forKey:prop];
        }
        
        [self setDefaultValue:[self objectValue]];
        _maintenanceBlocksByOwner = [NSMapTable weakToStrongObjectsMapTable];
    }
    return self;
}

- (id)init
{
    NSAssert(0, @"must use initWithJSONRepresentation");
    return self;
}

- (void)withOwner:(id)weaklyHeldOwner maintain:(void (^)(id owner, id objValue))maintenanceBlock {
    NSMutableArray *maintenanceBlocksForOwner = [_maintenanceBlocksByOwner objectForKey:weaklyHeldOwner];
    if (!maintenanceBlocksForOwner) {
        maintenanceBlocksForOwner = [NSMutableArray array];
        [_maintenanceBlocksByOwner setObject:maintenanceBlocksForOwner forKey:weaklyHeldOwner];
    }
    [maintenanceBlocksForOwner addObject:maintenanceBlock];
    maintenanceBlock(weaklyHeldOwner, [self objectValue]);
}

-(id)objectValue {
    return _objectValue;
}

- (void)setObjectValue:(id)objectValue {
    if (![_objectValue isEqual:objectValue]) {
        _objectValue = objectValue;
        objectValue = [self objectValue];
        for (id owner in _maintenanceBlocksByOwner) {
            for (void (^maintenanceBlock)(id owner, id objValue) in [_maintenanceBlocksByOwner objectForKey:owner]) {
                maintenanceBlock(owner, objectValue);
            }
        }
    }
}

static NSString *CamelCaseToSpaces(NSString *camelCaseString) {
    return [camelCaseString stringByReplacingOccurrencesOfString:@"([a-z])([A-Z])" withString:@"$1 $2" options:NSRegularExpressionSearch range:NSMakeRange(0, [camelCaseString length])];

}

- (NSString *)label {
    return _label ?: CamelCaseToSpaces([self key]);
}

- (UIView *)tuningView {
    NSAssert(0, @"%@ must implement %@ and not call super", [self class], NSStringFromSelector(_cmd));
    return nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:%@", [self key], [self objectValue]];
}

- (NSDictionary *)jsonRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (NSString *prop in [[self class] propertiesForJSONRepresentation]) {
        [dict setObject:[self valueForKey:prop] forKey:prop];
    }
    
    return dict;
}

@end

@interface _KFSilderSpecItem : _KFSpecItem
@property (nonatomic) NSNumber *sliderMinValue;
@property (nonatomic) NSNumber *sliderMaxValue;
@property UISlider *slider;
@end

@implementation _KFSilderSpecItem

+ (NSArray *)propertiesForJSONRepresentation {
    static NSArray *sProps;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sProps = [[super propertiesForJSONRepresentation] arrayByAddingObjectsFromArray:@[@"sliderValue", @"sliderMinValue", @"sliderMaxValue"]];
    });
    return sProps;
}

- (id)initWithJSONRepresentation:(NSDictionary *)json {
    if (json[@"sliderValue"] == nil) {
        return nil;
    } else {
        return [super initWithJSONRepresentation:json];
    }
}

- (UIView *)tuningView {
    if (![self slider]) {
        UISlider *slider = [[UISlider alloc] init];
        [slider setMinimumValue:[[self sliderMinValue] doubleValue]];
        [slider setMaximumValue:[[self sliderMaxValue] doubleValue]];
        [self withOwner:self maintain:^(id owner, id objValue) { [slider setValue:[objValue doubleValue]]; }];
        [slider addTarget:self action:@selector(takeSliderValue:) forControlEvents:UIControlEventValueChanged];
        [slider addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[slider(>=300@720)]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(slider)]];
        [slider addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[slider(>=25@750)]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(slider)]];
        [self setSlider:slider];
    }
    return [self slider];
}

- (void)takeSliderValue:(UISlider *)slider {
    [self setSliderValue:@([slider value])];
}

- (id)sliderValue {
    return [self objectValue];
}

- (void)setSliderValue:(id)sliderValue {
    [self setObjectValue:sliderValue];
}

- (NSNumber *)sliderMinValue {
    return _sliderMinValue ?: @0;
}

- (NSNumber *)sliderMaxValue {
    return _sliderMaxValue ?: @([[self defaultValue] doubleValue]*2);
}

@end

@interface _KFSwitchSpecItem : _KFSpecItem
@property UISwitch *uiSwitch;
@end

@implementation _KFSwitchSpecItem

+ (NSArray *)propertiesForJSONRepresentation {
    static NSArray *sProps;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sProps = [[super propertiesForJSONRepresentation] arrayByAddingObjectsFromArray:@[@"switchValue"]];
    });
    return sProps;
}

- (id)initWithJSONRepresentation:(NSDictionary *)json {
    if (json[@"switchValue"] == nil) {
        return nil;
    } else {
        return [super initWithJSONRepresentation:json];
    }
}

- (UIView *)tuningView {
    if (![self uiSwitch]) {
        UISwitch *uiSwitch = [[UISwitch alloc] init];
        [uiSwitch addTarget:self action:@selector(takeSwitchValue:) forControlEvents:UIControlEventValueChanged];
        [self withOwner:self maintain:^(id owner, id objValue) { [uiSwitch setOn:[objValue boolValue]]; }];
        [self setUiSwitch:uiSwitch];
    }
    return [self uiSwitch];
}

- (void)takeSwitchValue:(UISwitch *)uiSwitch {
    [self setSwitchValue:@([uiSwitch isOn])];
}

- (id)switchValue {
    return [self objectValue];
}

- (void)setSwitchValue:(id)switchValue {
    [self setObjectValue:switchValue];
}

@end

@interface KFTunableSpec () <UIDocumentInteractionControllerDelegate> {
    NSMutableArray *_KFSpecItems;
    NSMutableArray *_savedDictionaryRepresentations;
    NSUInteger _currentSaveIndex;
}
@property UIWindow *window;
@property NSString *name;
@property UIButton *previousButton;
@property UIButton *saveButton;
@property UIButton *defaultsButton;
@property UIButton *revertButton;
@property UIButton *shareButton;
@property UIButton *closeButton;

@property UIDocumentInteractionController *interactionController; // interaction controller doesn't keep itself alive during presentation. lame.
@end

@implementation KFTunableSpec

static NSMutableDictionary *sSpecsByName;
+(void)initialize {
    if (!sSpecsByName) sSpecsByName = [NSMutableDictionary dictionary];
}

+ (id)specNamed:(NSString *)name {
    KFTunableSpec *spec = sSpecsByName[name];
    if (!spec) {
        spec = [[self alloc] initWithName:name];
        sSpecsByName[name] = spec;
    }
    return spec;
}

- (id)initWithName:(NSString *)name {
    self = [super init];
    if (self) {
        [self setName:name];
        _KFSpecItems = [[NSMutableArray alloc] init];
        _savedDictionaryRepresentations = [NSMutableArray array];
        
        NSParameterAssert(name != nil);
        NSURL *jsonURL = [[NSBundle mainBundle] URLForResource:name withExtension:@"json"];
        NSAssert(jsonURL != nil, @"Missing %@.json in resources directory.", name);
        
        NSData *jsonData = [NSData dataWithContentsOfURL:jsonURL];
        NSError *error = nil;
        NSArray *specItemReps = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        NSAssert(specItemReps != nil, @"error decoding %@.json: %@", name, error);

        for (NSDictionary *rep in specItemReps) {
            _KFSpecItem *specItem = nil;
            specItem = specItem ?: [[_KFSilderSpecItem alloc] initWithJSONRepresentation:rep];
            specItem = specItem ?: [[_KFSwitchSpecItem alloc] initWithJSONRepresentation:rep];
            
            if (specItem) {
                [_KFSpecItems addObject:specItem];
            } else {
                NSLog(@"%s: Couldn't read entry %@ in %@. Probably you're missing a key? Check KFTunableSpec.h.", __func__, rep, name);
            }
        }
    }
    return self;
}

- (id)init
{
    return [self initWithName:nil];
}

- (_KFSpecItem *)_KFSpecItemForKey:(NSString *)key {
    for (_KFSpecItem *specItem in _KFSpecItems) {
        if ([[specItem key] isEqual:key]) {
            return specItem;
        }
    }
    NSLog(@"%@:Warning – you're trying to use key \"%@\" that doesn't have a valid entry in %@.json. That's unsupported.", [self class], key, [self name]);
    return nil;
}

- (double)doubleForKey:(NSString *)key {
    return [[[self _KFSpecItemForKey:key] objectValue] doubleValue];
}

- (void)withDoubleForKey:(NSString *)key owner:(id)weaklyHeldOwner maintain:(void (^)(id owner, double doubleValue))maintenanceBlock {
    [[self _KFSpecItemForKey:key] withOwner:weaklyHeldOwner maintain:^(id owner, id objectValue){
        maintenanceBlock(owner, [objectValue doubleValue]);
    }];
}

- (BOOL)boolForKey:(NSString *)key {
    return [[[self _KFSpecItemForKey:key] objectValue] boolValue];
}

- (void)withBoolForKey:(NSString *)key owner:(id)weaklyHeldOwner maintain:(void (^)(id owner, BOOL flag))maintenanceBlock {
    [[self _KFSpecItemForKey:key] withOwner:weaklyHeldOwner maintain:^(id owner, id objectValue){
        maintenanceBlock(owner, [objectValue boolValue]);
    }];
}


- (UIViewController *)makeViewController {
    UIView *mainView = [[UIView alloc] init];
    [mainView setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:0.6]];
    [[mainView layer] setBorderColor:[[UIColor whiteColor] CGColor]];
    [[mainView layer] setCornerRadius:5];
    
    UIView *lastControl = nil;
    for (_KFSpecItem *def in _KFSpecItems) {
        UILabel *label = [[UILabel alloc] init];
        [label setTextColor:[UIColor whiteColor]];
        [label setBackgroundColor:[UIColor clearColor]];
        UIView *control = [def tuningView];
        [label setTranslatesAutoresizingMaskIntoConstraints:NO];
        [label setText:[[def label] stringByAppendingString:@":"]];
        [label setTextAlignment:NSTextAlignmentRight];
        id views = lastControl ? NSDictionaryOfVariableBindings(label, control, lastControl) : NSDictionaryOfVariableBindings(label, control);
        [views enumerateKeysAndObjectsUsingBlock:^(id key, id view, BOOL *stop) {
            [view setTranslatesAutoresizingMaskIntoConstraints:NO];
            [mainView addSubview:view];
        }];
        [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[label]-[control]-(==20@700,>=20)-|" options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
        
        if (lastControl) {
            [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[lastControl]-[control]" options:0 metrics:nil views:views]];
            [mainView addConstraint:[NSLayoutConstraint constraintWithItem:lastControl attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:control attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
        } else {
            [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[control]" options:0 metrics:nil views:views]];
        }
        lastControl = control;
    }
    
    NSMutableDictionary *views = [NSMutableDictionary dictionary];
    for (NSString *op in @[@"revert", @"share"]) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [button setTintColor:[UIColor whiteColor]];
        [button setTitle:[op capitalizedString] forState:UIControlStateNormal];
        [button addTarget:self action:NSSelectorFromString(op) forControlEvents:UIControlEventTouchUpInside];
        [button setTranslatesAutoresizingMaskIntoConstraints:NO];
        [views setObject:button forKey:op];
        [self setValue:button forKey:[op stringByAppendingString:@"Button"]];
        [mainView addSubview:button];
    }
    
    [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(>=20)-[revert(==share)]-[share]-(>=20)-|" options:NSLayoutFormatAlignAllTop metrics:nil views:views]];
    [mainView addConstraint:[NSLayoutConstraint constraintWithItem:views[@"revert"] attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:mainView attribute:NSLayoutAttributeCenterX multiplier:1 constant:-10]];
    
    if (lastControl) {
        [views setObject:lastControl forKey:@"lastControl"];
        [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[lastControl]-[share]-|" options:0 metrics:nil views:views]];
    } else {
        [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[share]-|" options:0 metrics:nil views:views]];
    }
    
    
    // We would like to add a close button on the top left corner of the mainView
    // It sticks out a bit from the mainView. In order to have the part that sticks out stay tappable, we make a contentView that completely contains the closeButton and the mainView.

    UIButton *closeButton = [[UIButton alloc] init];
    [closeButton addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [closeButton setImage:CloseImage() forState:UIControlStateNormal];
    [closeButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [closeButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    
    UIView *contentView = [[UIView alloc] init];
    [mainView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [closeButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [contentView addSubview:mainView];
    [contentView addSubview:closeButton];
    
    // perch close button center on contentView corner, slightly inset
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:closeButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:mainView attribute:NSLayoutAttributeLeading multiplier:1 constant:5]];
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:closeButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:mainView attribute:NSLayoutAttributeTop multiplier:1 constant:5]];
    
    // center mainView in contentView
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:mainView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:mainView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];

    // align edge of close button with contentView
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:closeButton attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:closeButton attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];

    UIViewController *viewController = [[UIViewController alloc] init];
    [viewController setView:contentView];
    return viewController;
}

- (BOOL)controlsAreVisible {
    return [self window] != nil;
}

CGPoint RectCenter(CGRect rect) {
    return CGPointMake(rect.origin.x + rect.size.width/2, rect.origin.y + rect.size.height/2);
}

- (void)setControlsAreVisible:(BOOL)flag {
    if (flag && ![self window]) {        
        UIViewController *viewController = [self makeViewController];
        UIView *contentView = [viewController view];
        if ([self name]) {
            _savedDictionaryRepresentations = [[[NSUserDefaults standardUserDefaults] objectForKey:[self name]] mutableCopy];
        }
        _savedDictionaryRepresentations = _savedDictionaryRepresentations ?: [[NSMutableArray alloc] init];
        _currentSaveIndex = [_savedDictionaryRepresentations count];
        [self validateButtons];
        
        CGSize size = [contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        CGSize limitSize = [[[UIApplication sharedApplication] keyWindow] frame].size;
        size.width = MIN(size.width, limitSize.width);
        size.height = MIN(size.height, limitSize.height);
        CGRect windowBounds = CGRectMake(0, 0, size.width, size.height);
        
        
        UIWindow *window = [[UIWindow alloc] init];
        [window setBounds:windowBounds];
        [window setCenter:RectCenter([[UIScreen mainScreen] applicationFrame])];
        [window setRootViewController:viewController];
        
        [contentView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [window addSubview:contentView];
        
        // center contentView with autolayout, because we're going to resize window if we show the interaction controller
        id views = NSDictionaryOfVariableBindings(contentView);
        id metrics = @{@"width" : @(size.width), @"height" : @(size.height)};
        [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[contentView(width)]" options:0 metrics:metrics views:views]];
        [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[contentView(height)]" options:0 metrics:metrics views:views]];
        [window addConstraint:[NSLayoutConstraint constraintWithItem:window attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
        [window addConstraint:[NSLayoutConstraint constraintWithItem:window attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        
        
        [window makeKeyAndVisible];
        [self setWindow:window];
    }
    if (!flag && [self window]) {
        UIWindow *window = [self window];
        [window setHidden:YES];
        _savedDictionaryRepresentations = nil;
        [self setWindow:nil];
    }
}

- (UIGestureRecognizer *)twoFingerTripleTapGestureRecognizer {
    UITapGestureRecognizer *reco = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_toggleVisible:)];
    [reco setNumberOfTapsRequired:3];
    [reco setNumberOfTouchesRequired:2];
    return reco;
}

- (void)_toggleVisible:(id)sender {
    [self setControlsAreVisible:![self controlsAreVisible]];
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (_KFSpecItem *def in _KFSpecItems) {
        dict[[def key]] = [def objectValue];
    }
    return dict;
}

- (void)restoreFromDictionaryRepresentation:(NSDictionary *)dictionaryRep {
    for (_KFSpecItem *def in _KFSpecItems) {
        id savedVal = [dictionaryRep objectForKey:[def key]];
        if (savedVal) [def setObjectValue:savedVal];
    }
}

- (id)jsonRepresentation {
    NSMutableArray *json = [NSMutableArray array];
    for (_KFSpecItem *def in _KFSpecItems) {
        [json addObject:[def jsonRepresentation]];
    }
    return json;
}

- (NSString *)description {
    NSMutableString *desc = [NSMutableString stringWithFormat:@"<%@:%p \"%@\"", [self class], self, [self name]];
    for (_KFSpecItem *item in _KFSpecItems) {
        [desc appendFormat:@" %@", [item description]];
    }
    [desc appendString:@">"];
    return desc;
}

- (void)log {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[self jsonRepresentation] options:NSJSONWritingPrettyPrinted error:NULL];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"\n%@", jsonString);
}

- (void)save {
    NSDictionary *savedDict = [self dictionaryRepresentation];
    [_savedDictionaryRepresentations addObject:savedDict];
    _currentSaveIndex = [_savedDictionaryRepresentations count];
    [self validateButtons];
    
    if ([self name]) {
        [[NSUserDefaults standardUserDefaults] setObject:_savedDictionaryRepresentations forKey:[self name]];
    }
    
    [self log];
}

- (void)previous {
    if (_currentSaveIndex > 0) {
        _currentSaveIndex--;
        NSDictionary *savedDict = _savedDictionaryRepresentations[_currentSaveIndex];
        [self restoreFromDictionaryRepresentation:savedDict];
    }
    [self validateButtons];
}

- (void)defaults {
    [self log];
    for (_KFSpecItem *item in _KFSpecItems) {
        [item setObjectValue:[item defaultValue]];
    }
    [self validateButtons];
    [self log];
}

- (void)revert {
    [self defaults];
}

- (void)share {
    [self log];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:[self jsonRepresentation] options:NSJSONWritingPrettyPrinted error:&error];
    NSString *tempFilename = [[self name] ?: @"UnnamedSpec" stringByAppendingPathExtension:@"json"];
    NSURL *tempFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:tempFilename] isDirectory:NO];
    [data writeToURL:tempFileURL atomically:YES];
    UIDocumentInteractionController *interactionController = [UIDocumentInteractionController interactionControllerWithURL:tempFileURL];
    [self setInteractionController:interactionController];
    [interactionController setDelegate:self];
    
    [[self window] setFrame:[[[self window] screen] applicationFrame]];
    [[self window] layoutIfNeeded];
    [interactionController presentOptionsMenuFromRect:[[self shareButton] bounds] inView:[self shareButton] animated:YES];
}

- (void)documentInteractionControllerDidDismissOptionsMenu:(UIDocumentInteractionController *)controller {
    [self didFinishShare];
}

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller {
    [self didFinishShare];
}

- (void)didFinishShare {
    [self setInteractionController:nil];
    CGSize contentViewSize = [[[[self window] subviews] lastObject] frame].size;
    [[self window] setBounds:(CGRect){CGPointZero, contentViewSize}];
}

- (void)close {
    [self setControlsAreVisible:NO];
}


- (void)validateButtons {
    [[self previousButton] setEnabled:(_currentSaveIndex > 0)];
}


@end
     
// drawing code generated by http://likethought.com/opacity/
// (I just didn't want to require including image files)

const CGFloat kDrawCloseArtworkWidth = 30.0f;
const CGFloat kDrawCloseArtworkHeight = 30.0f;

void DrawCloseArtwork(CGContextRef context, CGRect bounds)
{
    CGRect imageBounds = CGRectMake(0.0f, 0.0f, kDrawCloseArtworkWidth, kDrawCloseArtworkHeight);
    CGFloat alignStroke;
    CGFloat resolution;
    CGMutablePathRef path;
    CGRect drawRect;
    CGColorRef color;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat stroke;
    CGPoint point;
    CGAffineTransform transform;
    CGFloat components[4];
    
    transform = CGContextGetUserSpaceToDeviceSpaceTransform(context);
    resolution = sqrtf(fabsf(transform.a * transform.d - transform.b * transform.c)) * 0.5f * (bounds.size.width / imageBounds.size.width + bounds.size.height / imageBounds.size.height);
    
    CGContextSaveGState(context);
    CGContextClipToRect(context, bounds);
    CGContextTranslateCTM(context, bounds.origin.x, bounds.origin.y);
    CGContextScaleCTM(context, (bounds.size.width / imageBounds.size.width), (bounds.size.height / imageBounds.size.height));
    
    // Layer 1
    
    alignStroke = 0.0f;
    path = CGPathCreateMutable();
    drawRect = CGRectMake(0.0f, 0.0f, 30.0f, 30.0f);
    drawRect.origin.x = (roundf(resolution * drawRect.origin.x + alignStroke) - alignStroke) / resolution;
    drawRect.origin.y = (roundf(resolution * drawRect.origin.y + alignStroke) - alignStroke) / resolution;
    drawRect.size.width = roundf(resolution * drawRect.size.width) / resolution;
    drawRect.size.height = roundf(resolution * drawRect.size.height) / resolution;
    CGPathAddEllipseInRect(path, NULL, drawRect);
    components[0] = 0.219f;
    components[1] = 0.219f;
    components[2] = 0.219f;
    components[3] = 1.0f;
    color = CGColorCreate(space, components);
    CGContextSetFillColorWithColor(context, color);
    CGColorRelease(color);
    CGContextAddPath(context, path);
    CGContextFillPath(context);
    components[0] = 1.0f;
    components[1] = 1.0f;
    components[2] = 1.0f;
    components[3] = 1.0f;
    color = CGColorCreate(space, components);
    CGContextSetStrokeColorWithColor(context, color);
    CGColorRelease(color);
    stroke = 2.0f;
    stroke *= resolution;
    if (stroke < 1.0f) {
        stroke = ceilf(stroke);
    } else {
        stroke = roundf(stroke);
    }
    stroke /= resolution;
    stroke *= 2.0f;
    CGContextSetLineWidth(context, stroke);
    CGContextSetLineCap(context, kCGLineCapSquare);
    CGContextSaveGState(context);
    CGContextAddPath(context, path);
    CGContextEOClip(context);
    CGContextAddPath(context, path);
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
    CGPathRelease(path);
    
    stroke = 2.5f;
    stroke *= resolution;
    if (stroke < 1.0f) {
        stroke = ceilf(stroke);
    } else {
        stroke = roundf(stroke);
    }
    stroke /= resolution;
    alignStroke = fmodf(0.5f * stroke * resolution, 1.0f);
    path = CGPathCreateMutable();
    point = CGPointMake(10.0f, 20.0f);
    point.x = (roundf(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (roundf(resolution * point.y + alignStroke) - alignStroke) / resolution;
    CGPathMoveToPoint(path, NULL, point.x, point.y);
    point = CGPointMake(20.0f, 10.0f);
    point.x = (roundf(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (roundf(resolution * point.y + alignStroke) - alignStroke) / resolution;
    CGPathAddLineToPoint(path, NULL, point.x, point.y);
    components[0] = 1.0f;
    components[1] = 1.0f;
    components[2] = 1.0f;
    components[3] = 1.0f;
    color = CGColorCreate(space, components);
    CGContextSetStrokeColorWithColor(context, color);
    CGColorRelease(color);
    CGContextSetLineWidth(context, stroke);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextAddPath(context, path);
    CGContextStrokePath(context);
    CGPathRelease(path);
    
    stroke = 2.5f;
    stroke *= resolution;
    if (stroke < 1.0f) {
        stroke = ceilf(stroke);
    } else {
        stroke = roundf(stroke);
    }
    stroke /= resolution;
    alignStroke = fmodf(0.5f * stroke * resolution, 1.0f);
    path = CGPathCreateMutable();
    point = CGPointMake(10.0f, 10.0f);
    point.x = (roundf(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (roundf(resolution * point.y + alignStroke) - alignStroke) / resolution;
    CGPathMoveToPoint(path, NULL, point.x, point.y);
    point = CGPointMake(20.0f, 20.0f);
    point.x = (roundf(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (roundf(resolution * point.y + alignStroke) - alignStroke) / resolution;
    CGPathAddLineToPoint(path, NULL, point.x, point.y);
    components[0] = 1.0f;
    components[1] = 1.0f;
    components[2] = 1.0f;
    components[3] = 1.0f;
    color = CGColorCreate(space, components);
    CGContextSetStrokeColorWithColor(context, color);
    CGColorRelease(color);
    CGContextAddPath(context, path);
    CGContextStrokePath(context);
    CGPathRelease(path);
    
    CGContextRestoreGState(context);
    CGColorSpaceRelease(space);
}

UIImage *CloseImage() {
    CGRect bounds = CGRectMake(0, 0, kDrawCloseArtworkWidth, kDrawCloseArtworkHeight);
    UIGraphicsBeginImageContextWithOptions(bounds.size, NO, [[UIScreen mainScreen] scale]);
    DrawCloseArtwork(UIGraphicsGetCurrentContext(), bounds);
    UIImage *closeImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return closeImage;
}
