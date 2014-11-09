//
//  AppDelegate.h
//  LightControl
//
//  Created by Justin Zeus on 11/8/14.
//  Copyright (c) 2014 Zeus Games. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <HueSDK_iOS/HueSDK.h>
#import "PHBridgePushLinkViewController.h"

#define UIAppDelegate  ((AppDelegate *)[[UIApplication sharedApplication] delegate])

@interface AppDelegate : UIResponder <UIApplicationDelegate, PHBridgePushLinkViewControllerDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) PHHueSDK *phHueSDK;

#pragma mark - HueSDK

/**
 Starts the local heartbeat
 */
- (void)enableLocalHeartbeat;

/**
 Stops the local heartbeat
 */
- (void)disableLocalHeartbeat;

/**
 Starts a search for a bridge
 */
- (void)searchForBridgeLocal;

@end

