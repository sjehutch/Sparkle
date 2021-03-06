//
//  SUHost.m
//  Sparkle
//
//  Copyright 2008 Andy Matuschak. All rights reserved.
//

#import "SUHost.h"

// This is a "core" class and thus should NOT import Cocoa/AppKit

#import "SUConstants.h"
#include <sys/mount.h> // For statfs for isRunningOnReadOnlyVolume
#import "SULog.h"
#import "SUParameterAssert.h"

#ifdef _APPKITDEFINES_H
#error This is a "core" class and should NOT import AppKit
#endif

// This class should also be process independent
// For example, it should not have code that tests writabilty to somewhere on disk,
// as that may depend on the privileges of the process owner. Or code that depends on
// if the process is sandboxed or not; eg: finding user caches directory

@interface SUHost ()

@property (strong, readwrite) NSBundle *bundle;
@property (copy) NSString *defaultsDomain;
@property (assign) BOOL usesStandardUserDefaults;
@property (nonatomic) NSDictionary *infoDictionary;

@end

@implementation SUHost

@synthesize bundle;
@synthesize defaultsDomain;
@synthesize usesStandardUserDefaults;
@synthesize infoDictionary = _infoDictionary;

- (instancetype)initWithBundle:(NSBundle *)aBundle
{
	if ((self = [super init]))
	{
        SUParameterAssert(aBundle);
        self.bundle = aBundle;
        if (![self.bundle bundleIdentifier]) {
            SULog(@"Error: the bundle being updated at %@ has no %@! This will cause preference read/write to not work properly.", self.bundle, kCFBundleIdentifierKey);
        }
        
        _infoDictionary = aBundle.infoDictionary;

        self.defaultsDomain = [self objectForInfoDictionaryKey:SUDefaultsDomainKey];
        if (!self.defaultsDomain) {
            self.defaultsDomain = [self.bundle bundleIdentifier];
        }

        // If we're using the main bundle's defaults we'll use the standard user defaults mechanism, otherwise we have to get CF-y.
        NSString *mainBundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
        usesStandardUserDefaults = !self.defaultsDomain || [self.defaultsDomain isEqualToString:mainBundleIdentifier];
    }
    return self;
}

// NSBundles always cache the info dictionary, even if you create a new NSBundle instance, but we sometimes want to reload it
// in case the bundle changes or is updated
- (void)reloadInfoDictionary
{
    CFDictionaryRef infoDictionary = CFBundleCopyInfoDictionaryInDirectory((CFURLRef)self.bundle.bundleURL);
    self.infoDictionary = CFBridgingRelease(infoDictionary);
}

- (NSString *)description { return [NSString stringWithFormat:@"%@ <%@>", [self class], [self bundlePath]]; }

- (NSString *)bundlePath
{
    return [self.bundle bundlePath];
}

- (NSString * _Nonnull)name
{
    NSString *name;

    // Allow host bundle to provide a custom name
    name = [self objectForInfoDictionaryKey:@"SUBundleName"];
    if (name && name.length > 0) return name;

    name = [self objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	if (name && name.length > 0) return name;

    name = [self objectForInfoDictionaryKey:(__bridge NSString *)kCFBundleNameKey];
	if (name && name.length > 0) return name;

    return [[[NSFileManager defaultManager] displayNameAtPath:[self.bundle bundlePath]] stringByDeletingPathExtension];
}

- (BOOL)validVersion
{
    return [self isValidVersion:[self _version]];
}

- (BOOL)isValidVersion:(NSString *)version
{
    return (version != nil && version.length != 0);
}

- (NSString *)_version
{
    NSString *version = [self objectForInfoDictionaryKey:(__bridge NSString *)kCFBundleVersionKey];
    return ([self isValidVersion:version] ? version : nil);
}

- (NSString * _Nonnull)version
{
    NSString *version = [self _version];
    if (version == nil) {
        SULog(@"This host (%@) has no %@! This attribute is required.", [self bundlePath], (__bridge NSString *)kCFBundleVersionKey);
        abort();
    }
    return version;
}

- (NSString * _Nonnull)displayVersion
{
    NSString *shortVersionString = [self objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (shortVersionString)
        return shortVersionString;
    else
        return [self version]; // Fall back on the normal version string.
}

- (BOOL)isRunningOnReadOnlyVolume
{
    struct statfs statfs_info;
    statfs([[self.bundle bundlePath] fileSystemRepresentation], &statfs_info);
    return (statfs_info.f_flags & MNT_RDONLY) != 0;
}

- (NSString *_Nullable)publicDSAKey
{
    // Maybe the key is just a string in the Info.plist.
    NSString *key = [self objectForInfoDictionaryKey:SUPublicDSAKeyKey];
	if (key) {
        return key;
    }

    // More likely, we've got a reference to a Resources file by filename:
    NSString *keyFilename = [self publicDSAKeyFileKey];
	if (!keyFilename) {
        return nil;
    }

    NSString *keyPath = [self.bundle pathForResource:keyFilename ofType:nil];
    if (!keyPath) {
        return nil;
    }
    return [NSString stringWithContentsOfFile:keyPath encoding:NSASCIIStringEncoding error:nil];
}

- (NSString * _Nullable)publicDSAKeyFileKey
{
    return [self objectForInfoDictionaryKey:SUPublicDSAKeyFileKey];;
}

- (id)objectForInfoDictionaryKey:(NSString *)key
{
    return [self.infoDictionary objectForKey:key];
}

- (BOOL)boolForInfoDictionaryKey:(NSString *)key
{
    return [[self objectForInfoDictionaryKey:key] boolValue];
}

- (id)objectForUserDefaultsKey:(NSString *)defaultName
{
    if (!defaultName || !self.defaultsDomain) {
        return nil;
    }

    // Under Tiger, CFPreferencesCopyAppValue doesn't get values from NSRegistrationDomain, so anything
    // passed into -[NSUserDefaults registerDefaults:] is ignored.  The following line falls
    // back to using NSUserDefaults, but only if the host bundle is the main bundle.
    if (self.usesStandardUserDefaults) {
        return [[NSUserDefaults standardUserDefaults] objectForKey:defaultName];
    }

    CFPropertyListRef obj = CFPreferencesCopyAppValue((__bridge CFStringRef)defaultName, (__bridge CFStringRef)self.defaultsDomain);
    return CFBridgingRelease(obj);
}

- (void)setObject:(id)value forUserDefaultsKey:(NSString *)defaultName
{
	if (self.usesStandardUserDefaults)
	{
        [[NSUserDefaults standardUserDefaults] setObject:value forKey:defaultName];
	}
	else
	{
        CFPreferencesSetValue((__bridge CFStringRef)defaultName, (__bridge CFPropertyListRef)(value), (__bridge CFStringRef)self.defaultsDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        CFPreferencesSynchronize((__bridge CFStringRef)self.defaultsDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    }
}

- (BOOL)boolForUserDefaultsKey:(NSString *)defaultName
{
    if (self.usesStandardUserDefaults) {
        return [[NSUserDefaults standardUserDefaults] boolForKey:defaultName];
    }

    BOOL value;
    CFPropertyListRef plr = CFPreferencesCopyAppValue((__bridge CFStringRef)defaultName, (__bridge CFStringRef)self.defaultsDomain);
    if (plr == NULL) {
        value = NO;
	}
	else
	{
        value = (BOOL)CFBooleanGetValue((CFBooleanRef)plr);
        CFRelease(plr);
    }
    return value;
}

- (void)setBool:(BOOL)value forUserDefaultsKey:(NSString *)defaultName
{
	if (self.usesStandardUserDefaults)
	{
        [[NSUserDefaults standardUserDefaults] setBool:value forKey:defaultName];
	}
	else
	{
        CFPreferencesSetValue((__bridge CFStringRef)defaultName, (__bridge CFBooleanRef) @(value), (__bridge CFStringRef)self.defaultsDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        CFPreferencesSynchronize((__bridge CFStringRef)self.defaultsDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    }
}

- (id)objectForKey:(NSString *)key {
    return [self objectForUserDefaultsKey:key] ? [self objectForUserDefaultsKey:key] : [self objectForInfoDictionaryKey:key];
}

- (BOOL)boolForKey:(NSString *)key {
    return [self objectForUserDefaultsKey:key] ? [self boolForUserDefaultsKey:key] : [self boolForInfoDictionaryKey:key];
}

@end
