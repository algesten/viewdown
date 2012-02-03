//
//  AppDelegate.h
//  ViewDown
//
//  Created by martin on 02/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSView *view;
@property (strong) IBOutlet WebView *web;

-(void)setCurrent:(NSURL*)url;

-(void)openDocument:(id)sender;

@end
