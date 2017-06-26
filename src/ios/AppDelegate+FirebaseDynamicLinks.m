#import "AppDelegate+FirebaseDynamicLinks.h"
#import "FirebaseDynamicLinks.h"
#import <objc/runtime.h>

@import Firebase;
@import GoogleSignIn;

@implementation AppDelegate (FirebasePlugin)

+ (void)load {
    method_exchangeImplementations(
        class_getInstanceMethod(self, @selector(application:openURL:options:)),
        class_getInstanceMethod(self, @selector(identity_application:openURL:options:))
    );

    method_exchangeImplementations(
        class_getInstanceMethod(self, @selector(application:openURL:sourceApplication:annotation:)),
        class_getInstanceMethod(self, @selector(identity_application:openURL:sourceApplication:annotation:))
    );

    method_exchangeImplementations(
        class_getInstanceMethod(self, @selector(application:continueUserActivity:restorationHandler:)),
        class_getInstanceMethod(self, @selector(identity_application:continueUserActivity:restorationHandler:))
    );
}

// [START openurl]
- (BOOL)identity_application:(nonnull UIApplication *)application
                     openURL:(nonnull NSURL *)url
                     options:(nonnull NSDictionary<NSString *, id> *)options {
    FirebaseDynamicLinks* dl = [self.viewController getCommandInstance:@"FirebaseDynamicLinks"];
    NSString* sourceApplication = options[UIApplicationOpenURLOptionsSourceApplicationKey];
    id annotation = options[UIApplicationOpenURLOptionsAnnotationKey];

    if ([dl isSigningIn]) {
        dl.isSigningIn = NO;

        return [[GIDSignIn sharedInstance] handleURL:url
                                   sourceApplication:sourceApplication
                                          annotation:annotation];
    } else {
        return [self identity_application:application
                                  openURL:url
                        sourceApplication:sourceApplication
                               annotation:annotation];
    }
}

- (BOOL)identity_application:(UIApplication *)application
                     openURL:(NSURL *)url
           sourceApplication:(NSString *)sourceApplication
                  annotation:(id)annotation {
    FirebaseDynamicLinks* dl = [self.viewController getCommandInstance:@"FirebaseDynamicLinks"];
    // Handle App Invite requests
    FIRReceivedInvite *invite =
        [FIRInvites handleURL:url sourceApplication:sourceApplication annotation:annotation];
    if (invite) {
        NSString *matchType = (invite.matchType == FIRReceivedInviteMatchTypeWeak) ? @"Weak" : @"Strong";
        [dl sendDynamicLinkData:@{
            @"deepLink": invite.deepLink,
            @"invitationId": invite.inviteId,
            @"matchType": matchType
        }];

        return YES;
    }

    FIRDynamicLink* dynamicLink =
        [[FIRDynamicLinks dynamicLinks] dynamicLinkFromCustomSchemeURL:url];
    if (dynamicLink) {
        NSString* matchType = (dynamicLink.matchConfidence == FIRDynamicLinkMatchConfidenceWeak) ? @"Weak" : @"Strong";
        [dl sendDynamicLinkData:@{
            @"deepLink": dynamicLink.url.absoluteString,
            @"matchType": matchType
        }];

        return YES;
    }

    if ([dl isSigningIn]) {
        dl.isSigningIn = NO;

        return [[GIDSignIn sharedInstance] handleURL:url
                                   sourceApplication:sourceApplication
                                          annotation:annotation];
    } else {
        return [self identity_application:application
                                  openURL:url
                        sourceApplication:sourceApplication
                               annotation:annotation];
    }
}
// [END openurl]

// [START continueuseractivity]
- (BOOL)identity_application:(UIApplication *)application
        continueUserActivity:(NSUserActivity *)userActivity
          restorationHandler:(void (^)(NSArray *))restorationHandler {
    FirebaseDynamicLinks* dl = [self.viewController getCommandInstance:@"FirebaseDynamicLinks"];

    BOOL handled = [[FIRDynamicLinks dynamicLinks]
        handleUniversalLink:userActivity.webpageURL
        completion:^(FIRDynamicLink * _Nullable dynamicLink, NSError * _Nullable error) {
            if (dynamicLink) {
                NSString *matchType = (dynamicLink.matchConfidence == FIRDynamicLinkMatchConfidenceWeak) ? @"Weak" : @"Strong";

                [dl sendDynamicLinkData:@{
                    @"deepLink": dynamicLink.url.absoluteString,
                    @"matchType": matchType
                }];
            }
        }];

    if (handled) {
        return YES;
    } else {
        return [self identity_application:application
                     continueUserActivity:userActivity
                       restorationHandler:restorationHandler];
    }
}
// [END continueuseractivity]

@end
