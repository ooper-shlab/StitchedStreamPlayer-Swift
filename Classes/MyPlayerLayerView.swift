//
//  MyPlayerLayerView.swift
//  StitchedStreamPlayer
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/12/1.
//
//
/*
Copyright (C) 2016 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
Abstract: A UIView subclass that contains an AVPlayerLayer.
*/

import UIKit
import AVFoundation

@objc(MyPlayerLayerView)
class MyPlayerLayerView: UIView {
    
    /* ---------------------------------------------------------
    **  To play the visual component of an asset, you need a view
    **  containing an AVPlayerLayer layer to which the output of an
    **  AVPlayer object can be directed. You can create a simple
    **  subclass of UIView to accommodate this. Use the view’s Core
    **  Animation layer (see the 'layer' property) for rendering.
    **  This class is a subclass of UIView that is used for this
    **  purpose.
    ** ------------------------------------------------------- */
    
    
    override class var layerClass : AnyClass {
        return AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        return self.layer as! AVPlayerLayer
    }
    
    func setPlayer(_ player: AVPlayer) {
        (self.layer as! AVPlayerLayer).player = player
    }
    
    /* Specifies how the video is displayed within a player layer’s bounds.
    (AVLayerVideoGravityResizeAspect is default) */
    func setVideoFillMode(_ fillMode: String) {
        let playerLayer = self.layer as! AVPlayerLayer
        playerLayer.videoGravity = fillMode
    }
    
    
}
