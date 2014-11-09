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

#import <AVFoundation/AVFoundation.h>

#import <HueSDK_iOS/HueSDK.h>

@interface ViewController () <LocationManagerDelegate>
{
  LocationManager *_locationManager;
  Direction _direction;
  UIButton *_buttonForLight;
  NSMutableDictionary *_lightStatus;
}

@end

@implementation ViewController

- (void)loadView
{
  self.view = [UIView new];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
  self.view.backgroundColor = [UIColor yellowColor];
  _buttonForLight = [UIButton buttonWithType:UIButtonTypeCustom];
  [_buttonForLight addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:_buttonForLight];
  
  _lightStatus = [@{@(NORTH) : @NO,
                    @(EAST) : @NO,
                    @(SOUTH) : @NO,
                    @(WEST) : @NO} mutableCopy];

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
      [_buttonForLight setEnabled:YES];
      PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
      for (PHLight *light in cache.lights.allValues) {
        PHLightState *lightState = light.lightState;
        _lightStatus[@([self directionForLightID:light.identifier])] = lightState.on;
      }
    } else {
      [_buttonForLight setEnabled:NO];
    }
  }

  for (NSUInteger i = 0; i < 4; i++) {
    Direction dir = (Direction)i;
    // TODO load light status of light @(dir)
    _lightStatus[@(dir)] = @NO;
  }
}

- (void)noLocalConnection{
  for (NSUInteger i = 0; i < 4; i++) {
    Direction dir = (Direction)i;
    _lightStatus[@(dir)] = @NO;
  }
  [_buttonForLight setHighlighted:NO];
  [_buttonForLight setEnabled:NO];
}


- (void)findNewBridgeButtonAction{
  [UIAppDelegate searchForBridgeLocal];
}


-(void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  [_buttonForLight sizeToFit];
  _buttonForLight.center = self.view.center;
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  
  
  //----- SHOW LIVE CAMERA PREVIEW -----
  AVCaptureSession *session = [[AVCaptureSession alloc] init];
  session.sessionPreset = AVCaptureSessionPresetMedium;
  
  AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
  
  captureVideoPreviewLayer.frame = self.view.bounds;
  [self.view.layer addSublayer:captureVideoPreviewLayer];
  
  AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
  
  NSError *error = nil;
  AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
  if (!input) {
    // Handle the error appropriately.
    NSLog(@"ERROR: trying to open camera: %@", error);
  }
  [session addInput:input];
  
  [session startRunning];
}
- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)locationManager:(LocationManager *)manager directionDidChange:(Direction)direction
{
  _direction = direction;
  NSString *imageName = nil;
  switch (direction) {
    case NORTH:
      imageName = @"NorthImage";
      break;
    case SOUTH:
      imageName = @"SouthImage";
      break;
    case EAST:
      imageName = @"EastImage";
      break;
    case WEST:
      imageName = @"WestImage";
      break;
      
    default:
      break;
  }
  [_buttonForLight setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
  [_buttonForLight setImage:[UIImage imageNamed:imageName] forState:UIControlStateHighlighted];
  [_buttonForLight setEnabled:[_lightStatus[@(direction)] boolValue]];
  [self.view bringSubviewToFront:_buttonForLight];
}

- (void)buttonPressed
{
  BOOL newStatus = ![_lightStatus[@(_direction)] boolValue];
  _lightStatus[@(_direction)] = @(newStatus);
  
  PHBridgeSendAPI *bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
  PHLightState *lightState = [[PHLightState alloc] init];
  lightState.on = @(newStatus);
  [lightState setHue:[NSNumber numberWithInt:arc4random() % 65535]];
  [lightState setBrightness:[NSNumber numberWithInt:254]];
  [lightState setSaturation:[NSNumber numberWithInt:254]];
  [bridgeSendAPI updateLightStateForId:[self lightIDForDirection:_direction] withLightState:lightState completionHandler:^(NSArray *errors) {
    if (errors != nil) {
      NSString *message = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Errors", @""), errors != nil ? errors : NSLocalizedString(@"none", @"")];
      
      NSLog(@"Response: %@",message);
    }
  }];
  __weak __typeof(self) weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    __typeof(self) strongSelf = weakSelf;
    [strongSelf->_buttonForLight setEnabled:newStatus];
  });
}

- (NSUInteger)directionForLightID:(NSString *)lightID
{
  if ([lightID isEqualToString:@"EAST"]) {
    return EAST;
  } else if ([lightID isEqualToString:@"WEST"]) {
    return WEST;
  } else if ([lightID isEqualToString:@"NORTH"]) {
    return NORTH;
  } else if ([lightID isEqualToString:@"SOUTH"]) {
    return SOUTH;
  }
  return 100;
}

- (NSString *)lightIDForDirection:(Direction)dir
{
  switch (dir) {
    case NORTH:
      return @"NORTH";
    case SOUTH:
      return @"SOUTH";
    case EAST:
      return @"EAST";
    case WEST:
      return @"WEST";
    default:
      break;
  }
}

@end
