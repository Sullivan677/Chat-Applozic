//
//  ALRegisterUserClientService.m
//  ChatApp
//
//  Created by devashish on 18/09/2015.
//  Copyright (c) 2015 AppLogic. All rights reserved.
//

#import "ALRegisterUserClientService.h"
#import "ALRequestHandler.h"
#import "ALResponseHandler.h"
#import "ALUtilityClass.h"
#import "ALRegistrationResponse.h"
#import "ALUserDefaultsHandler.h"
#import "ALMessageDBService.h"
#import "ALApplozicSettings.h"
#import "ALMQTTConversationService.h"
#import "ALMessageService.h"
#import "ALConstant.h"
#import "ALUserService.h"
#import "ALContactDBService.h"
#import "ALInternalSettings.h"
#import "ALAuthService.h"

@implementation ALRegisterUserClientService

-(void) initWithCompletion:(ALUser *)user
            withCompletion:(void(^)(ALRegistrationResponse * response, NSError *error)) completion {

    if ([ALUserDefaultsHandler isLoggedIn]) {
        ALSLog(ALLoggerSeverityInfo, @"User is already login to applozic with userId %@",ALUserDefaultsHandler.getUserId);
        ALRegistrationResponse *registrationResponse = [self getLoginRegistrationResponse];
        completion(registrationResponse,nil);
        return;
    }

    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/register/client",KBASE_URL];
    
    [ALUserDefaultsHandler setUserId:user.userId];
    [ALUserDefaultsHandler setPassword:user.password];
    [ALUserDefaultsHandler setDisplayName:user.displayName];
    [ALUserDefaultsHandler setEmailId:user.email];

    NSString *applicationId = [ALUserDefaultsHandler getApplicationKey];
    if (applicationId) {
        [user setApplicationId: applicationId];
    } else { // For backward compatibility
        [ALUserDefaultsHandler setApplicationKey: user.applicationId];
    }
    [user setPrefContactAPI:2];
    [user setEmailVerified:true];
    [user setDeviceType:4];
    [user setAppVersionCode:AL_VERSION_CODE];
    [user setRegistrationId: [ALUserDefaultsHandler getApnDeviceToken]];
    [user setNotificationMode:[ALUserDefaultsHandler getNotificationMode]];
    [user setAuthenticationTypeId:[ALUserDefaultsHandler getUserAuthenticationTypeId]];
    [user setPassword:[ALUserDefaultsHandler getPassword]];
    [user setUnreadCountType:[ALUserDefaultsHandler getUnreadCountType]];
    [user setDeviceApnsType:!isDevelopmentBuild()];
    [user setEnableEncryption:[ALUserDefaultsHandler getEnableEncryption]];
    [user setRoleName:[ALApplozicSettings getUserRoleName]];
    if ([ALUserDefaultsHandler getAppModuleName] != NULL) {
        [user setAppModuleName:[ALUserDefaultsHandler getAppModuleName]];
    }
    if ([ALApplozicSettings isAudioVideoEnabled]) {
        [user setFeatures:[NSMutableArray arrayWithArray:[NSArray arrayWithObjects: @"101",@"102",nil]]];
    }
    [user setUserTypeId:[ALUserDefaultsHandler getUserTypeId]];
    
    //NSString * theParamString = [ALUtilityClass generateJsonStringFromDictionary:userInfo];
    NSError * error;
    NSData * postdata = [NSJSONSerialization dataWithJSONObject:user.dictionary options:0 error:&error];
    NSString *theParamString = [[NSString alloc] initWithData:postdata encoding:NSUTF8StringEncoding];

    NSString *logParamText = [self getUserParamTextForLogging:user];
    ALSLog(ALLoggerSeverityInfo, @"PARAM_STRING USER_REGISTRATION :: %@",logParamText);

    NSMutableURLRequest * theRequest = [ALRequestHandler createPOSTRequestWithUrlString:theUrlString paramString:theParamString];

    [ALResponseHandler processRequest:theRequest andTag:@"CREATE ACCOUNT" WithCompletionHandler:^(id theJson, NSError *theError) {
        
        NSString *statusStr = (NSString *)theJson;
        ALSLog(ALLoggerSeverityInfo, @"RESPONSE_USER_REGISTRATION :: %@", statusStr);
        
        if (theError) {
            completion(nil, theError);
            return;
        }
        
        ALRegistrationResponse *response = [[ALRegistrationResponse alloc] initWithJSONString:statusStr];

        // Only save the UserDefaults for successful register.
        if([response isRegisteredSuccessfully]) {

            @try
            {
                [ALUserDefaultsHandler setUserId:user.userId];
                [ALUserDefaultsHandler setEmailVerified: user.emailVerified];
                [ALUserDefaultsHandler setDisplayName: user.displayName];
                [ALUserDefaultsHandler setEmailId:user.email];
                [ALUserDefaultsHandler setDeviceKeyString:response.deviceKey];
                [ALUserDefaultsHandler setUserKeyString:response.userKey];
                [ALUserDefaultsHandler setUserPricingPackage:response.pricingPackage];
                [ALUserDefaultsHandler setLastSyncTimeForMetaData:[NSNumber numberWithDouble:[response.currentTimeStamp doubleValue]]];
                [ALUserDefaultsHandler setLastSyncTime:[NSNumber numberWithDouble:[response.currentTimeStamp doubleValue]]];
                [ALUserDefaultsHandler setLastSyncChannelTime:(NSNumber *)response.currentTimeStamp];


                if (user.pushNotificationFormat) {
                    [ALUserDefaultsHandler setPushNotificationFormat:user.pushNotificationFormat];
                }

                if (response.roleType) {
                    [ALUserDefaultsHandler setUserRoleType:response.roleType];
                }

                if (response.notificationSoundFileName ) {
                    [ALUserDefaultsHandler setNotificationSoundFileName:response.notificationSoundFileName];
                }
                if (response.imageLink) {
                    [ALUserDefaultsHandler setProfileImageLinkFromServer:response.imageLink];
                }
                if (response.userEncryptionKey) {
                    [ALUserDefaultsHandler setUserEncryption:response.userEncryptionKey];
                }

                if (response.statusMessage) {
                    [ALUserDefaultsHandler setLoggedInUserStatus:response.statusMessage];
                }
                if (response.brokerURL && ![response.brokerURL isEqualToString:@""]) {
                    NSArray * mqttURL = [response.brokerURL componentsSeparatedByString:@":"];
                    NSString * MQTTURL = [mqttURL[1] substringFromIndex:2];
                    ALSLog(ALLoggerSeverityInfo, @"MQTT_URL :: %@",MQTTURL);
                    [ALUserDefaultsHandler setMQTTURL:MQTTURL];
                }
                if (response.encryptionKey) {
                    [ALUserDefaultsHandler setEncryptionKey:response.encryptionKey];
                }

                if (response.message) {
                    [ALInternalSettings setRegistrationStatusMessage:response.message];
                }

                ALAuthService * authService = [[ALAuthService alloc] init];
                [authService decodeAndSaveToken:response.authToken];

                ALContactDBService  * alContactDBService = [[ALContactDBService alloc] init];
                ALContact *contact = [[ALContact alloc] init];
                contact.userId = user.userId;
                contact.displayName = response.displayName;
                contact.contactImageUrl = response.imageLink;
                contact.contactNumber  = response.contactNumber;
                contact.roleType  =  [NSNumber numberWithShort:response.roleType];
                contact.metadata  =  response.metadata;
                [alContactDBService addContact:contact];

            }

            @catch (NSException *exception)
            {
                ALSLog(ALLoggerSeverityError, @"EXCEPTION :: %@", exception.description);
            }

            @finally
            {
                ALSLog(ALLoggerSeverityInfo, @"..");
            }

            [self connect];

            completion(response,nil);

            ALUserService * alUserService = [ALUserService new];
            [alUserService getMutedUserListWithDelegate:nil withCompletion:^(NSMutableArray *userDetailArray, NSError *error) {

            }];
        } else {
            completion(response, nil);
        }
    }];

}

-(void) updateApnDeviceTokenWithCompletion:(NSString *)apnDeviceToken withCompletion:(void(^)(ALRegistrationResponse * response, NSError *error)) completion
{
    ALSLog(ALLoggerSeverityInfo, @"ApnDeviceToken ## %@", apnDeviceToken);

    if (apnDeviceToken.length == 0) {
        NSError *error = [NSError errorWithDomain:@"Applozic"
                                             code:1
                                         userInfo:@{NSLocalizedDescriptionKey : @"ApnDeviceToken can not be empty or nil"}];

        completion(nil, error);
        return;
    }

    [ALUserDefaultsHandler setApnDeviceToken:apnDeviceToken];
    if ([ALUserDefaultsHandler isLoggedIn]) {

        [self updateDeviceToken:apnDeviceToken withCompletion:^(ALRegistrationResponse *response, NSError *error) {
            completion(response,error);
        }];
    }
}


-(void) updateDeviceToken:(NSString *)apnDeviceToken withCompletion:(void(^)(ALRegistrationResponse * response, NSError *error)) completion
{
    ALUser *user = [[ALUser alloc] init];
    [user setNotificationMode:ALUserDefaultsHandler.getNotificationMode];
    [user setRegistrationId:apnDeviceToken];

    [self updateUser:user withCompletion:^(ALRegistrationResponse *response, NSError *error) {
        completion(response, error);
    }];
}

+(void) updateNotificationMode:(short)notificationMode withCompletion:(void(^)(ALRegistrationResponse * response, NSError *error)) completion
{

    ALUser *user = [[ALUser alloc] init];
    [user setNotificationMode:notificationMode];
    [user setRegistrationId:ALUserDefaultsHandler.getApnDeviceToken];

    ALRegisterUserClientService * alRegisterUserClientService = [[ALRegisterUserClientService alloc] init];
    [alRegisterUserClientService updateUser:user withCompletion:^(ALRegistrationResponse *response, NSError *error) {
        completion(response, error);
    }];
}

-(void)updateUser:(ALUser *)alUser
   withCompletion:(void(^)(ALRegistrationResponse * response, NSError *error)) completion {

    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/register/update",KBASE_URL];

    ALUser * user = [ALUser new];

    [user setUserId:[ALUserDefaultsHandler getUserId]];
    [user setApplicationId:[ALUserDefaultsHandler getApplicationKey]];
    [user setNotificationMode:alUser.notificationMode];
    [user setPassword:[ALUserDefaultsHandler getPassword]];

    if (alUser.registrationId) {
        [user setRegistrationId:alUser.registrationId];
    } else if ([ALUserDefaultsHandler getApnDeviceToken]) {
        [user setRegistrationId:[ALUserDefaultsHandler getApnDeviceToken]];
    }
    [user setEnableEncryption:[ALUserDefaultsHandler getEnableEncryption]];
    [user setPrefContactAPI:2];
    [user setEmailVerified:true];
    [user setDeviceType:4];
    [user setDeviceApnsType:!isDevelopmentBuild()];
    [user setAppVersionCode: AL_VERSION_CODE];
    [user setAuthenticationTypeId:[ALUserDefaultsHandler getUserAuthenticationTypeId]];
    [user setRoleName:[ALApplozicSettings getUserRoleName]];

    if (alUser.displayName) {
        user.displayName = alUser.displayName;
    }

    if (alUser.contactNumber) {
        user.contactNumber = alUser.contactNumber;
    }

    if (alUser.email) {
        user.email = alUser.email;
    }

    if ([ALUserDefaultsHandler getAppModuleName] != NULL) {
        [user setAppModuleName:[ALUserDefaultsHandler getAppModuleName]];
    }
    [user setPushNotificationFormat:[ALUserDefaultsHandler getPushNotificationFormat]];

    if (alUser.notificationSoundFileName) {
        [user setNotificationSoundFileName:alUser.notificationSoundFileName];
    } else if ([ALUserDefaultsHandler getNotificationSoundFileName] != nil) {
        [user setNotificationSoundFileName:[ALUserDefaultsHandler getNotificationSoundFileName]];
    }

    if([ALApplozicSettings isAudioVideoEnabled]) {
        [user setFeatures:[NSMutableArray arrayWithArray:[NSArray arrayWithObjects: @"101",@"102",nil]]];
    }

    [user setUserTypeId:[ALUserDefaultsHandler getUserTypeId]];

    [user setUnreadCountType:[ALUserDefaultsHandler getUnreadCountType]];

    NSError * error;
    NSData * postdata = [NSJSONSerialization dataWithJSONObject:user.dictionary options:0 error:&error];
    NSString *theParamString = [[NSString alloc] initWithData:postdata encoding:NSUTF8StringEncoding];

    NSMutableURLRequest *theRequest = [ALRequestHandler createPOSTRequestWithUrlString:theUrlString paramString:theParamString];

    [ALResponseHandler authenticateAndProcessRequest:theRequest andTag:@"UPDATE USER DETAILS" WithCompletionHandler:^(id theJson, NSError *theError) {
        ALSLog(ALLoggerSeverityInfo, @"Update login user details %@", theJson);

        NSString *statusStr = (NSString *)theJson;
        if (theError) {
            completion(nil,theError);
            return ;
        }
        ALRegistrationResponse *response = [[ALRegistrationResponse alloc] initWithJSONString:statusStr];

        if (response && response.isRegisteredSuccessfully) {

            if (response.displayName) {
                [ALUserDefaultsHandler setDisplayName: response.displayName];
            }

            [ALUserDefaultsHandler setUserPricingPackage:response.pricingPackage];

            if (response.message) {
                [ALInternalSettings setRegistrationStatusMessage:response.message];
            }

            if (response.notificationSoundFileName) {
                [ALUserDefaultsHandler setNotificationSoundFileName:response.notificationSoundFileName];
            }

            if(response.imageLink) {
                [ALUserDefaultsHandler setProfileImageLinkFromServer:response.imageLink];
            }

            if (response.authToken) {
                [ALUserDefaultsHandler setAuthToken:response.authToken];
            }

            [ALUserDefaultsHandler setUserRoleType:response.roleType];

        }
        completion(response, error);

    }];
}

-(void)syncAccountStatusWithCompletion:(void(^)(ALRegistrationResponse * response, NSError *error)) completion {
    ALUser *user = [[ALUser alloc] init];
    [user setNotificationMode:ALUserDefaultsHandler.getNotificationMode];
    [user setRegistrationId:ALUserDefaultsHandler.getApnDeviceToken];

    [self updateUser:user withCompletion:^(ALRegistrationResponse *response, NSError *error) {
        completion(response, error);
    }];
}


-(void) connect {
    
    //[[ALMQTTService sharedInstance] connectToApplozic];
}

-(void) disconnect {
    
    // ALMQTTConversationService *ob  = [[ALMQTTConversationService alloc] init];
    //[ob sendTypingStatus:[ALUserDefaultsHandler getApplicationKey] userID:[ALUserDefaultsHandler getUserId] typing:NO];
    
    //  [[ALMQTTConversationService sharedInstance] unsubscribeToConversation];
}

-(void)logoutWithCompletionHandler:(void(^)(ALAPIResponse *response, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@%@",KBASE_URL,AL_LOGOUT_URL];
    NSMutableURLRequest *theRequest = [ALRequestHandler createPOSTRequestWithUrlString:urlString paramString:nil];

    [ALResponseHandler authenticateAndProcessRequest:theRequest andTag:@"USER_LOGOUT" WithCompletionHandler:^(id theJson, NSError *error) {

        ALSLog(ALLoggerSeverityInfo, @"RESPONSE_USER_LOGOUT :: %@", (NSString *)theJson);
        ALAPIResponse *response = [[ALAPIResponse alloc] initWithJSONString:theJson];

        NSString *userKey = [ALUserDefaultsHandler getUserKeyString];
        BOOL completed = [[ALMQTTConversationService sharedInstance] unsubscribeToConversation: userKey];
        ALSLog(ALLoggerSeverityInfo, @"Unsubscribed to conversation after logout: %d", completed);

        [ALUserDefaultsHandler clearAll];
        [ALApplozicSettings clearAll];

        ALMessageDBService *messageDBService = [[ALMessageDBService alloc] init];
        [messageDBService deleteAllObjectsInCoreData];

        if(error) {
            ALSLog(ALLoggerSeverityError, @"Error in logout: %@", error.description);
            [[UIApplication sharedApplication] unregisterForRemoteNotifications];
        }

        completion(response,error);
    }];

}

+(BOOL)isAppUpdated{
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *currentAppVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *previousVersion = [defaults objectForKey:@"appVersion"];
    
    if (!previousVersion) {
        ALSLog(ALLoggerSeverityInfo, @"First start after installing the app");
        [defaults setObject:currentAppVersion forKey:@"appVersion"];
        [defaults synchronize];
        return NO;
    } else if ([previousVersion isEqualToString:currentAppVersion]) {
        return NO;
    } else {
        ALSLog(ALLoggerSeverityInfo, @"App was updated since last run");
        
        [ALRegisterUserClientService sendServerRequestForAppUpdate];
        [defaults setObject:currentAppVersion forKey:@"appVersion"];
        [defaults synchronize];
        return YES;
    }
    
}

+(void)sendServerRequestForAppUpdate {
    
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/register/version/update",KBASE_URL];
    NSString * paramString = [NSString stringWithFormat:@"appVersionCode=%i&deviceKey=%@", AL_VERSION_CODE , [ALUserDefaultsHandler getDeviceKeyString]];
    NSLog(@"sending data to server from sendServerRequestForAppUpdate ");

    NSMutableURLRequest *theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:paramString];
    [ALResponseHandler authenticateAndProcessRequest:theRequest andTag:@"APP_UPDATED" WithCompletionHandler:^(id theJson, NSError *theError) {
        if (theError) {
            ALSLog(ALLoggerSeverityError, @"error:%@",theError);
        }
        ALSLog(ALLoggerSeverityInfo, @"Response: APP UPDATED:%@",theJson);
    }];
}

-(void)syncAccountStatus {
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/application/pricing/package", KBASE_URL];
    NSString * paramString = [NSString stringWithFormat:@"applicationId=%@", [ALUserDefaultsHandler getApplicationKey]];

    NSMutableURLRequest *theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:paramString];

    [ALResponseHandler authenticateAndProcessRequest:theRequest andTag:@"SYNC_ACCOUNT_STATUS" WithCompletionHandler:^(id theJson, NSError *theError) {

        if (theError) {
            ALSLog(ALLoggerSeverityError, @"ERROR_SYNC_ACCOUNT_STATUS :: %@", theError.description);
        }
        ALSLog(ALLoggerSeverityInfo, @"RESPONSE_SYNC_ACCOUNT_STATUS :: %@",(NSString *)theJson);
    }];

}

-(ALRegistrationResponse *) getLoginRegistrationResponse {
    ALRegistrationResponse * registrationResponse = [[ALRegistrationResponse alloc]init];
    registrationResponse.deviceKey = [ALUserDefaultsHandler getDeviceKeyString];
    registrationResponse.userKey = [ALUserDefaultsHandler getUserKeyString];
    registrationResponse.message = [ALInternalSettings getRegistrationStatusMessage];
    ALContactDBService * contactDatabase = [[ALContactDBService alloc]init];
    ALContact *loginUserContact = [contactDatabase loadContactByKey:@"userId"value:[ALUserDefaultsHandler getUserId]];
    registrationResponse.contactNumber = loginUserContact.contactNumber;
    registrationResponse.lastSyncTime = [ALUserDefaultsHandler.getLastSyncTime stringValue];
    registrationResponse.imageLink = loginUserContact.contactImageUrl;
    registrationResponse.encryptionKey = ALUserDefaultsHandler.getEncryptionKey;
    registrationResponse.pricingPackage = ALUserDefaultsHandler.getUserPricingPackage;
    registrationResponse.brokerURL = [NSString stringWithFormat:@"tcp://%@:%@",[ALUserDefaultsHandler getMQTTURL],[ALUserDefaultsHandler getMQTTPort]];
    registrationResponse.displayName = loginUserContact.displayName;
    registrationResponse.notificationSoundFileName = ALUserDefaultsHandler.getNotificationSoundFileName;
    registrationResponse.statusMessage = [ALUserDefaultsHandler getLoggedInUserStatus];
    registrationResponse.metadata = loginUserContact.metadata;
    registrationResponse.roleType = ALUserDefaultsHandler.getUserRoleType;
    registrationResponse.userEncryptionKey  = ALUserDefaultsHandler.getUserEncryptionKey;

    return registrationResponse;
}

-(NSString *)getUserParamTextForLogging:(ALUser *)user {
    NSString *passwordText = user.password ? @"***":@"";
    [user setPassword: passwordText];
    NSError * error;
    NSData * userData = [NSJSONSerialization dataWithJSONObject:user.dictionary options:0 error:&error];
    NSString *logParamString = [[NSString alloc] initWithData:userData encoding:NSUTF8StringEncoding];
    return logParamString;
}

static BOOL isDevelopmentBuild(void) {
#if TARGET_IPHONE_SIMULATOR
    return YES;
#else
    static BOOL isDevelopment = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // There is no provisioning profile in AppStore Apps.
        NSData *data = [NSData dataWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"embedded" ofType:@"mobileprovision"]];
        if (data) {
            const char *bytes = [data bytes];
            NSMutableString *profile = [[NSMutableString alloc] initWithCapacity:data.length];
            for (NSUInteger i = 0; i < data.length; i++) {
                [profile appendFormat:@"%c", bytes[i]];
            }
            // Look for debug value, if detected we're a development build.
            NSString *cleared = [[profile componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] componentsJoinedByString:@""];
            isDevelopment = [cleared rangeOfString:@"<key>get-task-allow</key><true/>"].length > 0;
        }
    });
    return isDevelopment;
#endif
}

@end

