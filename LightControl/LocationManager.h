//
//  LocationManager.h
//  LightControl
//
//  Created by Justin Zeus on 11/8/14.
//  Copyright (c) 2014 Zeus Games. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, Direction)
{
  NORTH,
  EAST,
  SOUTH,
  WEST
};

@class LocationManager;

@protocol LocationManagerDelegate <NSObject>

- (void)locationManager:(LocationManager *)manager directionDidChange:(Direction)direction;

@end


@interface LocationManager : NSObject

@property (nonatomic, weak) id<LocationManagerDelegate> delegate;

@end

