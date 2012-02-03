//
//  MainView.m
//  ViewDown
//
//  Created by martin on 03/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MainView.h"

@implementation MainView

@synthesize appDelegate;

-(id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {

        [self registerForDraggedTypes:[NSArray arrayWithObject:NSURLPboardType]];
        
    }
    return self;
}

-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    if ( [[pboard types] containsObject:NSURLPboardType] ) {
        
        NSURL *fileURL = [NSURL URLFromPasteboard:pboard];

        [appDelegate setCurrent:fileURL];
        
    }
    
    return NO;
}

@end
