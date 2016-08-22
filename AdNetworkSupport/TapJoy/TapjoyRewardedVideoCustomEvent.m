
#import "TapjoyRewardedVideoCustomEvent.h"
#import <Tapjoy/Tapjoy.h>
#import <Tapjoy/TJPlacement.h>
#import "MPRewardedVideoError.h"
#import "MPLogging.h"
#import "MPRewardedVideoReward.h"
#import "TapjoyGlobalMediationSettings.h"
#import "MoPub.h"

@interface TapjoyRewardedVideoCustomEvent () <TJPlacementDelegate, TJCVideoAdDelegate>
@property (nonatomic, strong) TJPlacement *placement;
@property (nonatomic, assign) BOOL isAutoConnect;
@property (nonatomic, strong) NSString *placementName;
@end

@implementation TapjoyRewardedVideoCustomEvent

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
    //Instantiate Mediation Settings
    TapjoyGlobalMediationSettings *medSettings = [[MoPub sharedInstance] globalMediationSettingsForClass:[TapjoyGlobalMediationSettings class]];
    
    
    // Grab sdkKey and connect flags defined in MoPub dashboard
    NSString *sdkKey = info[@"sdkKey"];
    BOOL enableDebug = info[@"debugEnabled"];
    
    
    _isAutoConnect = NO;
    
    if (medSettings.sdkKey) {
        MPLogInfo(@"Connecting to Tapjoy via MoPub mediation settings");
        [self setupListeners];
        [Tapjoy connect:medSettings.sdkKey
                options:medSettings.connectFlags];
        
        _isAutoConnect = YES;
        
    } else if (sdkKey) {
        MPLogInfo(@"Connecting to Tapjoy via MoPub dashboard settings");
        NSMutableDictionary *connectOptions = [[NSMutableDictionary alloc] init];
        [connectOptions setObject:@(enableDebug) forKey:TJC_OPTION_ENABLE_LOGGING];
        [self setupListeners];
        
        [Tapjoy connect:sdkKey
                options:connectOptions];
        
        _isAutoConnect = YES;
        
    } else {
        MPLogInfo(@"Tapjoy rewarded video is initialized with empty 'sdkKey'. You must call Tapjoy connect before requesting content.");
        [self.delegate rewardedVideoDidFailToLoadAdForCustomEvent:self error:nil];
    }
}

- (void)requestRewardedVideoWithCustomEventInfo:(NSDictionary *)info
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
        MPLogInfo(@"Requesting Tapjoy rewarded video");
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
        NSError *error = [NSError errorWithDomain:MoPubRewardedVideoAdsSDKDomain code:MPRewardedVideoAdErrorInvalidCustomEvent userInfo:nil];
        [self.delegate rewardedVideoDidFailToLoadAdForCustomEvent:self error:error];
    }
}
- (void)presentRewardedVideoFromViewController:(UIViewController *)viewController
{
    if ([self hasAdAvailable]) {
        MPLogInfo(@"Tapjoy rewarded video will be shown");
        [_placement showContentWithViewController:nil];
    }
    else {
        MPLogInfo(@"Failed to show Tapjoy rewarded video");
        NSError *error = [NSError errorWithDomain:MoPubRewardedVideoAdsSDKDomain code:MPRewardedVideoAdErrorNoAdsAvailable userInfo:nil];
        [self.delegate rewardedVideoDidFailToPlayForCustomEvent:self error:error];
    }
    
}

- (BOOL)hasAdAvailable
{
    return _placement.isContentAvailable;
}

- (void)handleCustomEventInvalidated
{
    _placement.delegate = nil;
}

- (void)handleAdPlayedForCustomEventNetwork
{
    // If we no longer have an ad available, report back up to the application that this ad expired.
    // We receive this message only when this ad has reported an ad has loaded and another ad unit
    // has played a video for the same ad network.
    if (![self hasAdAvailable]) {
        [self.delegate rewardedVideoDidExpireForCustomEvent:self];
    }
}

- (void)dealloc
{
    _placement.delegate = nil;
}

#pragma mark - TJPlacementDelegate methods
- (void)requestDidSucceed:(TJPlacement *)placement {
    if (!placement.isContentAvailable) {
        MPLogInfo(@"No Tapjoy rewarded videos available");
        NSError *error = [NSError errorWithDomain:MoPubRewardedVideoAdsSDKDomain code:MPRewardedVideoAdErrorNoAdsAvailable userInfo:nil];
        [self.delegate rewardedVideoDidFailToLoadAdForCustomEvent:self error:error];
    }
}

- (void)contentIsReady:(TJPlacement *)placement {
    MPLogInfo(@"Tapjoy rewarded video content is ready");
    [self.delegate rewardedVideoDidLoadAdForCustomEvent:self];
}
- (void)requestDidFail:(TJPlacement *)placement error:(NSError *)error {
    MPLogInfo(@"Tapjoy rewarded video request failed");
    [self.delegate rewardedVideoDidFailToLoadAdForCustomEvent:self error:error];
}

- (void)contentDidAppear:(TJPlacement *)placement {
    MPLogInfo(@"Tapjoy rewarded video content did appear");
    [Tapjoy setVideoAdDelegate:self];
    [self.delegate rewardedVideoWillAppearForCustomEvent:self];
    [self.delegate rewardedVideoDidAppearForCustomEvent:self];
}

- (void)contentDidDisappear:(TJPlacement *)placement {
    MPLogInfo(@"Tapjoy rewarded video content did disappear");
    [Tapjoy setVideoAdDelegate:nil];
    [self.delegate rewardedVideoWillDisappearForCustomEvent:self];
    [self.delegate rewardedVideoDidDisappearForCustomEvent:self];
}

#pragma mark Tapjoy Video

- (void)videoAdCompleted {
    MPLogInfo(@"Tapjoy rewarded video completed");
    [self.delegate rewardedVideoShouldRewardUserForCustomEvent:self reward:[[MPRewardedVideoReward alloc] initWithCurrencyAmount:@(kMPRewardedVideoRewardCurrencyAmountUnspecified)]];
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
