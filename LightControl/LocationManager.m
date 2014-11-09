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
  NSLog(@"%@", newHeading);
  Direction newDirection = (Direction)((NSUInteger)(((double)newHeading.trueHeading + 45.0) / 90.0)) % 4;
  if (newDirection != _direction) {
    _direction = newDirection;
    [_delegate locationManager:self directionDidChange:_direction];
  }
}

@end
