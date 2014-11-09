//
//  LocationManager.m
//  LightControl
//
//  Created by Justin Zeus on 11/8/14.
//  Copyright (c) 2014 Zeus Games. All rights reserved.
//

#import "LocationManager.h"

#import <CoreLocation/CoreLocation.h>

@interface LocationManager () <CLLocationManagerDelegate>
{
  CLLocationManager *_manager;
  CLHeading *_heading;
  Direction _direction;
}

@end

@implementation LocationManager

- (instancetype)init
{
  self = [super init];
  if (self) {
    _manager = [[CLLocationManager alloc] init];
    _manager.delegate = self;
    [self getPermission];
    [self checkAndStartUpdateHeading];
  }
  return self;
}

- (void)getPermission
{
  if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
    [_manager requestWhenInUseAuthorization];
  }
}

- (void)checkAndStartUpdateHeading
{
  if ([CLLocationManager headingAvailable]) {
    [_manager startUpdatingHeading];
  }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
  // 0 is north, 90 is east, 180 is south, 270 is west
  double direction = (double)newHeading.trueHeading;
  
  static double L1Low = 270;
  static double L1High = 300;

  static double L2Low = 50;
  static double L2High = 120;
  
  static double L3Low = 180;
  static double L3High = 240;
  
  Direction newDirection = NOTHING;
  if (direction > L1Low && direction < L1High) {
    newDirection = ONE;
  } else if (direction > L2Low && direction < L2High) {
    newDirection = TWO;
  } else if (direction > L3Low && direction < L3High) {
    newDirection = THREE;
  }
  if (newDirection != _direction) {
    _direction = newDirection;
    [_delegate locationManager:self directionDidChange:_direction];
  }
}

@end
