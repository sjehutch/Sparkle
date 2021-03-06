//
//  SPUCoreBasedUpdateDriver.h
//  Sparkle
//
//  Created by Mayur Pawashe on 3/18/16.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPUStatusCompletionResults.h"
#import "SPUUpdateDriver.h"

NS_ASSUME_NONNULL_BEGIN

@class SUHost, SUAppcastItem;
@protocol SPUUpdaterDelegate;

@protocol SPUCoreBasedUpdateDriverDelegate <NSObject>

- (void)basicDriverDidFindUpdateWithAppcastItem:(SUAppcastItem *)updateItem;

- (void)installerDidFinishPreparationAndWillInstallImmediately:(BOOL)willInstallImmediately silently:(BOOL)willInstallSilently;

- (void)coreDriverIsRequestingAbortUpdateWithError:(nullable NSError *)error;

- (void)basicDriverIsRequestingAbortUpdateWithError:(nullable NSError *)error;

@optional

- (void)basicDriverDidFinishLoadingAppcast;

- (void)downloadDriverWillBeginDownload;

- (void)downloadDriverDidReceiveExpectedContentLength:(NSUInteger)expectedContentLength;

- (void)downloadDriverDidReceiveDataOfLength:(NSUInteger)length;

- (void)coreDriverDidStartExtractingUpdate;

- (void)installerDidStartInstalling;

- (void)installerDidExtractUpdateWithProgress:(double)progress;

- (void)installerIsSendingAppTerminationSignal;

- (void)installerDidFinishInstallationWithAcknowledgement:(void(^)(void))acknowledgement;

@end

@interface SPUCoreBasedUpdateDriver : NSObject

- (instancetype)initWithHost:(SUHost *)host applicationBundle:(NSBundle *)applicationBundle sparkleBundle:(NSBundle *)sparkleBundle updater:(id)updater updaterDelegate:(nullable id <SPUUpdaterDelegate>)updaterDelegate delegate:(id<SPUCoreBasedUpdateDriverDelegate>)delegate;

- (void)prepareCheckForUpdatesWithCompletion:(SPUUpdateDriverCompletion)completionBlock;

- (void)preflightForUpdatePermissionPreventingInstallerInteraction:(BOOL)preventsInstallerInteraction reply:(void (^)(NSError * _Nullable))reply;

- (void)checkForUpdatesAtAppcastURL:(NSURL *)appcastURL withUserAgent:(NSString *)userAgent httpHeaders:(NSDictionary * _Nullable)httpHeaders includesSkippedUpdates:(BOOL)includesSkippedUpdates requiresSilentInstall:(BOOL)silentInstall;

- (void)resumeInstallingUpdateWithCompletion:(SPUUpdateDriverCompletion)completionBlock;

- (void)resumeDownloadedUpdate:(SPUDownloadedUpdate *)downloadedUpdate completion:(SPUUpdateDriverCompletion)completionBlock;

- (void)downloadUpdateFromAppcastItem:(SUAppcastItem *)updateItem;

- (void)extractDownloadedUpdate;

- (void)clearDownloadedUpdate;

- (void)finishInstallationWithResponse:(SPUInstallUpdateStatus)installUpdateStatus displayingUserInterface:(BOOL)displayingUserInterface;

- (void)abortUpdateAndShowNextUpdateImmediately:(BOOL)shouldShowUpdateImmediately error:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END
