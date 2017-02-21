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

protocol WelcomeViewControllerDelegate: class {
    
    func welcomeViewControllerDidFinish(_ controller: WelcomeViewController)
    
}

class WelcomeViewController: UIViewController {
    
    enum State {
        case welcome
        case welcomed
        case welcomed_amazon
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
                createProfileButton.isHidden = true
                continueButton.isHidden = true
                orLabel.isHidden = false
                activityIndicator.isHidden = true
            case .welcomed:
                showMessage("You are now signed in. An empty user profile with a unique userId has already been created behind the scenes in DynamoDB.", type: GSMessageType.info, options: MessageOptions.Info)
                signInButton.isHidden = true
                amazonButton.isHidden = true
                createProfileButton.isHidden = false
                continueButton.isHidden = true
                orLabel.isHidden = true
                activityIndicator.isHidden = true
            case .welcomed_amazon:
                showMessage("You are now signed in using your Amazon account. A user profile with your Amazon info and a unique userId has already been created behind the scenes in DynamoDB.", type: GSMessageType.info, options: MessageOptions.Info)
                signInButton.isHidden = true
                amazonButton.isHidden = true
                createProfileButton.setTitle("Edit Profile", for: UIControlState())
                createProfileButton.isHidden = false
                continueButton.isHidden = true
                orLabel.isHidden = true
                activityIndicator.isHidden = true
            case .fetchingUserProfile:
                signInButton.isHidden = true
                amazonButton.isHidden = true
                createProfileButton.isHidden = true
                continueButton.isHidden = true
                orLabel.isHidden = true
                activityIndicator.isHidden = false
                activityIndicator.startAnimating()
            case .fetchedUserProfile:
                showMessage("You are automatically signed in on your existing account. Your user profile data was fetched from AWS on the background.", type: GSMessageType.info, options: MessageOptions.Info)
                signInButton.isHidden = true
                amazonButton.isHidden = true
                createProfileButton.setTitle("Edit Profile", for: UIControlState())
                createProfileButton.isHidden = false
                continueButton.isHidden = false
                orLabel.isHidden = false
                activityIndicator.isHidden = true
                activityIndicator.stopAnimating()
            }
        }
    }
    
    let service = RemoteServiceFactory.getDefaultService()
    
    @IBOutlet weak var signInButton: ButtonWithActivityIndicator!
    
    @IBOutlet weak var amazonButton: ButtonWithActivityIndicator!
    
    @IBOutlet weak var createProfileButton: UIButton!
    
    @IBOutlet weak var continueButton: ButtonWithActivityIndicator!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var orLabel: UILabel!
    
    @IBAction func didTapAmazonButton(_ sender: Any) {
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
                            }
                        })
                    } else if ((userData != nil) && (error == nil)) {
                        DispatchQueue.main.async(execute: { () -> Void in
                            self.state = .welcomed_amazon
                            self.amazonButton.stopAnimating()
                        })
                    } else {
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

