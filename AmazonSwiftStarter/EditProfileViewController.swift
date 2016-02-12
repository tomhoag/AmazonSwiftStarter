//
//  EditProfileViewController.swift
//  AmazonSwiftStarter
//
//  Created by Peter Fennema on 12/02/16.
//  Copyright © 2016 Peter Fennema. All rights reserved.
//

import UIKit

protocol EditProfileViewControllerDelegate: class {
    
    func editProfileViewControllerDidFinishEditing(controller: EditProfileViewController)
    
}

class EditProfileViewController: UIViewController {
    
    weak var delegate: EditProfileViewControllerDelegate?
    
    @IBAction func didTapDone(sender: UIButton) {
        if let delegate = delegate {
            delegate.editProfileViewControllerDidFinishEditing(self)
        }
    }

}
