//
//  MoviePlayerAppDelegate.swift
//  StitchedStreamPlayer
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/12/1.
//
//
/*
Copyright (C) 2016 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
A simple UIApplication delegate class that adds the StreamingViewController
view to the window as a subview.
*/

import UIKit

@UIApplicationMain
@objc(MoviePlayerAppDelegate)
class MoviePlayerAppDelegate: NSObject, UIApplicationDelegate, UITabBarControllerDelegate {
    
    @IBOutlet var window: UIWindow?
    @IBOutlet var streamingViewController: MyStreamingMovieViewController?
    
    
    func applicationDidFinishLaunching(_ application: UIApplication) {
        // Specify the streaming view controller as the root view controller of the window
        window?.rootViewController = streamingViewController
        
        window?.makeKeyAndVisible()
    }
    
}
