//
//  SPUUpdatePermissionRequest.m
//  Sparkle
//
//  Created by Mayur Pawashe on 8/14/16.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

#import "SPUUpdatePermissionRequest.h"

#ifdef _APPKITDEFINES_H
#error This is a "core" class and should NOT import AppKit
#endif

static NSString *SPUUpdatePermissionRequestSystemProfileKey = @"SPUUpdatePermissionRequestSystemProfile";

@implementation SPUUpdatePermissionRequest

@synthesize systemProfile = _systemProfile;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
    NSArray<NSDictionary<NSString *, NSString *> *> *systemProfile = [decoder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [NSDictionary class], [NSString class]]] forKey:SPUUpdatePermissionRequestSystemProfileKey];
    if (systemProfile == nil) {
        return nil;
    }
    
    return [self initWithSystemProfile:systemProfile];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.systemProfile forKey:SPUUpdatePermissionRequestSystemProfileKey];
}

- (instancetype)initWithSystemProfile:(NSArray<NSDictionary<NSString *, NSString *> *> *)systemProfile
{
    self = [super init];
    if (self != nil) {
        _systemProfile = systemProfile;
    }
    return self;
}

@end
