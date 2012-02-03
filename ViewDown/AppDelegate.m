//
//  AppDelegate.m
//  ViewDown
//
//  Created by martin on 02/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "MainView.h"

@implementation AppDelegate

@synthesize window = _window, view, web;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
    ((MainView*)view).appDelegate = self;
    
    WebPreferences *prefs = [[WebPreferences alloc] init];

    prefs.defaultTextEncodingName = @"utf-8";
    
    web.preferences = prefs;
    
}

-(void)setCurrent:(NSURL *)url
{

    [web.mainFrame loadRequest:[NSURLRequest requestWithURL:url]];
    
}

-(void)openDocument:(id)sender
{
    
    NSArray *types = [NSArray arrayWithObject:@"md"];
    
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.allowedFileTypes = types;

    if ([openPanel runModal] == NSOKButton)
    {
        NSURL *url = openPanel.URL;
        
        [self setCurrent:url];
        
    }
    
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
