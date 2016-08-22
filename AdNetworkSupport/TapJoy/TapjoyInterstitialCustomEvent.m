
#import "TapjoyInterstitialCustomEvent.h"
#import <Tapjoy/TJPlacement.h>
#import <Tapjoy/Tapjoy.h>
#import "MPLogging.h"
#import "MoPub.h"

@interface TapjoyInterstitialCustomEvent () <TJPlacementDelegate>
@property (nonatomic, strong) TJPlacement *placement;
@property (nonatomic, assign) BOOL isAutoConnect;
@property (nonatomic, strong) NSString *placementName;
@end


@implementation TapjoyInterstitialCustomEvent

- (void)setupListeners{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(tjcConnectSuccess:)
                                                 name:TJC_CONNECT_SUCCESS
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(tjcConnectFail:)
                                                 name:TJC_CONNECT_FAILED
                                               object:nil];
}

- (void)initializeWithCustomNetworkInfo:(NSDictionary *)info {
    // Grab sdkKey and connect flags defined in MoPub dashboard
    NSString *sdkKey = info[@"sdkKey"];
    BOOL enableDebug = info[@"debugEnabled"];
    
    _isAutoConnect = NO;
    
    if (sdkKey) {
        MPLogInfo(@"Connecting to Tapjoy via MoPub dashboard settings");
        NSMutableDictionary *connectOptions = [[NSMutableDictionary alloc] init];
        [connectOptions setObject:@(enableDebug) forKey:TJC_OPTION_ENABLE_LOGGING];
        [self setupListeners];
        
        [Tapjoy connect:sdkKey
                options:connectOptions];
        
        _isAutoConnect = YES;
        
    } else {
        MPLogInfo(@"Tapjoy interstitial is initialized with empty 'sdkKey'. You must call Tapjoy connect before requesting content.");
        [self.delegate interstitialCustomEvent:self didFailToLoadAdWithError:nil];
    }
}

- (void)requestInterstitialWithCustomEventInfo:(NSDictionary *)info
{
    // Grab placement name defined in MoPub dashboard as custom event data
    _placementName = info[@"name"];
    
    if (![Tapjoy isConnected]) {
        if (_isAutoConnect) {
            //Adapter is making connect call on behalf of publisher, wait for success before requesting content
            return;
        } else {
            [self initializeWithCustomNetworkInfo:info];
        }
    } else {
        //Tapjoy has successfully connected
        MPLogInfo(@"Requesting Tapjoy interstitial");
        [self requestPlacementContent];
    }
}
- (void)requestPlacementContent {
    if(_placementName) {
        _placement = [TJPlacement placementWithName:_placementName mediationAgent:@"mopub" mediationId:nil delegate:self];
        _placement.adapterVersion = @"4.1.0";
        
        [_placement requestContent];
    }
    else {
        MPLogInfo(@"Invalid Tapjoy placement name specified");
        [self.delegate interstitialCustomEvent:self didFailToLoadAdWithError:nil];
    }
}

- (void)showInterstitialFromRootViewController:(UIViewController *)rootViewController
{
    MPLogInfo(@"Tapjoy interstitial will be shown");
    [_placement showContentWithViewController:nil];
}

- (void)dealloc
{
    _placement.delegate = nil;
}

#pragma mark - TJPlacementtDelegate

- (void)requestDidSucceed:(TJPlacement *)placement {
    if (placement.isContentAvailable) {
        MPLogInfo(@"Tapjoy interstitial request successful");
        [self.delegate interstitialCustomEvent:self didLoadAd:nil];
    }
    else {
        MPLogInfo(@"No Tapjoy interstitials available");
        [self.delegate interstitialCustomEvent:self didFailToLoadAdWithError:nil];
    }
}

- (void)requestDidFail:(TJPlacement *)placement error:(NSError *)error {
    MPLogInfo(@"Tapjoy interstitial request failed");
    [self.delegate interstitialCustomEvent:self didFailToLoadAdWithError:error];
}

- (void)contentDidAppear:(TJPlacement *)placement {
    MPLogInfo(@"Tapjoy interstitial did appear");
    [self.delegate interstitialCustomEventWillAppear:self];
    [self.delegate interstitialCustomEventDidAppear:self];
}

- (void)contentDidDisappear:(TJPlacement *)placement {
    MPLogInfo(@"Tapjoy interstitial did disappear");
    [self.delegate interstitialCustomEventWillDisappear:self];
    [self.delegate interstitialCustomEventDidDisappear:self];
}

-(void)tjcConnectSuccess:(NSNotification*)notifyObj
{
    MPLogInfo(@"Tapjoy connect Succeeded");
    _isAutoConnect = NO;
    [self requestPlacementContent];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TJC_CONNECT_SUCCESS object:nil];
}

- (void)tjcConnectFail:(NSNotification*)notifyObj
{
    MPLogInfo(@"Tapjoy connect Failed");
    _isAutoConnect = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TJC_CONNECT_FAILED object:nil];
}

@end
