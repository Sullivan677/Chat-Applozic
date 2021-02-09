import Applozic
import ApplozicSwift
import Foundation
import UIKit

var TYPE_CLIENT: Int16 = 0
var TYPE_APPLOZIC: Int16 = 1
var TYPE_FACEBOOK: Int16 = 2

var APNS_TYPE_DEVELOPMENT: Int16 = 0
var APNS_TYPE_DISTRIBUTION: Int16 = 1

class ALChatManager: NSObject {
    static let applicationId = "Paste_you_application_id_here"
    static let shared = ALChatManager(applicationKey: ALChatManager.applicationId as NSString)

    var pushNotificationTokenData: Data? {
        didSet {
            updateToken()
        }
    }

    init(applicationKey: NSString) {
        super.init()
        if applicationKey.length == 0 {
            fatalError("Please pass your applicationId in the ALChatManager file.")
        }
        ALUserDefaultsHandler.setApplicationKey(applicationKey as String)
        defaultChatViewSettings()
    }

    class func isNilOrEmpty(_ string: NSString?) -> Bool {
        switch string {
        case let .some(nonNilString):
            return nonNilString.length == 0
        default:
            return true
        }
    }

    func updateToken() {
        guard let deviceToken = pushNotificationTokenData else { return }
        print("DEVICE_TOKEN_DATA :: \(deviceToken.description)") // (SWIFT = 3) : TOKEN PARSING

        var deviceTokenString: String = ""
        for i in 0 ..< deviceToken.count {
            deviceTokenString += String(format: "%02.2hhx", deviceToken[i] as CVarArg)
        }
        print("DEVICE_TOKEN_STRING :: \(deviceTokenString)")

        if ALUserDefaultsHandler.getApnDeviceToken() != deviceTokenString {
            let alRegisterUserClientService = ALRegisterUserClientService()
            alRegisterUserClientService.updateApnDeviceToken(withCompletion: deviceTokenString, withCompletion: { response, _ in
                print("REGISTRATION_RESPONSE :: \(String(describing: response))")
            })
        }
    }

    func connectUser(_ alUser: ALUser, completion: @escaping (_ response: ALRegistrationResponse?, _ error: NSError?) -> Void) {
        _ = ALChatLauncher(applicationId: getApplicationKey() as String)
        let registerUserClientService = ALRegisterUserClientService()
        registerUserClientService.initWithCompletion(alUser, withCompletion: { response, error in
            guard error == nil else {
                completion(nil, error as NSError?)
                return
            }
            guard let response = response else {
                let apiError = NSError(domain: "Applozic", code: 0, userInfo: [NSLocalizedDescriptionKey: "Api error while registering to applozic"])
                completion(nil, apiError as NSError?)
                return
            }
            guard response.isRegisteredSuccessfully() else {
                let message = response.message ?? "Api error while registering to applozic"
                let errorResponse = NSError(domain: "Applozic", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
                completion(nil, errorResponse)
                return
            }
            print("Registration successfull")
            completion(response, nil)
        })
    }

    func getApplicationKey() -> NSString {
        let appKey = ALUserDefaultsHandler.getApplicationKey() as NSString?
        let applicationKey = (appKey != nil) ? appKey : ALChatManager.applicationId as NSString?
        return applicationKey!
    }

    func isUserPresent() -> Bool {
        guard let _ = ALUserDefaultsHandler.getApplicationKey() as String?,
            let _ = ALUserDefaultsHandler.getUserId() as String?
        else {
            return false
        }
        return true
    }

    func logoutUser(completion: @escaping (Bool) -> Void) {
        let registerUserClientService = ALRegisterUserClientService()
        if let _ = ALUserDefaultsHandler.getDeviceKeyString() {
            registerUserClientService.logout(completionHandler: {
                _, _ in
                NSLog("Applozic logout")
                let appSettingsUserDefaults = ALKAppSettingsUserDefaults()
                appSettingsUserDefaults.clear()
                completion(true)
            })
        }
    }

    func defaultChatViewSettings() {
        ALUserDefaultsHandler.setGoogleMapAPIKey("AIzaSyCOacEeJi-ZWLLrOtYyj3PKMTOFEG7HDlw") // REPLACE WITH YOUR GOOGLE MAPKEY
        ALApplozicSettings.setListOfViewControllers([ALKConversationListViewController.description(), ALKConversationViewController.description()])
        ALApplozicSettings.setFilterContactsStatus(false)
        ALUserDefaultsHandler.setDebugLogsRequire(true)
        ALApplozicSettings.setSwiftFramework(true)
    }

    func launchChatList(from viewController: UIViewController, with configuration: ALKConfiguration) {
        let conversationVC = ALKConversationListViewController(configuration: configuration)
        let navVC = ALKBaseNavigationViewController(rootViewController: conversationVC)
        navVC.modalPresentationStyle = .fullScreen
        viewController.present(navVC, animated: true, completion: nil)
    }

    func launch(viewController: UIViewController, from vc: UIViewController) {
        let navVC = ALKBaseNavigationViewController(rootViewController: viewController)
        guard vc.navigationController != nil else {
            vc.present(navVC, animated: true, completion: nil)
            return
        }
        vc.modalPresentationStyle = .fullScreen
        vc.navigationController?.pushViewController(viewController, animated: true)
    }

    func launchChatWith(contactId: String, from viewController: UIViewController, configuration: ALKConfiguration, prefilledMessage: String? = nil) {
        let alContactDbService = ALContactDBService()
        var title = ""
        if let alContact = alContactDbService.loadContact(byKey: "userId", value: contactId), let name = alContact.getDisplayName() {
            title = name
        }
        title = title.isEmpty ? "No name" : title
        let convViewModel = ALKConversationViewModel(contactId: contactId, channelKey: nil, localizedStringFileName: configuration.localizedStringFileName, prefilledMessage: prefilledMessage)
        let conversationViewController = ALKConversationViewController(configuration: configuration, individualLaunch: true)
        conversationViewController.viewModel = convViewModel
        launch(viewController: conversationViewController, from: viewController)
    }

    func launchGroupWith(clientGroupId: String, from viewController: UIViewController, configuration: ALKConfiguration, prefilledMessage: String? = nil) {
        let alChannelService = ALChannelService()
        alChannelService.getChannelInformation(nil, orClientChannelKey: clientGroupId) { channel in
            guard let channel = channel, let key = channel.key else { return }
            let convViewModel = ALKConversationViewModel(contactId: nil, channelKey: key, localizedStringFileName: configuration.localizedStringFileName, prefilledMessage: prefilledMessage)
            let conversationViewController = ALKConversationViewController(configuration: configuration, individualLaunch: true)
            conversationViewController.viewModel = convViewModel
            self.launch(viewController: conversationViewController, from: viewController)
        }
    }

    func launchChatWith(conversationProxy: ALConversationProxy, from viewController: UIViewController, configuration: ALKConfiguration) {
        let userId = conversationProxy.userId
        let groupId = conversationProxy.groupId
        let convViewModel = ALKConversationViewModel(contactId: userId, channelKey: groupId, conversationProxy: conversationProxy, localizedStringFileName: configuration.localizedStringFileName)
        let conversationViewController = ALKConversationViewController(configuration: configuration, individualLaunch: true)
        conversationViewController.viewModel = convViewModel
        launch(viewController: conversationViewController, from: viewController)
    }

    /// Use [launchGroupOfTwo](x-source-tag://GroupOfTwo) method instead.
    func createAndLaunchChatWith(conversationProxy: ALConversationProxy, from viewController: UIViewController, configuration: ALKConfiguration) {
        let conversationService = ALConversationService()
        conversationService.createConversation(conversationProxy) { error, response in
            guard let proxy = response, error == nil else {
                print("Error creating conversation :: \(String(describing: error))")
                return
            }
            let alConversationProxy = self.conversationProxyFrom(original: conversationProxy, generated: proxy)
            self.launchChatWith(conversationProxy: alConversationProxy, from: viewController, configuration: configuration)
        }
    }

    func launchGroupOfTwo(
        with userId: String,
        metadata: NSMutableDictionary,
        topic: String,
        from viewController: UIViewController,
        configuration: ALKConfiguration
    ) {
        let clientGroupId = String(format: "%@_%@_%@", topic, ALUserDefaultsHandler.getUserId(), userId)
        let channelService = ALChannelService()
        channelService.getChannelInformation(nil, orClientChannelKey: clientGroupId) {
            channel in
            guard let channel = channel else {
                channelService.createChannel(userId, orClientChannelKey: clientGroupId, andMembersList: [userId], andImageLink: nil, channelType: Int16(GROUP_OF_TWO.rawValue), andMetaData: metadata, withCompletion: { channel, error in
                    guard error == nil, let channel = channel else {
                        print("Error while creating channel : \(String(describing: error))")
                        return
                    }
                    ALChannelDBService().addMember(toChannel: userId, andChannelKey: channel.key)
                    self.launchGroupWith(clientGroupId: clientGroupId, from: viewController, configuration: configuration)
                })
                return
            }
            if channel.metadata == metadata {
                self.launchGroupWith(clientGroupId: clientGroupId, from: viewController, configuration: configuration)
            } else {
                channelService.updateChannelMetaData(channel.key, orClientChannelKey: nil, metadata: metadata, withCompletion: { error in
                    print("Failed to update channel metadata: \(String(describing: error))")
                    self.launchGroupWith(clientGroupId: clientGroupId, from: viewController, configuration: configuration)
                })
            }
        }
    }

    func launchContactList(from viewController: UIViewController, configuration: ALKConfiguration) {
        let newChatVC = ALKNewChatViewController(configuration: configuration, viewModel: ALKNewChatViewModel(localizedStringFileName: configuration.localizedStringFileName))
        let navVC = UINavigationController(rootViewController: newChatVC)
        viewController.present(navVC, animated: true, completion: nil)
    }

    func setApplicationBaseUrl() {
        guard let dict = Bundle.main.infoDictionary?["APPLOZIC_PRODUCTION"] as? [AnyHashable: Any] else {
            return
        }
        /// Change URLs if they are present in the info dictionary.
        if let baseUrl = dict["AL_KBASE_URL"] as? String {
            ALUserDefaultsHandler.setBASEURL(baseUrl)
        }

        if let mqttUrl = dict["AL_MQTT_URL"] as? String {
            ALUserDefaultsHandler.setMQTTURL(mqttUrl)
        }

        if let fileUrl = dict["AL_FILE_URL"] as? String {
            ALUserDefaultsHandler.setFILEURL(fileUrl)
        }

        if let mqttPort = dict["AL_MQTT_PORT"] as? String {
            ALUserDefaultsHandler.setMQTTPort(mqttPort)
        }
    }

    func getLoggedInUserInfo() -> ALUser {
        let user = ALUser()
        user.applicationId = getApplicationKey() as String
        user.appModuleName = ALUserDefaultsHandler.getAppModuleName()
        user.userId = ALUserDefaultsHandler.getUserId()
        user.email = ALUserDefaultsHandler.getEmailId()
        user.password = ALUserDefaultsHandler.getPassword()
        user.displayName = ALUserDefaultsHandler.getDisplayName()
        return user
    }

    private func conversationProxyFrom(original: ALConversationProxy, generated: ALConversationProxy) -> ALConversationProxy {
        let finalProxy = ALConversationProxy()
        finalProxy.userId = generated.userId
        finalProxy.topicDetailJson = generated.topicDetailJson
        finalProxy.id = original.id
        finalProxy.groupId = original.groupId
        return finalProxy
    }

    private func chatTitleUsing(userId: String?, groupId: NSNumber?) -> String {
        if let contactId = userId,
            let contact = ALContactDBService().loadContact(byKey: "userId", value: contactId),
            let name = contact.getDisplayName()
        {
            return name
        }
        if let channelKey = groupId,
            let channel = ALChannelService().getChannelByKey(channelKey)
        {
            return channel.name
        }
        return "No name"
    }
}
