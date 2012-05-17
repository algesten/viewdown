//
//  Document.h
//  ViewDown
//
//  Created by martin on 05/02/2012.
//  Copyright (c) 2012 Objekt & Funktion AB. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface Document : NSDocument <NSWindowDelegate>
{
    @private

    NSUserDefaults *userDefaults;
    
    BOOL started;
    NSURL *urlToStartWith;
    BOOL didFirstMain;
    
    NSFileManager* fm;
    NSMutableArray* pathsToWatch;
    NSNumber* lastEventId;
    FSEventStreamRef stream;
    
    NSString *monitored;
    NSDate *lastModified;
    
    NSDate *lastBuilt;
    
    NSString* tmpFile;
    
    NSString* markdownPath;
    
    NSData *head;
    NSData *tail;
    
    NSPoint savedScrollPosition;
    BOOL scrollToLast;

}

@property (strong) IBOutlet WebView *web;

// called by FSEvent callback
-(void)scanDir:(NSString*)path lastEventId:(uint64_t)eventId;

//////////////////  Delegate methods for WebView
-(NSUInteger)webView:(WebView *)webView dragDestinationActionMaskForDraggingInfo:(id<NSDraggingInfo>)draggingInfo;

-(void)webView:(WebView *)webView willPerformDragDestinationAction:(WebDragDestinationAction)action forDraggingInfo:(id <NSDraggingInfo>)draggingInfo;

-(void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame;
/////////////////////////////////////////////////

@end
