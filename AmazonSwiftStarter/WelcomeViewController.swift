//
//  WelcomeViewController.swift
//  AmazonSwiftStarter
//
//  Created by Peter Fennema on 12/02/16.
//  Copyright © 2016 Peter Fennema. All rights reserved.
//

import UIKit
import GSMessages
import LoginWithAmazon
import FacebookCore
import FacebookLogin

protocol WelcomeViewControllerDelegate: class {
    
    func welcomeViewControllerDidFinish(_ controller: WelcomeViewController)
    
}

class WelcomeViewController: UIViewController {
    
    enum State {
        case welcome
        case welcomed
        case welcomed_amazon
        case welcomed_facebook
        case fetchingUserProfile
        case fetchedUserProfile
    }
    
    weak var delegate: WelcomeViewControllerDelegate?
    
    fileprivate var state: State = .welcome {
        didSet {
            switch state {
            case .welcome:
                showMessage("\"Anonymous Sign In\" will call AWS Cognito. The app will receive an identity token from the Cognito Service and will store it on the device.", type: GSMessageType.info, options: MessageOptions.Info)
                signInButton.isHidden = false
                amazonButton.isHidden = false
                facebookButton.isHidden = false
                createProfileButton.isHidden = true
                continueButton.isHidden = true
                orLabel.isHidden = false
                topOrLabel.isHidden = false
                activityIndicator.isHidden = true
            case .welcomed:
                showMessage("You are now signed in. An empty user profile with a unique userId has already been created behind the scenes in DynamoDB.", type: GSMessageType.info, options: MessageOptions.Info)
                signInButton.isHidden = true
                amazonButton.isHidden = true
                facebookButton.isHidden = true
                createProfileButton.isHidden = false
                continueButton.isHidden = true
                orLabel.isHidden = true
                topOrLabel.isHidden = true
                activityIndicator.isHidden = true
            case .welcomed_facebook:
                showMessage("You are now signed in using your Facebook account. A user profile with your Facebook info and a unique userId has already been created behind the scenes in DynamoDB.", type: GSMessageType.info, options: MessageOptions.Info)
                signInButton.isHidden = true
                amazonButton.isHidden = true
                facebookButton.isHidden = true
                createProfileButton.setTitle("Edit Profile", for: UIControlState())
                createProfileButton.isHidden = false
                continueButton.isHidden = true
                orLabel.isHidden = true
                topOrLabel.isHidden = true
                activityIndicator.isHidden = true
            case .welcomed_amazon:
                showMessage("You are now signed in using your Amazon account. A user profile with your Amazon info and a unique userId has already been created behind the scenes in DynamoDB.", type: GSMessageType.info, options: MessageOptions.Info)
                signInButton.isHidden = true
                amazonButton.isHidden = true
                facebookButton.isHidden = true
                createProfileButton.setTitle("Edit Profile", for: UIControlState())
                createProfileButton.isHidden = false
                continueButton.isHidden = true
                orLabel.isHidden = true
                topOrLabel.isHidden = true
                activityIndicator.isHidden = true
            case .fetchingUserProfile:
                signInButton.isHidden = true
                amazonButton.isHidden = true
                facebookButton.isHidden = true
                createProfileButton.isHidden = true
                continueButton.isHidden = true
                orLabel.isHidden = true
                topOrLabel.isHidden = true
                activityIndicator.isHidden = false
                activityIndicator.startAnimating()
            case .fetchedUserProfile:
                showMessage("You are automatically signed in on your existing account. Your user profile data was fetched from AWS on the background.", type: GSMessageType.info, options: MessageOptions.Info)
                signInButton.isHidden = true
                amazonButton.isHidden = true
                facebookButton.isHidden = true
                createProfileButton.setTitle("Edit Profile", for: UIControlState())
                createProfileButton.isHidden = false
                continueButton.isHidden = false
                orLabel.isHidden = false
                topOrLabel.isHidden = true
                activityIndicator.isHidden = true
                activityIndicator.stopAnimating()
            }
        }
    }
    
    let service = RemoteServiceFactory.getDefaultService()
    
    @IBOutlet weak var signInButton: ButtonWithActivityIndicator!
    
    @IBOutlet weak var amazonButton: ButtonWithActivityIndicator!
    
    @IBOutlet weak var facebookButton: ButtonWithActivityIndicator!
    
    @IBOutlet weak var createProfileButton: UIButton!
    
    @IBOutlet weak var continueButton: ButtonWithActivityIndicator!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var orLabel: UILabel!
    
    @IBOutlet weak var topOrLabel: UILabel!
    

    @IBAction func didTapAmazonButton(_ sender: UIButton) {
        hideMessage()
        amazonButton.startAnimating()
        // login in the amazon user
        
        let request = AMZNAuthorizeRequest()
        request.scopes = [AMZNProfileScope.profile()] //["profile"]
        //request.interactiveStrategy = AMZNInteractiveStrategy.never
        
        AMZNAuthorizationManager.shared().authorize(request) { (authResult, userDidCancel, error) in
            if ((error) != nil) {
                print(error!)
                DispatchQueue.main.async(execute: { () -> Void in
                    self.state = .welcome
                    self.amazonButton.stopAnimating()
                })
            } else if (userDidCancel) {
                DispatchQueue.main.async(execute: { () -> Void in
                    self.state = .welcome
                    self.amazonButton.stopAnimating()
                })
            } else {
                // Authentication was successful. Obtain the access token and user profile data.
                // let accessToken = authResult?.token; let user = authResult?.user; let userID = authResult?.userID;
                
                self.service.fetchAmazonUser(authResult!.token, completion: { (userData, error) in

                    if(!(error != nil) && !(userData != nil)) { // The user is new
                        
                        var newAmazonUser = UserDataValue()
                        newAmazonUser.name = authResult?.user?.name
                        
                        self.service.createCurrentUser(newAmazonUser, completion: { (error) in
                            if let error = error {
                                print("something went wrong in createCurrentUser: \(error)")
                            } else {
                                DispatchQueue.main.async(execute: { () -> Void in
                                    self.state = .welcomed_amazon
                                    self.amazonButton.stopAnimating()
                                })
                            }
                        })
                    } else if ((userData != nil) && (error == nil)) { // Existing User
                        DispatchQueue.main.async(execute: { () -> Void in
                            self.state = .welcomed_amazon
                            self.amazonButton.stopAnimating()
                        })
                    } else { // uh-oh
                        print("something went wrong in fetchAmazonUser: \(error)")
                        DispatchQueue.main.async(execute: { () -> Void in
                            self.state = .welcome
                            self.amazonButton.stopAnimating()
                        })
                    }
                })
            }
        }
    }
    
    @IBAction func didTapFacebookButton(_ sender: UIButton) {
        hideMessage()
        facebookButton.startAnimating()
        
        let loginManager = LoginManager()
        loginManager.logIn([ ReadPermission.publicProfile ], viewController: self) { loginResult in
            switch loginResult {
            case .failed(let error): // uh-oh
                print(error)
                self.facebookButton.stopAnimating()
            case .cancelled: //User cancelled login
                self.facebookButton.stopAnimating()
            case .success( _,  _,  _): // successful login
                UserProfile.loadCurrent({ (comp) in // fetch fb info
                    self.service.fetchFacebookUser() { (userData, error) -> Void in
                        if(!(error != nil) && !(userData != nil)) { // The user is new
                            
                            var newFacebookUser = UserDataValue() // create a new user from the FB name and profile pic
                            newFacebookUser.name = UserProfile.current?.fullName
                            // Create and run a URLSession to fetch the fb profile pic
                            let fbID = UserProfile.current?.userId
                            let profileURL = URL(string:"https://graph.facebook.com/"+fbID!+"/picture?type=large")
                            let session = URLSession(configuration: .default)
                            let downloadPicTask = session.dataTask(with: profileURL!, completionHandler: { (data, response, error) in
                                if let error = error {
                                    // no biggie, maybe there isn't a profile pic??
                                    print(">>>>>> error fetching fb profile pic: \(error)")
                                } else {
                                    if let data = data {
                                        newFacebookUser.imageData = data
                                    }
                                }
                                self.service.createCurrentUser(newFacebookUser, completion: { (error) in
                                    if let error = error {
                                        print("something went wrong in createCurrentUser: \(error)")
                                    } else {
                                        DispatchQueue.main.async(execute: { () -> Void in
                                            self.state = .welcomed_amazon
                                            self.facebookButton.stopAnimating()
                                        })
                                    }
                                })

                            })
                            downloadPicTask.resume()
                            
                        } else if ((userData != nil) && (error == nil)) { // Existing User
                            DispatchQueue.main.async(execute: { () -> Void in
                                self.state = .welcomed_facebook
                                self.facebookButton.stopAnimating()
                            })
                        } else { // uh-oh
                            print("something went wrong in fetchAmazonUser: \(error)")
                            DispatchQueue.main.async(execute: { () -> Void in
                                self.state = .welcome
                                self.facebookButton.stopAnimating()
                            })
                        }
                    }
                })
            }
        }
    }
    
    @IBAction func didTapSignInButton(_ sender: UIButton) {
        hideMessage()
        signInButton.startAnimating()
        service.createCurrentUser(nil) { (error) -> Void in
            DispatchQueue.main.async(execute: { () -> Void in
                self.state = .welcomed
                self.signInButton.stopAnimating()
            })
        }
    }
    
    @IBAction func didTapContinueButton(_ sender: UIButton) {
        if let delegate = self.delegate {
            delegate.welcomeViewControllerDidFinish(self)
        }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        if service.hasCurrentUserIdentity {
            state = .fetchingUserProfile
            service.fetchCurrentUser({ (userData, error) -> Void in
                if let error = error {
                    print(error)
                }
                DispatchQueue.main.async(execute: { () -> Void in
                    self.state = .fetchedUserProfile
                })
            })
        } else {
            state = .welcome
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "editProfileSegue" {
            hideMessage()
            let destVC = segue.destination as! EditProfileViewController
            destVC.delegate = self
        }
    }
    
}

// MARK: - EditProfileViewControllerDelegate

extension WelcomeViewController: EditProfileViewControllerDelegate {
    
    func editProfileViewControllerDidFinishEditing(_ controller: EditProfileViewController) {
        self.view.isHidden = true
        controller.dismiss(animated: true) { () -> Void in
            if let delegate = self.delegate {
                delegate.welcomeViewControllerDidFinish(self)
            }
        }
    }
    
}

