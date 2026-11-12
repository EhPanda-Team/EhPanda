// The test network guard, linked into every package test target by `Package.swift`.
//
// A test process must never reach the network. A request no test stubbed used to go to the live site from the
// FeatureTests processes: request types default to the shared session, and a reducer effect a test starts without
// awaiting it, or a coordinator a test builds on the shared session, sends a real request (18-UAT, gap of test 10).
// This guard fails such a request at once, offline, the way a device without a connection would, so the code under
// test takes its ordinary failure path and the run never depends on the site or the network.
//
// It is installed when the test bundle loads, before any test runs, so no test, suite order or parallel worker can get
// ahead of it: it is registered for the shared session, and every session configuration built from `.default` or
// `.ephemeral` starts with it, as the download client, the image cache and the analytics SDK build theirs. A test
// that stubs a session still gets its stub: a protocol registered later, or put in the configuration's
// `protocolClasses` ahead of the guard or instead of the list, is asked first. Loopback hosts stay reachable.
//
// Written in Objective-C for `+load`: a Swift test target has no hook that runs before its first test.

#import "TestNetworkGuard.h"
#import <objc/runtime.h>

NSString *const EhPandaTestNetworkGuardKey = @"EhPandaTestNetworkGuard";

@interface EhPandaTestNetworkGuardProtocol : NSURLProtocol
@end

/// Makes the session configuration factory `selector` return configurations whose protocol list starts with the guard.
static void EhPandaGuardConfigurationFactory(SEL selector) {
    Class metaclass = object_getClass([NSURLSessionConfiguration class]);
    Method method = class_getClassMethod([NSURLSessionConfiguration class], selector);
    if (metaclass == Nil || method == NULL) {
        return;
    }
    typedef NSURLSessionConfiguration *(*Factory)(id, SEL);
    Factory original = (Factory)method_getImplementation(method);
    IMP guarded = imp_implementationWithBlock(^NSURLSessionConfiguration *(id receiver) {
        NSURLSessionConfiguration *configuration = original(receiver, selector);
        NSArray<Class> *classes = configuration.protocolClasses ?: @[];
        if (![classes containsObject:[EhPandaTestNetworkGuardProtocol class]]) {
            configuration.protocolClasses = [@[[EhPandaTestNetworkGuardProtocol class]]
                arrayByAddingObjectsFromArray:classes];
        }
        return configuration;
    });
    method_setImplementation(method, guarded);
}

@implementation EhPandaTestNetworkGuardProtocol

+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [NSURLProtocol registerClass:self];
        EhPandaGuardConfigurationFactory(@selector(defaultSessionConfiguration));
        EhPandaGuardConfigurationFactory(@selector(ephemeralSessionConfiguration));
    });
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString *scheme = request.URL.scheme.lowercaseString;
    if (scheme == nil || ![@[@"http", @"https", @"ws", @"wss"] containsObject:scheme]) {
        return NO;
    }
    NSString *host = request.URL.host.lowercaseString;
    return host == nil || ![@[@"localhost", @"127.0.0.1", @"::1"] containsObject:host];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSURL *url = self.request.URL;
    NSString *description = [NSString stringWithFormat:
        @"The test network guard failed an unstubbed request to %@: a test process stays offline.",
        url.absoluteString ?: @"(no URL)"];
    NSLog(@"%@", description);
    NSMutableDictionary<NSErrorUserInfoKey, id> *userInfo = [@{
        NSLocalizedDescriptionKey: description,
        EhPandaTestNetworkGuardKey: @YES
    } mutableCopy];
    if (url != nil) {
        userInfo[NSURLErrorFailingURLErrorKey] = url;
        userInfo[NSURLErrorFailingURLStringErrorKey] = url.absoluteString;
    }
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:userInfo];
    [self.client URLProtocol:self didFailWithError:error];
}

- (void)stopLoading {
}

@end
