//
//  WelcomeViewController.swift
//  AmazonSwiftStarter
//
//  Created by Peter Fennema on 12/02/16.
//  Copyright © 2016 Peter Fennema. All rights reserved.
//

import UIKit
import GSMessages

protocol WelcomeViewControllerDelegate: class {
    
    func welcomeViewControllerDidFinish(controller: WelcomeViewController)
    
}

class WelcomeViewController: UIViewController {
    
    enum State {
        case Welcome
        case Welcomed
    }


    weak var delegate: WelcomeViewControllerDelegate?
    
    private var state: State = .Welcome {
        didSet {
            switch state {
            case .Welcome:
                showMessage("\"Anonymous Sign In\" will call AWS Cognito. The app will receive an identity token from the Cognito Service and will store it on the device.", type: GSMessageType.Info, options: MessageOptions.Info)
                signInButton.hidden = false
                createProfileButton.hidden = true
            case .Welcomed:
                showMessage("You are now signed in. An empty user profile with a unique userId has already been created behind the scenes in DynamoDB. The user data will be added in the next step.", type: GSMessageType.Info, options: MessageOptions.Info)
                signInButton.hidden = true
                createProfileButton.hidden = false
            }
        }
    }
    
    @IBOutlet weak var signInButton: UIButton!
    
    @IBOutlet weak var createProfileButton: UIButton!
    
    
    @IBAction func didTapSignInButton(sender: UIButton) {
        state = .Welcomed
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        state = .Welcome
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "editProfileSegue" {
            let destVC = segue.destinationViewController as! EditProfileViewController
            destVC.delegate = self
        }
    }

}

// MARK: - EditProfileViewControllerDelegate

extension WelcomeViewController: EditProfileViewControllerDelegate {
    
    func editProfileViewControllerDidFinishEditing(controller: EditProfileViewController) {
        self.view.hidden = true
        controller.dismissViewControllerAnimated(true) { () -> Void in
            if let delegate = self.delegate {
                delegate.welcomeViewControllerDidFinish(self)
            }
        }
    }
    
}

