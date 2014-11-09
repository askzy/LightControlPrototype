//
//  AppDelegate.m
//  LightControl
//
//  Created by Justin Zeus on 11/8/14.
//  Copyright (c) 2014 Zeus Games. All rights reserved.
//

#import "AppDelegate.h"

#import "ViewController.h"
#import "PHLoadingViewController.h"
#import "PHBridgeSelectionViewController.h"



@interface AppDelegate ()
@property (strong, nonatomic) UINavigationController *navigationController;
@property (nonatomic, strong) UIAlertView *noConnectionAlert;
@property (nonatomic, strong) UIAlertView *noBridgeFoundAlert;
@property (nonatomic, strong) PHLoadingViewController *loadingView;
@property (nonatomic, strong) PHBridgeSearching *bridgeSearch;
@property (nonatomic, strong) PHBridgeSelectionViewController *bridgeSelectionViewController;


@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  
  self.phHueSDK = [[PHHueSDK alloc] init];
  [self.phHueSDK startUpSDK];
  [self.phHueSDK enableLogging:YES];
  
  UIViewController *vc = [[ViewController alloc] init];
  self.navigationController = [[UINavigationController alloc] initWithRootViewController:vc];

  self.window.rootViewController = self.navigationController;
  [self.window makeKeyAndVisible];
  
  PHNotificationManager *notificationManager = [PHNotificationManager defaultManager];
  [notificationManager registerObject:self withSelector:@selector(localConnection) forNotification:LOCAL_CONNECTION_NOTIFICATION];
  [notificationManager registerObject:self withSelector:@selector(noLocalConnection) forNotification:NO_LOCAL_CONNECTION_NOTIFICATION];
  [notificationManager registerObject:self withSelector:@selector(notAuthenticated) forNotification:NO_LOCAL_AUTHENTICATION_NOTIFICATION];
  
  
  [self enableLocalHeartbeat];
  return YES;
}


/**
 Notification receiver for successful local connection
 */
- (void)localConnection {
  // Check current connection state
  [self checkConnectionState];
}

/**
 Notification receiver for failed local connection
 */
- (void)noLocalConnection {
  // Check current connection state
  [self checkConnectionState];
}

/**
 Notification receiver for failed local authentication
 */
- (void)notAuthenticated {
  /***************************************************
   We are not authenticated so we start the authentication process
   *****************************************************/
  
  // Move to main screen (as you can't control lights when not connected)
  [self.navigationController popToRootViewControllerAnimated:YES];
  
  // Dismiss modal views when connection is lost
  if (self.navigationController.presentedViewController) {
    [self.navigationController dismissViewControllerAnimated:YES completion:NULL];
  }
  
  // Remove no connection alert
  if (self.noConnectionAlert != nil) {
    [self.noConnectionAlert dismissWithClickedButtonIndex:[self.noConnectionAlert cancelButtonIndex] animated:YES];
    self.noConnectionAlert = nil;
  }
  
  /***************************************************
   doAuthentication will start the push linking
   *****************************************************/
  
  // Start local authenticion process
  [self performSelector:@selector(doAuthentication) withObject:nil afterDelay:0.5];
}


/**
 Checks if we are currently connected to the bridge locally and if not, it will show an error when the error is not already shown.
 */
- (void)checkConnectionState {
  if (!self.phHueSDK.localConnected) {
    // Dismiss modal views when connection is lost
    
    if (self.navigationController.presentedViewController) {
      [self.navigationController dismissViewControllerAnimated:YES completion:NULL];
    }
    
    // No connection at all, show connection popup
    
    if (self.noConnectionAlert == nil) {
      [self.navigationController popToRootViewControllerAnimated:YES];
      
      // Showing popup, so remove this view
      [self removeLoadingView];
      [self showNoConnectionDialog];
    }
    
  }
  else {
    // One of the connections is made, remove popups and loading views
    
    if (self.noConnectionAlert != nil) {
      [self.noConnectionAlert dismissWithClickedButtonIndex:[self.noConnectionAlert cancelButtonIndex] animated:YES];
      self.noConnectionAlert = nil;
    }
    [self removeLoadingView];
    
  }
}

/**
 Shows the first no connection alert with more connection options
 */
- (void)showNoConnectionDialog {
  
  self.noConnectionAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No connection", @"No connection alert title")
                                                      message:NSLocalizedString(@"Connection to bridge is lost", @"No Connection alert message")
                                                     delegate:self
                                            cancelButtonTitle:nil
                                            otherButtonTitles:NSLocalizedString(@"Reconnect", @"No connection alert reconnect button"), NSLocalizedString(@"Find new bridge", @"No connection find new bridge button"),NSLocalizedString(@"Cancel", @"No connection cancel button"), nil];
  self.noConnectionAlert.tag = 1;
  [self.noConnectionAlert show];
  
}

#pragma mark - Heartbeat control

/**
 Starts the local heartbeat with a 10 second interval
 */
- (void)enableLocalHeartbeat {
  /***************************************************
   The heartbeat processing collects data from the bridge
   so now try to see if we have a bridge already connected
   *****************************************************/
  
  PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
  if (cache != nil && cache.bridgeConfiguration != nil && cache.bridgeConfiguration.ipaddress != nil) {
    //
    [self showLoadingViewWithText:NSLocalizedString(@"Connecting...", @"Connecting text")];
    
    // Enable heartbeat with interval of 10 seconds
    [self.phHueSDK enableLocalConnection];
  } else {
    // Automaticly start searching for bridges
    [self searchForBridgeLocal];
  }
}

/**
 Stops the local heartbeat
 */
- (void)disableLocalHeartbeat {
  [self.phHueSDK disableLocalConnection];
}

#pragma mark - Bridge searching and selection

/**
 Search for bridges using UPnP and portal discovery, shows results to user or gives error when none found.
 */
- (void)searchForBridgeLocal {
  // Stop heartbeats
  [self disableLocalHeartbeat];
  
  // Show search screen
  [self showLoadingViewWithText:NSLocalizedString(@"Searching...", @"Searching for bridges text")];
  /***************************************************
   A bridge search is started using UPnP to find local bridges
   *****************************************************/
  
  // Start search
  self.bridgeSearch = [[PHBridgeSearching alloc] initWithUpnpSearch:YES andPortalSearch:YES andIpAdressSearch:YES];
  [self.bridgeSearch startSearchWithCompletionHandler:^(NSDictionary *bridgesFound) {
    // Done with search, remove loading view
    [self removeLoadingView];
    
    /***************************************************
     The search is complete, check whether we found a bridge
     *****************************************************/
    
    // Check for results
    if (bridgesFound.count > 0) {
      
      // Results were found, show options to user (from a user point of view, you should select automatically when there is only one bridge found)
      self.bridgeSelectionViewController = [[PHBridgeSelectionViewController alloc] initWithNibName:@"PHBridgeSelectionViewController" bundle:[NSBundle mainBundle] bridges:bridgesFound delegate:self];
      
      /***************************************************
       Use the list of bridges, present them to the user, so one can be selected.
       *****************************************************/
      
      UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self.bridgeSelectionViewController];
      navController.modalPresentationStyle = UIModalPresentationFormSheet;
      [self.navigationController presentViewController:navController animated:YES completion:nil];
    }
    else {
      /***************************************************
       No bridge was found was found. Tell the user and offer to retry..
       *****************************************************/
      
      // No bridges were found, show this to the user
      
      self.noBridgeFoundAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No bridges", @"No bridge found alert title")
                                                           message:NSLocalizedString(@"Could not find bridge", @"No bridge found alert message")
                                                          delegate:self
                                                 cancelButtonTitle:nil
                                                 otherButtonTitles:NSLocalizedString(@"Retry", @"No bridge found alert retry button"),NSLocalizedString(@"Cancel", @"No bridge found alert cancel button"), nil];
      self.noBridgeFoundAlert.tag = 1;
      [self.noBridgeFoundAlert show];
    }
  }];
}


#pragma mark - Loading view

/**
 Shows an overlay over the whole screen with a black box with spinner and loading text in the middle
 @param text The text to display under the spinner
 */
- (void)showLoadingViewWithText:(NSString *)text {
  // First remove
  [self removeLoadingView];
  
  // Then add new
  self.loadingView = [[PHLoadingViewController alloc] initWithNibName:@"PHLoadingViewController" bundle:[NSBundle mainBundle]];
  self.loadingView.view.frame = self.navigationController.view.bounds;
  [self.navigationController.view addSubview:self.loadingView.view];
  self.loadingView.loadingLabel.text = text;
}

/**
 Removes the full screen loading overlay.
 */
- (void)removeLoadingView {
  if (self.loadingView != nil) {
    [self.loadingView.view removeFromSuperview];
    self.loadingView = nil;
  }
}

@end
