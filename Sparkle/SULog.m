//
//  SULog.m
//  Sparkle
//
//  Created by Mayur Pawashe on 5/18/16.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

#include "SULog.h"
#include <asl.h>
#include "SUExport.h"

#ifdef _APPKITDEFINES_H
#error This is a "core" implementation and should NOT import AppKit
#endif

void _SULogDisableStandardErrorStream(void);
static BOOL gDisableStandardErrorStream;

// For converting constants to string literals using the preprocessor
#define STRINGIFY(x) #x
#define TO_STRING(x) STRINGIFY(x)

// Private API for disable logging to standard error stream
// We don't want to do this normally unless eg: releasing a command line utility,
// because it may be useful for error output to show up in an immediately visible terminal/panel
SU_EXPORT void _SULogDisableStandardErrorStream(void)
{
    gDisableStandardErrorStream = YES;
}

void SULog(NSString *format, ...)
{
    static aslclient client;
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath:mainBundle.bundlePath];
        
        uint32_t options = ASL_OPT_NO_DELAY;
        if (!gDisableStandardErrorStream) {
            options |= ASL_OPT_STDERR;
        }
        client = asl_open([displayName stringByAppendingString:@" [Sparkle]"].UTF8String, mainBundle.bundleIdentifier.UTF8String, options);
        queue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    });
    
    if (client == NULL) {
        return;
    }
    
    va_list ap;
    va_start(ap, format);
    NSString *logMessage = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    
    // Make sure we do not async, because if we async, the log may not be delivered deterministically
    dispatch_sync(queue, ^{
        aslmsg message = asl_new(ASL_TYPE_MSG);
        if (message == NULL) {
            return;
        }
        
        if (asl_set(message, ASL_KEY_MSG, logMessage.UTF8String) != 0) {
            return;
        }
        
        // In the future, we could possibly have different logging functions using different levels
        if (asl_set(message, ASL_KEY_LEVEL, TO_STRING(ASL_LEVEL_ERR)) != 0) {
            return;
        }
        
        asl_send(client, message);
    });
}
