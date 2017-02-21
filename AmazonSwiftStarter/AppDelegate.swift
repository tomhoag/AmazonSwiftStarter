//
//  AppDelegate.swift
//  AmazonSwiftStarter
//
//  Created by Peter Fennema on 12/02/16.
//  Copyright © 2016 Peter Fennema. All rights reserved.
//

import UIKit
import IQKeyboardManagerSwift
import LoginWithAmazon

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        window!.backgroundColor = UIColor.white
        
        IQKeyboardManager.sharedManager().enable = true
        
        let welcomeViewController = window!.rootViewController as! WelcomeViewController
        welcomeViewController.delegate = self
        
        //SDKApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        return true
    }
    
    @available(iOS 9.0, *)
    public func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool
    {
        // return SDKApplicationDelegate.shared.application(app, open: url, options: options) // Facebook
        return AIMobileLib.handleOpen(url, sourceApplication: UIApplicationOpenURLOptionsKey.sourceApplication.rawValue) // LWA
        /*
        return SDKApplicationDelegate.shared.application(app, open: url, options: options) ||
            AIMobileLib.handleOpen(url, sourceApplication: UIApplicationOpenURLOptionsKey.sourceApplication.rawValue)
        */
    }
    
    // AWSS3TransferUtility
    /*
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        // Store the completion handler.
        AWSS3TransferUtility.interceptApplication(application, handleEventsForBackgroundURLSession: identifier, completionHandler: completionHandler)
    }
    */

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }


}

// MARK: - WelcomeViewControllerDelegate

extension AppDelegate: WelcomeViewControllerDelegate {
    
    func welcomeViewControllerDidFinish(_ controller: WelcomeViewController) {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let tabBarVC = storyBoard.instantiateViewController(withIdentifier: "tabBarController") as! UITabBarController
        self.window!.rootViewController = tabBarVC
        UIView.transition(with: window!,
            duration: 0.5,
            options: .transitionCrossDissolve,
            animations: { () -> Void in
                self.window!.rootViewController = tabBarVC
            },
            completion: nil)
    }
    
}
