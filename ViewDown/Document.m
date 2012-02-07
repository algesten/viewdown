//
//  Document.m
//  ViewDown
//
//  Created by martin on 05/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "Document.h"

// callback for receiving file system events telling us
// when a directory has had some changes
void fsevents_callback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[])
{
    
    Document *doc = (__bridge Document *)userData;

    size_t i;
    for(i=0; i < numEvents; i++){
        
        [doc scanDir:[(__bridge NSArray *)eventPaths objectAtIndex:i] lastEventId:eventIds[i]];
        
    }
    
}

@interface Document()
-(void)setCurrent:(NSURL*)url;
-(void)initializeEventStream:(NSURL*)file;
-(void)buildMarkdown:(BOOL)savePosition;
-(void)reloadWebView;
-(void)updateWebSize:(NSSize)frameSize;
-(NSDate*)lastModifiedForMonitored;
-(NSString*)pathForTemporaryFile;
@end

NSString* const VDDefaultWidth = @"VDDefaultWidth";
NSString* const VDDefaultHeight = @"VDDefaultHeight";
NSString* const VDDefaultX = @"VDDefaultX";
NSString* const VDDefaultY = @"VDDefaultY";

@implementation Document

@synthesize web;

#pragma mark ----- Lifecycle -----

- (NSString *)windowNibName
{
    return @"Document";
}

-(void)windowControllerDidLoadNib:(NSWindowController *)windowController
{
    [super windowControllerDidLoadNib:windowController];
}

-(void)awakeFromNib
{
    
    // ensures we get no white top/bottom
    web.drawsBackground = NO;
    
    // our own preferences
    WebPreferences *prefs = [[WebPreferences alloc] init];
    
    prefs.defaultTextEncodingName = @"utf-8";
    
    // read user stylesheet
    NSBundle *bundle = [NSBundle mainBundle];    
    NSURL *userStyles = [bundle URLForResource:@"userstyles" withExtension:@"css"];
    
    // set user stylesheet and enable it
    prefs.userStyleSheetLocation = userStyles;
    prefs.userStyleSheetEnabled = YES;
    prefs.defaultFontSize = 16;
    prefs.defaultFixedFontSize = 16;
    prefs.minimumFontSize  = 16;
    prefs.minimumLogicalFontSize = 16;
    
    web.preferences = prefs;
    
    
    // html5 head/tail
    head = [@"<!DOCTYPE html><html><head></head><body><div id=\"wrapper\"><div id=\"content\">" 
            dataUsingEncoding:NSUTF8StringEncoding];
    tail = [@"</div></div></body></html>" dataUsingEncoding:NSUTF8StringEncoding];
    
    // get default file manager
    fm = [NSFileManager defaultManager];
    
    // attempts to find markdown (XXX more work here!)
    if ([fm fileExistsAtPath:@"/usr/local/bin/markdown"])
    {
        markdownPath = @"/usr/local/bin/markdown";
    }
    
    // show error dialog to warn if no markdown is found.
    if (!markdownPath) {
        CFUserNotificationDisplayAlert(0, kCFUserNotificationNoDefaultButtonFlag, NULL, NULL, NULL, CFSTR("Missing markdown"), CFSTR("The markdown script could not be found."), NULL, NULL, NULL, NULL);
    }

    // set up defaults
    userDefaults = [NSUserDefaults standardUserDefaults];
    
    // now we're running
    started = YES;
    
    if (urlToStartWith) {
        [self setCurrent:urlToStartWith];
    } else {
        [self setCurrent:NULL];
    }
    
}


-(void)windowDidBecomeMain:(NSNotification *)notification
{

    if (didFirstMain) {
        return;
    }
    
    NSInteger defaultWidth = [userDefaults integerForKey:VDDefaultWidth];
    NSInteger defaultHeight = [userDefaults integerForKey:VDDefaultHeight];
    NSInteger defaultX = [userDefaults integerForKey:VDDefaultX];
    NSInteger defaultY = [userDefaults integerForKey:VDDefaultY];
    
    if (!defaultWidth || !defaultHeight) {
        defaultWidth = 680;
        defaultHeight = 500;
        defaultX = 50;
        defaultY = 214;
        [userDefaults setInteger:defaultWidth forKey:VDDefaultWidth];
        [userDefaults setInteger:defaultHeight forKey:VDDefaultHeight];
        [userDefaults setInteger:defaultX forKey:VDDefaultX];
        [userDefaults setInteger:defaultY forKey:VDDefaultY];
        [userDefaults synchronize];
    }
    
    CGRect theSize = CGRectMake(defaultX, defaultY, defaultWidth, defaultHeight);

    [self.windowForSheet setFrame:theSize display:YES animate:YES];

    [self updateWebSize:theSize.size];
    
    didFirstMain = YES;
    
}


-(void)windowWillClose:(NSNotification *)notification
{
    if (fm && tmpFile) {
        [fm removeItemAtPath:tmpFile error:nil];
    }
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
{

    // change the nested web container
    [self updateWebSize:frameSize];
    
    return frameSize;
}

-(void)updateWebSize:(NSSize)frameSize
{
    NSSize adjusted;
    adjusted.height = frameSize.height - 22;
    adjusted.width = frameSize.width;
    
    [web setFrameSize:adjusted];
}

-(void)windowDidMove:(NSNotification *)notification
{
    CGRect rect = self.windowForSheet.frame;

    [userDefaults setInteger:rect.origin.x forKey:VDDefaultX];
    [userDefaults setInteger:rect.origin.y forKey:VDDefaultY];

    [userDefaults synchronize];

}

-(void)windowDidResize:(NSNotification *)notification
{

    CGRect rect = self.windowForSheet.frame;
    
    [userDefaults setInteger:rect.size.width forKey:VDDefaultWidth];
    [userDefaults setInteger:rect.size.height forKey:VDDefaultHeight];
    
    [userDefaults synchronize];
    
}

#pragma mark ----- Private methods -----

// sets the current url we are to work from.
-(void)setCurrent:(NSURL *)url
{
    
    // reset all
    monitored = nil;
    lastModified = nil;
    lastBuilt = nil;
    scrollToLast = NO;
    if (stream) {
        FSEventStreamStop(stream);
        FSEventStreamInvalidate(stream);
        FSEventStreamRelease(stream);
        stream = NULL;
    }
    
    if (url && !started) {
        urlToStartWith = url;
        return;
    }
    
    if (!url) 
    {
        // default to blank
        NSBundle *bundle = [NSBundle mainBundle];
        [web.mainFrame loadRequest:[NSURLRequest 
                                    requestWithURL:[bundle URLForResource:@"empty" withExtension:@"html"]]];
        
    }
    else
    {
        
        monitored = [url path];
        
        NSLog(@"%@", monitored);
        
        lastModified = [self lastModifiedForMonitored];
        
        if (!lastModified) {
            // file has disappeared
            CFUserNotificationDisplayAlert(0, kCFUserNotificationNoDefaultButtonFlag, NULL, NULL, NULL, CFSTR("File not found"), CFSTR("The file could not be opened."), NULL, NULL, NULL, NULL);
            [self close];
            return;
        }
        
        [self initializeEventStream:url];
        
        [self buildMarkdown:NO];
        
    }
    
}


- (void)initializeEventStream:(NSURL*)file
{
    
    if (!file.isFileURL) {
        abort();
    }
    
    // pick out directory where the file resides
    NSMutableArray *path = [NSMutableArray arrayWithArray:file.pathComponents];
    [path removeLastObject];
    
    if (!pathsToWatch) {
        pathsToWatch = [NSMutableArray array];
    }
    
    // restart from 0 to get all changes
    lastEventId = [NSNumber numberWithInt:0];
    
    [pathsToWatch removeAllObjects];
    [pathsToWatch addObject:[path componentsJoinedByString:@"/"]];
    
    void *appPointer = (__bridge void *)self;
    
    FSEventStreamContext context = {0, appPointer, NULL, NULL, NULL};
    NSTimeInterval latency = 0.1;
    
	stream = FSEventStreamCreate(NULL,
	                             &fsevents_callback,
	                             &context,
	                             (__bridge CFArrayRef) pathsToWatch,
	                             [lastEventId unsignedLongLongValue],
	                             (CFAbsoluteTime) latency,
	                             kFSEventStreamCreateFlagUseCFTypes 
                                 );
    
	FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	FSEventStreamStart(stream);
    
}

- (void)buildMarkdown:(BOOL)savePosition
{
    
    // no change, ignore
    if (lastBuilt && [lastBuilt laterDate:lastModified] == lastBuilt) {
        return;
    }
    
    lastBuilt = lastModified;
    
    if (!tmpFile) {
        tmpFile = [self pathForTemporaryFile];
    }
    
    if (![fm fileExistsAtPath:tmpFile]) {
        [fm createFileAtPath:tmpFile contents:nil attributes:nil];
    }
    
    // this task is used to execute the external markdown script
    NSTask *task = [[NSTask alloc] init];
    
    // the script
    [task setLaunchPath:markdownPath];
    
    // the argument
    [task setArguments:[NSArray arrayWithObject:monitored]];
    
    // pipe to capture output
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    // file handle to output
    NSFileHandle *markdownOut = pipe.fileHandleForReading;
    
    // launch and wait for it to finish
    [task launch];
    [task waitUntilExit];
    
    // read data from output
    NSData *data = [markdownOut readDataToEndOfFile];
    
    // create file handle for (already created) file
    NSFileHandle *tmpFileHandle = [NSFileHandle fileHandleForWritingAtPath:tmpFile];
    
    // empty file
    [tmpFileHandle truncateFileAtOffset:0];
    
    [tmpFileHandle writeData:head]; 
    [tmpFileHandle writeData:data];
    [tmpFileHandle writeData:tail]; 
    
    if (savePosition) {
        // save scroll position before reloading
        NSScrollView *scrollView = [[[[web mainFrame] frameView] documentView] enclosingScrollView];
        NSRect scrollViewBounds = [[scrollView contentView] bounds];
        savedScrollPosition = scrollViewBounds.origin;  
        scrollToLast = YES;
    } else {
        scrollToLast = NO;
    }
    
    [tmpFileHandle closeFile];
    
    [self performSelector:@selector(reloadWebView) withObject:nil afterDelay:0.1];
    
}


-(void)reloadWebView
{
    [web.mainFrame stopLoading];
    [web.mainFrame loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:tmpFile]]];
}

#pragma mark ----- Public methods -----

- (void)scanDir:(NSString*)path lastEventId:(uint64_t)eventId
{
    
    lastEventId = [NSNumber numberWithUnsignedLongLong:eventId];
    
    if ([monitored hasPrefix:path]) {
        
        NSDate *current = [self lastModifiedForMonitored];
        
        if (!current) {

            // file has disappeared stop monitoring
            [self setCurrent:NULL];

            // close window
            [self close];

            return;
        }
        
        if ([lastModified laterDate:current] == current) {
            
            lastModified = current;
            
            // file has been modified, reload it
            [self buildMarkdown:YES];
            
        }
        
    }
    
}

#pragma mark ----- Private utitilty methods -----

-(NSDate*)lastModifiedForMonitored
{
    
    // no file, then blank
    if (![fm fileExistsAtPath:monitored]) {
        return NULL;
    }
    
    NSDictionary *attr = [fm attributesOfItemAtPath:monitored error:nil];
    
    return [attr valueForKey:NSFileModificationDate];
    
}

- (NSString *)pathForTemporaryFile
{
    
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    assert(uuid != NULL);
    
    CFStringRef uuidStr = CFUUIDCreateString(NULL, uuid);
    assert(uuidStr != NULL);
    
    NSString *name = [NSString stringWithFormat:@"%@-viewdown.html",uuidStr];
    
    NSString *result = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    assert(result != nil);
    
    CFRelease(uuidStr);
    CFRelease(uuid);
    
    return result;
}

#pragma mark ----- WebView delegate -----

-(NSUInteger)webView:(WebView *)webView dragDestinationActionMaskForDraggingInfo:(id<NSDraggingInfo>)draggingInfo
{
    
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
    
    if ( [[pboard types] containsObject:NSURLPboardType] ) {
        
        NSURL *fileURL = [NSURL URLFromPasteboard:pboard];
        
        if ([[fileURL path] hasSuffix:@".md"]) {
            
            return WebDragDestinationActionLoad;
            
        }
        
    }
    
    return WebDragDestinationActionNone;
    
}

- (void)webView:(WebView *)webView willPerformDragDestinationAction:(WebDragDestinationAction)action forDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
    
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
    
    if ( [[pboard types] containsObject:NSURLPboardType] ) {
        
        NSURL *fileURL = [NSURL URLFromPasteboard:pboard];
        
        if ([[fileURL path] hasSuffix:@".md"]) {
            
            [self setCurrent:fileURL];
            
        }
        
    }
    
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    
    if (scrollToLast) {
		NSScrollView *scrollView = [[[[web mainFrame] frameView] documentView] enclosingScrollView];	
		[[scrollView documentView] scrollPoint:savedScrollPosition];
        scrollToLast = NO;
    }
    
}


#pragma mark ----- NSDocument reading/printing -----

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)type error:(NSError **)outError {
    
    [self setCurrent:url];
    
    return YES;
}

-(NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError *__autoreleasing *)outError
{
    
    NSView *view = [[[web mainFrame] frameView] documentView];
    
    NSPrintOperation *po = [NSPrintOperation printOperationWithView:view];
    
    return po;
    
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

@end
