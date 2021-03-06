//
//  SUCommandLineUserDriver.m
//  Sparkle
//
//  Created by Mayur Pawashe on 4/10/16.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

#import "SPUCommandLineUserDriver.h"
#import <AppKit/AppKit.h>
#import <SparkleCore/SparkleCore.h>
#import "SPUUserDriverCoreComponent.h"

#define SCHEDULED_UPDATE_TIMER_THRESHOLD 2.0 // seconds

@interface SPUCommandLineUserDriver ()

@property (nonatomic, nullable, readonly) SPUUpdatePermissionResponse *updatePermissionResponse;
@property (nonatomic, readonly) BOOL deferInstallation;
@property (nonatomic, readonly) BOOL verbose;
@property (nonatomic, readonly) SPUUserDriverCoreComponent *coreComponent;
@property (nonatomic) NSUInteger bytesDownloaded;
@property (nonatomic) NSUInteger bytesToDownload;

@end

@implementation SPUCommandLineUserDriver

@synthesize updatePermissionResponse = _updatePermissionResponse;
@synthesize deferInstallation = _deferInstallation;
@synthesize verbose = _verbose;
@synthesize coreComponent = _coreComponent;
@synthesize bytesDownloaded = _bytesDownloaded;
@synthesize bytesToDownload = _bytesToDownload;

- (instancetype)initWithUpdatePermissionResponse:(nullable SPUUpdatePermissionResponse *)updatePermissionResponse deferInstallation:(BOOL)deferInstallation verbose:(BOOL)verbose
{
    self = [super init];
    if (self != nil) {
        _updatePermissionResponse = updatePermissionResponse;
        _deferInstallation = deferInstallation;
        _verbose = verbose;
        _coreComponent = [[SPUUserDriverCoreComponent alloc] init];
    }
    return self;
}

- (void)showCanCheckForUpdates:(BOOL)canCheckForUpdates
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.coreComponent showCanCheckForUpdates:canCheckForUpdates];
    });
}

- (void)showUpdatePermissionRequest:(SPUUpdatePermissionRequest *)__unused request reply:(void (^)(SPUUpdatePermissionResponse *))reply
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.updatePermissionResponse == nil) {
            // We don't want to make this decision on behalf of the user.
            fprintf(stderr, "Error: Asked to grant update permission. Exiting.\n");
            exit(EXIT_FAILURE);
        } else {
            if (self.verbose) {
                fprintf(stderr, "Granting permission for automatic update checks with sending system profile %s...\n", self.updatePermissionResponse.sendSystemProfile ? "enabled" : "disabled");
            }
            reply(self.updatePermissionResponse);
        }
    });
}

- (void)showUserInitiatedUpdateCheckWithCompletion:(void (^)(SPUUserInitiatedCheckStatus))updateCheckStatusCompletion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.coreComponent registerUpdateCheckStatusHandler:updateCheckStatusCompletion];
        if (self.verbose) {
            fprintf(stderr, "Checking for Updates...\n");
        }
    });
}

- (void)dismissUserInitiatedUpdateCheck
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.coreComponent completeUpdateCheckStatus];
    });
}

- (void)displayReleaseNotes:(const char * _Nullable)releaseNotes
{
    if (releaseNotes != NULL) {
        fprintf(stderr, "Release notes:\n");
        fprintf(stderr, "%s\n", releaseNotes);
    }
}

- (void)displayHTMLReleaseNotes:(NSData *)releaseNotes
{
    // Note: this is the only API we rely on here that references AppKit
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithHTML:releaseNotes documentAttributes:nil];
    [self displayReleaseNotes:attributedString.string.UTF8String];
}

- (void)displayPlainTextReleaseNotes:(NSData *)releaseNotes encoding:(NSStringEncoding)encoding
{
    NSString *string = [[NSString alloc] initWithData:releaseNotes encoding:encoding];
    [self displayReleaseNotes:string.UTF8String];
}

- (void)showUpdateWithAppcastItem:(SUAppcastItem *)appcastItem updateAdjective:(NSString *)updateAdjective
{
    if (self.verbose) {
        fprintf(stderr, "Found %s update! (%s)\n", updateAdjective.UTF8String, appcastItem.displayVersionString.UTF8String);
        
        if (appcastItem.itemDescription != nil) {
            NSData *descriptionData = [appcastItem.itemDescription dataUsingEncoding:NSUTF8StringEncoding];
            if (descriptionData != nil) {
                [self displayHTMLReleaseNotes:descriptionData];
            }
        }
    }
}

- (void)showUpdateFoundWithAppcastItem:(SUAppcastItem *)appcastItem userInitiated:(BOOL)__unused userInitiated reply:(void (^)(SPUUpdateAlertChoice))reply
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showUpdateWithAppcastItem:appcastItem updateAdjective:@"new"];
        reply(SPUInstallUpdateChoice);
    });
}

- (void)showDownloadedUpdateFoundWithAppcastItem:(SUAppcastItem *)appcastItem userInitiated:(BOOL)__unused userInitiated reply:(void (^)(SPUUpdateAlertChoice))reply
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showUpdateWithAppcastItem:appcastItem updateAdjective:@"downloaded"];
        reply(SPUInstallUpdateChoice);
    });
}

- (void)showResumableUpdateFoundWithAppcastItem:(SUAppcastItem *)appcastItem userInitiated:(BOOL)__unused userInitiated reply:(void (^)(SPUInstallUpdateStatus))reply
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.coreComponent registerInstallUpdateHandler:reply];
        [self showUpdateWithAppcastItem:appcastItem updateAdjective:@"resumable"];
        
        if (self.deferInstallation) {
            if (self.verbose) {
                fprintf(stderr, "Deferring Installation.\n");
            }
            [self.coreComponent installUpdateWithChoice:SPUDismissUpdateInstallation];
        } else {
            [self.coreComponent installUpdateWithChoice:SPUInstallAndRelaunchUpdateNow];
        }
    });
}

- (void)showUpdateReleaseNotesWithDownloadData:(SPUDownloadData *)downloadData
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.verbose) {
            if (downloadData.MIMEType != nil && [downloadData.MIMEType isEqualToString:@"text/plain"]) {
                NSStringEncoding encoding;
                if (downloadData.textEncodingName == nil) {
                    encoding = NSUTF8StringEncoding;
                } else {
                    CFStringEncoding cfEncoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)downloadData.textEncodingName);
                    if (cfEncoding != kCFStringEncodingInvalidId) {
                        encoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
                    } else {
                        encoding = NSUTF8StringEncoding;
                    }
                }
                [self displayPlainTextReleaseNotes:downloadData.data encoding:encoding];
            } else {
                [self displayHTMLReleaseNotes:downloadData.data];
            }
        }
    });
}

- (void)showUpdateReleaseNotesFailedToDownloadWithError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.verbose) {
            fprintf(stderr, "Error: Unable to download release notes: %s\n", error.localizedDescription.UTF8String);
        }
    });
}

- (void)showUpdateNotFoundWithAcknowledgement:(void (^)(void))__unused acknowledgement
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.verbose) {
            fprintf(stderr, "No new update available!\n");
        }
        exit(EXIT_SUCCESS);
    });
}

- (void)showUpdaterError:(NSError *)error acknowledgement:(void (^)(void))__unused acknowledgement
{
    dispatch_async(dispatch_get_main_queue(), ^{
        fprintf(stderr, "Error: Update has failed: %s\n", error.localizedDescription.UTF8String);
        exit(EXIT_FAILURE);
    });
}

- (void)showDownloadInitiatedWithCompletion:(void (^)(SPUDownloadUpdateStatus))downloadUpdateStatusCompletion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.coreComponent registerDownloadStatusHandler:downloadUpdateStatusCompletion];
        
        if (self.verbose) {
            fprintf(stderr, "Downloading Update...\n");
        }
    });
}

- (void)showDownloadDidReceiveExpectedContentLength:(NSUInteger)expectedContentLength
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.verbose) {
            fprintf(stderr, "Downloading %lu bytes...\n", (unsigned long)expectedContentLength);
        }
        self.bytesDownloaded = 0;
        self.bytesToDownload = expectedContentLength;
    });
}

- (void)showDownloadDidReceiveDataOfLength:(NSUInteger)length
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.bytesDownloaded += length;
        if (self.bytesToDownload > 0 && self.verbose) {
            fprintf(stderr, "Downloaded %lu out of %lu bytes (%.0f%%)\n", (unsigned long)self.bytesDownloaded, (unsigned long)self.bytesToDownload, (self.bytesDownloaded * 100.0 / self.bytesToDownload));
        }
    });
}

- (void)showDownloadDidStartExtractingUpdate
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.coreComponent completeDownloadStatus];
        
        if (self.verbose) {
            fprintf(stderr, "Extracting update...\n");
        }
    });
}

- (void)showExtractionReceivedProgress:(double)progress
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.verbose) {
            fprintf(stderr, "Extracting Update (%.0f%%)\n", progress * 100);
        }
    });
}

- (void)showReadyToInstallAndRelaunch:(void (^)(SPUInstallUpdateStatus))installUpdateHandler
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.coreComponent registerInstallUpdateHandler:installUpdateHandler];
        
        if (self.deferInstallation) {
            if (self.verbose) {
                fprintf(stderr, "Deferring Installation.\n");
            }
            [self.coreComponent installUpdateWithChoice:SPUDismissUpdateInstallation];
        } else {
            [self.coreComponent installUpdateWithChoice:SPUInstallAndRelaunchUpdateNow];
        }
    });
}

- (void)showInstallingUpdate
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.verbose) {
            fprintf(stderr, "Installing Update...\n");
        }
    });
}

- (void)showUpdateInstallationDidFinishWithAcknowledgement:(void (^)(void))acknowledgement
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.coreComponent registerAcknowledgement:acknowledgement];
        
        if (self.verbose) {
           fprintf(stderr, "Installation Finished.\n");
        }
        
        [self.coreComponent acceptAcknowledgement];
    });
}

- (void)dismissUpdateInstallation
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.verbose) {
            fprintf(stderr, "Exiting.\n");
        }
        exit(EXIT_SUCCESS);
    });
}

- (void)showSendingTerminationSignal
{
    // We are already showing that the update is installing, so there is no need to do anything here
}

@end
