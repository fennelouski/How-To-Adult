//
//  AppDelegate.h
//  How To Adult
//
//  Created by Nathan Fennel on 2/23/17.
//  Copyright © 2017 Nathan Fennel. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

