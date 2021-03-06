//
//  SPUInstallerProtocol.h
//  Sparkle
//
//  Created by Mayur Pawashe on 3/12/16.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SPUInstallerProtocol <NSObject>

// Any installation work can be done prior to user application being terminated and relaunched
// No UI should occur during this stage (i.e, do not show package installer apps, etc..)
// Should be able to be called from non-main thread
- (BOOL)performInitialInstallation:(NSError **)error;

// Any installation work after the user application has has been terminated. This is where the final installation work can be done.
// After this stage is done, the user application may be relaunched.
// Should be able to be called from non-main thread
- (BOOL)performFinalInstallation:(NSError **)error;

// Indicates whether or not this installer can install the update silently in the background, without hindering the user
// If this returns NO, then the installation can fail if the user did not directly request for the install to occur.
// Should be thread safe
- (BOOL)canInstallSilently;

// Cleans up work done from the initial or final installation (depending on how far installation gets)
// Should be able to be called from non-main thread
- (void)cleanup;

// The destination and installation path of the bundle being updated
- (NSString *)installationPath;

@end

NS_ASSUME_NONNULL_END
