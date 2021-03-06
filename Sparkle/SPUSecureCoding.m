//
//  SPUSecureCoding.m
//  Sparkle
//
//  Created by Mayur Pawashe on 3/24/16.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

#import "SPUSecureCoding.h"
#import "SULog.h"

#ifdef _APPKITDEFINES_H
#error This is a "core" class and should NOT import AppKit
#endif

static NSString *SURootObjectArchiveKey = @"SURootObjectArchive";

NSData * _Nullable SPUArchiveRootObjectSecurely(id<NSSecureCoding> rootObject)
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *keyedArchiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    keyedArchiver.requiresSecureCoding = YES;
    
    @try {
        [keyedArchiver encodeObject:rootObject forKey:SURootObjectArchiveKey];
        [keyedArchiver finishEncoding];
        return [data copy];
    } @catch (NSException *exception) {
        SULog(@"Exception while securely archiving object: %@", exception);
        [keyedArchiver finishEncoding];
        return nil;
    }
}

id<NSSecureCoding> _Nullable SPUUnarchiveRootObjectSecurely(NSData *data, Class klass)
{
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    unarchiver.requiresSecureCoding = YES;
    
    @try {
        id<NSSecureCoding> rootObject = [unarchiver decodeObjectOfClass:klass forKey:SURootObjectArchiveKey];
        [unarchiver finishDecoding];
        return rootObject;
    } @catch (NSException *exception) {
        SULog(@"Exception while securely unarchiving object: %@", exception);
        [unarchiver finishDecoding];
        return nil;
    }
}
