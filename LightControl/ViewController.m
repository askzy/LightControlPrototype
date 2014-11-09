//
//  ViewController.m
//  LightControl
//
//  Created by Justin Zeus on 11/8/14.
//  Copyright (c) 2014 Zeus Games. All rights reserved.
//

#import "ViewController.h"

#import "AppDelegate.h"
#import "LocationManager.h"

#import <HueSDK_iOS/HueSDK.h>

@interface ViewController () <LocationManagerDelegate>
{
  LocationManager *_locationManager;
  Direction _direction;
  UIButton *_buttonForLight;
  NSMutableDictionary *_lightStatus;
  
  UILabel *_lightNumber;
}

@end

@implementation ViewController

- (void)loadView
{
  self.view = [UIView new];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  _buttonForLight = [UIButton buttonWithType:UIButtonTypeCustom];
  [_buttonForLight addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:_buttonForLight];
  
  _lightNumber = [[UILabel alloc] initWithFrame:CGRectZero];
  _lightNumber.font = [UIFont systemFontOfSize:36];
  _lightNumber.textColor = [UIColor yellowColor];
  [self.view addSubview:_lightNumber];
  
  _lightStatus = [@{@(ONE) : @NO,
                    @(TWO) : @NO,
                    @(THREE) : @NO} mutableCopy];

  _locationManager = [[LocationManager alloc] init];
  _locationManager.delegate = self;
  
  
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Find bridge" style:UIBarButtonItemStylePlain target:self action:@selector(findNewBridgeButtonAction)];
  
  self.navigationItem.title = @"Light Control";
  
  PHNotificationManager *notificationManager = [PHNotificationManager defaultManager];
  // Register for the local heartbeat notifications
  [notificationManager registerObject:self withSelector:@selector(localConnection) forNotification:LOCAL_CONNECTION_NOTIFICATION];
  [notificationManager registerObject:self withSelector:@selector(noLocalConnection) forNotification:NO_LOCAL_CONNECTION_NOTIFICATION];

}


- (void)localConnection{
  PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
  
  // Check if we have connected to a bridge before
  if (cache != nil && cache.bridgeConfiguration != nil && cache.bridgeConfiguration.ipaddress != nil){
    // Check if we are connected to the bridge right now
    if (UIAppDelegate.phHueSDK.localConnected) {
      PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
      for (PHLight *light in cache.lights.allValues) {
        PHLightState *lightState = light.lightState;
        _lightStatus[@([self directionForLightID:light.identifier])] = lightState.on;
      }
      if (_direction != NOTHING) {
        [_buttonForLight setHighlighted:[_lightStatus[@(_direction)] boolValue]];
      }
    }
  }
  NSLog(@"connected %@", _lightStatus);
}

- (void)noLocalConnection{
  NSLog(@"connection lost");
  for (NSUInteger i = 0; i < 4; i++) {
    Direction dir = (Direction)i;
    _lightStatus[@(dir)] = @NO;
  }
  [_buttonForLight setHighlighted:NO];
}


- (void)findNewBridgeButtonAction{
  [UIAppDelegate searchForBridgeLocal];
}


-(void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  _buttonForLight.frame = self.view.bounds;
  [_lightNumber sizeToFit];
  CGRect rect = _lightNumber.frame;
  rect.origin = (CGPoint) {
    .x = CGRectGetMaxX(self.view.bounds) - rect.size.width,
    .y = CGRectGetMaxY(self.view.bounds) - rect.size.height
  };
  _lightNumber.frame = rect;
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)locationManager:(LocationManager *)manager directionDidChange:(Direction)direction
{
  NSLog(@"direction changed to :%@, light status: %@", @(direction), _lightStatus);
  _direction = direction;
  switch (direction) {
    case ONE:
    case TWO:
    case THREE:
      [_buttonForLight setImage:[UIImage imageNamed:@"bulb_off"] forState:UIControlStateNormal];
      [_buttonForLight setImage:[UIImage imageNamed:@"bulb"] forState:UIControlStateHighlighted];
      [_buttonForLight setHighlighted:[_lightStatus[@(direction)] boolValue]];
      _lightNumber.text = [self lightIDForDirection:_direction];
      [self.view setNeedsLayout];
      break;
    case NOTHING:
      [_buttonForLight setImage:[UIImage imageNamed:@"logo"] forState:UIControlStateNormal];
      [_buttonForLight setImage:nil forState:UIControlStateHighlighted];
      [_buttonForLight setHighlighted:NO];
      break;
  }
  [self.view bringSubviewToFront:_buttonForLight];
}

- (void)buttonPressed
{
  if (_direction == NOTHING) {
    return;
  }
  BOOL newStatus = ![_lightStatus[@(_direction)] boolValue];
  
  PHBridgeSendAPI *bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
  PHLightState *lightState = [[PHLightState alloc] init];
  lightState.on = @(newStatus);
  [lightState setHue:[NSNumber numberWithInt:arc4random() % 65535]];
  [lightState setBrightness:[NSNumber numberWithInt:254]];
  [lightState setSaturation:[NSNumber numberWithInt:254]];

  
  __weak __typeof(self) weakSelf = self;
  Direction direction = _direction;
  
  [bridgeSendAPI updateLightStateForId:[self lightIDForDirection:_direction] withLightState:lightState completionHandler:^(NSArray *errors) {
    if (errors != nil) {
      NSString *message = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Errors", @""), errors != nil ? errors : NSLocalizedString(@"none", @"")];
      
      NSLog(@"Response: %@",message);
    } else {
      dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf handleLightChange:direction newStatus:newStatus];
      });
    }
  }];
}

- (void)handleLightChange:(Direction)direction newStatus:(BOOL)newStatus
{
  _lightStatus[@(direction)] = @(newStatus);
  if (direction == _direction) {
    [_buttonForLight setHighlighted:newStatus];
  }
}

- (NSUInteger)directionForLightID:(NSString *)lightID
{
  if ([lightID isEqualToString:@"2"]) {
    return TWO;
  } else if ([lightID isEqualToString:@"1"]) {
    return ONE;
  } else if ([lightID isEqualToString:@"3"]) {
    return THREE;
  }
  return NOTHING;
}

- (NSString *)lightIDForDirection:(Direction)dir
{
  switch (dir) {
    case ONE:
      return @"1";
    case TWO:
      return @"2";
    case THREE:
      return @"3";
    case NOTHING:
      return @"NOTHING";
  }
}

@end
