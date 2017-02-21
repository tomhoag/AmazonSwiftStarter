//
//  AMZRemoteService.swift
//  AmazonSwiftStarter
//
//  Created by Peter Fennema on 16/02/16.
//  Copyright © 2016 Peter Fennema. All rights reserved.
//

import Foundation
import AWSCore
import AWSDynamoDB
import AWSS3
import LoginWithAmazon
import FacebookCore
import FacebookLogin

class AMZRemoteService {
    
    // MARK: - RemoteService Properties
    
    var hasCurrentUserIdentity: Bool {
        return persistentUserId != nil
    }

    var currentUser: UserData?
    
    // MARK: - Properties

    var persistentUserId: String? {
        set {
            UserDefaults.standard.setValue(newValue, forKey: "userId")
            UserDefaults.standard.synchronize()
        }
        get {
            return UserDefaults.standard.string(forKey: "userId")
        }
    }
    
    fileprivate (set) var identityProvider: AWSCognitoCredentialsProvider?
    
    fileprivate var deviceDirectoryForUploads: URL?
    
    fileprivate var deviceDirectoryForDownloads: URL?
    
    fileprivate static var sharedInstance: AMZRemoteService?
    
    
    // MARK: - Functions
    
    static func defaultService() -> RemoteService {
        if sharedInstance == nil {
            sharedInstance = AMZRemoteService()
            //sharedInstance!.configure() // defer until we know how to configure
            AWSLogger.default().logLevel = .warn

        }
        return sharedInstance!
    }
    
    

    fileprivate func createLocalTmpDirectory(_ directoryName: String) -> URL? {
        do {
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(directoryName)
            try
                FileManager.default.createDirectory(
                    at: url,
                    withIntermediateDirectories: true,
                    attributes: nil)
            return url
        } catch let error as NSError {
            print("Creating \(directoryName) directory failed. Error: \(error)")
            return nil
        }
    }
    
    // This is where the saving to S3 (image) and DynamoDB (data) is done.
    func saveAMZUser(_ user: AMZUser, completion: @escaping ErrorResultBlock) {
        precondition(user.userId != nil, "You should provide a user object with a userId when saving a user")
        
        let mapper = AWSDynamoDBObjectMapper.default()
        // We create a task that will save the user to DynamoDB
        // This works because AMZUser extends AWSDynamoDBObjectModel and conforms to AWSDynamoDBModeling
        let saveToDynamoDBTask: AWSTask = mapper.save(user)
        
        saveToDynamoDBTask.continueOnSuccessWith(block: { (awsTask) -> Any? in
            if user.imageData == nil {
                return nil
            } else {
                return self.createUploadImageTask(user)
            }
        }).continueWith(block: { (awsTask) -> Any? in
            completion(awsTask.error as NSError?)
            return nil
        })
    }
    
    fileprivate func createUploadImageTask(_ user: UserData) -> AWSTask<AWSS3TransferUtilityUploadTask> { //AWSTask<AnyObject> {
        guard let userId = user.userId else {
            preconditionFailure("You should provide a user object with a userId when uploading a user image")
        }
        guard let imageData = user.imageData else {
            preconditionFailure("You are trying to create an UploadImageTask, but the user has no imageData")
        }
        let fileName = "\(userId).jpg"
        
        let expression = AWSS3TransferUtilityUploadExpression()
        expression.progressBlock = {(task, progress) in DispatchQueue.main.async(execute: {
            // Do something e.g. Update a progress bar.
        })
        }
        let completionHandler: AWSS3TransferUtilityUploadCompletionHandlerBlock = { (task, error) -> Void in
            DispatchQueue.main.async(execute: {
                // Do something e.g. Alert a user for transfer completion.
                // On failed uploads, `error` contains the error object.
                print("image finished uploading")
            })
        }
        
        let  transferUtility = AWSS3TransferUtility.default()
        
        return transferUtility.uploadData(imageData,
                                          bucket: AMZConstants.S3BUCKET_USERS,
                                          key: fileName,
                                          contentType: "image/jpg",
                                          expression: expression,
                                          completionHandler: completionHandler)
    }

    fileprivate func createDownloadImageTask(_ userId: String) -> AWSTask<AnyObject> {
        
        // The location where the downloaded file has to be saved on the device
        let fileName = "\(userId).jpg"
        let fileURL = deviceDirectoryForDownloads!.appendingPathComponent(fileName)
        
        // Create a task to download the file
        let downloadRequest = AWSS3TransferManagerDownloadRequest()!
        downloadRequest.downloadingFileURL = fileURL
        downloadRequest.bucket = AMZConstants.S3BUCKET_USERS
        downloadRequest.key = fileName
        let transferManager = AWSS3TransferManager.default()
        return transferManager.download(downloadRequest)
    }
    
}


// MARK: - RemoteService

extension AMZRemoteService: RemoteService {
    
    enum providers {
        case loginwithamazon
        case facebook
        case anonymous
    }
    
    func createCurrentUser(_ userData: UserData? , completion: @escaping ErrorResultBlock ) {
        precondition(currentUser == nil, "currentUser should not exist when createCurrentUser(..) is called")
        precondition(userData == nil || userData!.userId == nil, "You can not create a user with a given userId. UserId's are assigned automatically")
        precondition(persistentUserId == nil, "A persistent userId should not yet exist")
        
        guard let identityProvider = identityProvider else {
            preconditionFailure("No identity provider available, did you forget to call configure() before using AMZRemoteService?")
        }
        
        // This covers the scenario that an app was deleted and later reinstalled. 
        // The goal is to create a new identity and a new user profile for this use case. 
        // By default, Cognito stores a Cognito identity in the keychain. 
        // This identity survives app uninstalls, so there can be an identity left from a previous app install. 
        // When we detect this scenario we remove all data from the keychain, so we can start from scratch.
        if identityProvider.identityId != nil {
            identityProvider.clearKeychain()
            assert(identityProvider.identityId == nil)
        }
        
        // Create a new Cognito identity
        let task: AWSTask = identityProvider.getIdentityId()
        task.continueWith(block: { (task) -> AnyObject? in
            if let error = task.error {
                completion(error as NSError?)
            } else {
                // The new cognito identity token is now stored in the keychain.
                // Create a new empty user object of type AMZUser
                var newUser = AMZUser()!
                // Copy the data from the parameter userData
                if let userData = userData {
                    newUser.updateWithData(userData)
                }
                // use identityProvider.identityId so that we can find this user with other non-anon login services (e.g. facebook)
                newUser.userId = self.identityProvider?.identityId
                // Now save the data on AWS. This will save the image on S3, the other data in DynamoDB
                self.saveAMZUser(newUser) { (error) -> Void in
                    if let error = error {
                        completion(error)
                    } else {
                        // Here we can be certain that the user was saved on AWS, so we set the local user instance
                        self.currentUser = newUser
                        self.persistentUserId = newUser.userId
                        completion(nil)
                    }
                }
            }
            return nil
        })
    }

    
    func updateCurrentUser(_ userData: UserData, completion: @escaping ErrorResultBlock) {
        guard var currentUser = currentUser else {
            preconditionFailure("currentUser should already exist when updateCurrentUser(..) is called")
        }
        precondition(userData.userId == nil || userData.userId == currentUser.userId, "Updating current user with a different userId is not allowed")
        precondition(persistentUserId != nil, "A persistent userId should exist")
        
        // create a new empty user
        var updatedUser = AMZUser()!
        // apply the new userData
        updatedUser.updateWithData(userData)
        // restore the userId of the current user
        updatedUser.userId = currentUser.userId
        
        // If there are no changes, there is no need to update.
        if updatedUser.isEqualTo(currentUser) {
            completion(nil)
            return
        }
        
        self.saveAMZUser(updatedUser) { (error) -> Void in
            if let error = error {
                completion(error)
            } else {
                // Here we can be certain that the user was saved on AWS, so we update the local user property
                currentUser.updateWithData(updatedUser)
                completion(nil)
            }
        }
    }
    
    func fetchCurrentUser(_ completion: @escaping UserDataResultBlock) { //(userData, error)
        precondition(persistentUserId != nil, "A persistent userId should exist")
        
        if(identityProvider == nil) {
            configure() // TODO: Can this always be default if not previously configured??
        }
        
        // Task to fetch the DynamoDB data
        let mapper = AWSDynamoDBObjectMapper.default()
        let loadFromDynamoDBTask: AWSTask = mapper.load(AMZUser.self, hashKey: persistentUserId!, rangeKey: nil)
        var outerUser: AMZUser?
        
        loadFromDynamoDBTask.continueOnSuccessWith(block: { (dynamoTask:AWSTask<AnyObject>) -> Any? in
            
            // don't have to check for an error on continueOnSuccessWith
            
            if (dynamoTask.result as? AMZUser) != nil {
                outerUser = dynamoTask.result as? AMZUser
                return self.createDownloadImageTask(self.persistentUserId!)
                // defer completion until the next continueWith()
            } else {
                //completion(nil, nil)
                return nil
            }
        }).continueOnSuccessWith(block: { (downloadTask:AWSTask<AnyObject>) -> Any? in
            
            if outerUser != nil {
                // add the image data to the user
                let fileName = "\(self.persistentUserId!).jpg"
                let fileURL = self.deviceDirectoryForDownloads!.appendingPathComponent(fileName)
                do {
                    try outerUser?.imageData = Data(contentsOf: fileURL)
                } catch let err {
                    print("there was a problem gettting the data, non-fatal . . . \(err)")
                }
                self.currentUser = outerUser
                self.persistentUserId = outerUser?.userId
            }
            
            print("fetchCurrentUser is complete!!")
            completion(outerUser,nil)
            return nil
        })
    }
    
    /*
     * Requires that the authorization token be passed in
     * The authResult is a product of the authorization and contains the .token and AMZNUser (.user)
     */
    func fetchAmazonUser(_ token: String, completion: @escaping UserDataResultBlock) {
        //precondition(apiResult != nil, "token cannot be nil when fetching Amazon user")
        
        if(identityProvider == nil) {
            configure(provider: .loginwithamazon, token: token)
        }
        guard let identityProvider = identityProvider else {
            preconditionFailure("No identity provider available, did you forget to call configure() before using AMZRemoteService?")
        }
        
        let task: AWSTask = identityProvider.getIdentityId()
        task.continueWith(block: { (task) -> AnyObject? in
            if let error = task.error {
                print("there was a problem getting with identityProvider!.getIdentityId()")
                completion(nil, error as NSError?)
            } else {

                // The identityId was found, this user is authorized via amazon login.  Now create a legit user
                self.persistentUserId = self.identityProvider?.identityId
                print(">>>> fAU pUID: \(self.persistentUserId)")
                self.fetchCurrentUser({ (userData, error) in
                    // fetchCurrentUser will return (nil, nil) if this is a new user.  The new
                    // user can be created elsewhere, but we need to nil out the persistentUserId
                    if(userData == nil && error == nil) {
                        self.persistentUserId = nil
                    }
                    completion(userData,error)
                    
                })
            }
            return nil
        })
    }
    
    func fetchFacebookUser(_ completion: @escaping UserDataResultBlock) {
        // This will attempt to fetch a user from the database with the current facebook login
        precondition(AccessToken.current != nil, "Faceboook token should exist")
        
        if(identityProvider == nil) {
            configure(provider: .facebook)
        }
        guard let identityProvider = identityProvider else {
            preconditionFailure("No identity provider available, did you forget to call configure() before using AMZRemoteService?")
        }
        
        /*
        // nuke any existing identityId
        if identityProvider.identityId != nil {
            identityProvider.clearKeychain()
            assert(identityProvider.identityId == nil)
        }
        */
        let task: AWSTask = identityProvider.getIdentityId()
        task.continueWith(block: { (task) -> AnyObject? in
            if let error = task.error {
                print("there was a problem getting with identityProvider!.getIdentityId()")
                completion(nil, error as NSError?)
            } else {
                
                // The identityId was found, this user is authorized via facebook login.  Now create a legit user
                self.persistentUserId = self.identityProvider?.identityId
                print(">>>> fAU pUID: \(self.persistentUserId)")
                self.fetchCurrentUser({ (userData, error) in
                    // fetchCurrentUser will return (nil, nil) if this is a new user.  The new
                    // user can be created elsewhere, but we need to nil out the persistentUserId
                    if(userData == nil && error == nil) {
                        self.persistentUserId = nil
                    }
                    completion(userData,error)
                })
            }
            return nil
        })
        
        
    }

    // MARK: - Additional configure()-ers
    func configure() {
        configure(provider: .anonymous)
    }
    
    public func configure(provider :providers, token: String) {
        precondition(provider == .loginwithamazon, "configure(provider:token:) only for .loginwithamazon")
        var serviceConfiguration :AWSServiceConfiguration
        
        let lwaProviderManager = LoginWithAmazonIdentityProviderManager(token: token)
        
        identityProvider = AWSCognitoCredentialsProvider(
            regionType: AMZConstants.COGNITO_REGIONTYPE,
            identityPoolId: AMZConstants.COGNITO_IDENTITY_POOL_ID,
            identityProviderManager: lwaProviderManager)
        
        serviceConfiguration = AWSServiceConfiguration(
            region: AMZConstants.DEFAULT_SERVICE_REGION,
            credentialsProvider: identityProvider)
        
        AWSServiceManager.default().defaultServiceConfiguration = serviceConfiguration
        
        deviceDirectoryForUploads = createLocalTmpDirectory("upload")
        deviceDirectoryForDownloads = createLocalTmpDirectory("download")
        
    }
    
    public func configure(provider :providers) {
        precondition(provider != .loginwithamazon, "configuration(provider:) cannot be user for .loginwithamazon")
        
        var serviceConfiguration :AWSServiceConfiguration
        
        switch provider {
        case .facebook:
            precondition(AccessToken.current != nil, "AccessToken.current cannot be nil when using Facebook authentication")
            let facebookProviderManager = FacebookIdentityProviderManager()
            
            identityProvider = AWSCognitoCredentialsProvider(
                regionType: AMZConstants.COGNITO_REGIONTYPE,
                identityPoolId: AMZConstants.COGNITO_IDENTITY_POOL_ID,
                identityProviderManager: facebookProviderManager)
            break
            
        case .anonymous:
            fallthrough
            
        default:
            identityProvider = AWSCognitoCredentialsProvider(
                regionType: AMZConstants.COGNITO_REGIONTYPE,
                identityPoolId: AMZConstants.COGNITO_IDENTITY_POOL_ID)
        }
        
        serviceConfiguration = AWSServiceConfiguration(
            region: AMZConstants.DEFAULT_SERVICE_REGION,
            credentialsProvider: identityProvider)
        
        AWSServiceManager.default().defaultServiceConfiguration = serviceConfiguration
        
        deviceDirectoryForUploads = createLocalTmpDirectory("upload")
        deviceDirectoryForDownloads = createLocalTmpDirectory("download")
    }
}

// MARK: - AWSIdentityProviderManagers

class LoginWithAmazonIdentityProviderManager: NSObject, AWSIdentityProviderManager {
    
    var token :String?
    
    convenience init(token: String) {
        self.init()
        self.token = token
    }
    
    func logins() -> AWSTask<NSDictionary> {
        if let token = token {
            return AWSTask(result: [AWSIdentityProviderLoginWithAmazon: token])
        }
        return AWSTask(error:NSError(domain: "Amazon Login", code: -1 , userInfo: ["Amazon" : "No current Amazon access token"]))
    }
}

class FacebookIdentityProviderManager: NSObject, AWSIdentityProviderManager {
    func logins() -> AWSTask<NSDictionary> {
        if let token = AccessToken.current?.authenticationToken {
            return AWSTask(result: [AWSIdentityProviderFacebook:token])
        }
        return AWSTask(error:NSError(domain: "Facebook Login", code: -1 , userInfo: ["Facebook" : "No current Facebook access token"]))
    }
}
