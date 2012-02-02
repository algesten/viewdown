//
//  AppDelegate.m
//  ViewDown
//
//  Created by martin on 02/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize window = _window, view, web;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
    NSString *url = @"http://www.google.com/";
    
    [web.mainFrame loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
    
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
{

    NSSize adjusted;
    adjusted.height = frameSize.height - 22;
    adjusted.width = frameSize.width;
    
    [view setFrameSize:adjusted];
    [web setFrameSize:adjusted];
    
    return frameSize;
}

@end
