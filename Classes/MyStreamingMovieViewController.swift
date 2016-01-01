//
//  MyStreamingMovieViewController.swift
//  StitchedStreamPlayer
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/12/1.
//
//
/*
    File: MyStreamingMovieViewController.h
    File: MyStreamingMovieViewController.m
Abstract:
A UIViewController controller subclass that loads the SecondView nib file that contains its view.
 Contains an action method that is called when the Play Movie button is pressed to play the movie.
 Provides a text edit control for the user to enter a movie URL.
 Manages a collection of transport control UI that allows the user to play/pause and seek.

 Version: 1.4

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Inc. ("Apple") in consideration of your agreement to the following
terms, and your use, installation, modification or redistribution of
this Apple software constitutes acceptance of these terms.  If you do
not agree with these terms, please do not use, install, modify or
redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may
be used to endorse or promote products derived from the Apple Software
without specific prior written permission from Apple.  Except as
expressly stated in this notice, no other rights or licenses, express or
implied, are granted by Apple herein, including but not limited to any
patent rights that may be infringed by your derivative works or by other
works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2011 Apple Inc. All Rights Reserved.

*/

import UIKit
import AVFoundation
import CoreMedia


private var MyStreamingMovieViewControllerTimedMetadataObserverContext_ = 0
private var MyStreamingMovieViewControllerRateObservationContext_ = 0
private var MyStreamingMovieViewControllerCurrentItemObservationContext_ = 0
private var MyStreamingMovieViewControllerPlayerItemStatusObserverContext_ = 0

@objc(MyStreamingMovieViewController)
class MyStreamingMovieViewController: UIViewController, UITextFieldDelegate {
    
    var movieURL: NSURL?
    var player: AVPlayer?
    var playerItem: AVPlayerItem?
    @IBOutlet var playerLayerView: MyPlayerLayerView!
    
    @IBOutlet var movieURLTextField: UITextField!
    
    @IBOutlet var movieTimeControl: UISlider!
    var isSeeking: Bool = false
    var seekToZeroBeforePlay: Bool = false
    var restoreAfterScrubbingRate: Float = 0.0
    
    var timeObserver: AnyObject?
    
    @IBOutlet var toolBar: UIToolbar!
    @IBOutlet var playButton: UIBarButtonItem!
    @IBOutlet var stopButton: UIBarButtonItem!
    
    @IBOutlet var isPlayingAdText: UILabel!
    
    var adList: [NSObject] = []
    
    private let kTracksKey		= "tracks"
    private let kStatusKey		= "status"
    private let kRateKey			= "rate"
    private let kPlayableKey		= "playable"
    private let kCurrentItemKey	= "currentItem"
    private let kTimedMetadataKey	= "currentItem.timedMetadata"
    
    //MARK: -
    //MARK: Movie controller methods
    //MARK: -
    
    /* ---------------------------------------------------------
    **  Methods to handle manipulation of the movie scrubber control
    ** ------------------------------------------------------- */
    
    //MARK: Play, Stop Buttons
    
    /* Show the stop button in the movie player controller. */
    private func showStopButton() {
        var toolbarItems = toolBar.items
        toolbarItems?[0] = stopButton
        toolBar.items = toolbarItems
    }
    
    /* Show the play button in the movie player controller. */
    private func showPlayButton() {
        var toolbarItems = toolBar.items
        toolbarItems?[0] = playButton
        toolBar.items = toolbarItems
    }
    
    /* If the media is playing, show the stop button; otherwise, show the play button. */
    private func syncPlayPauseButtons() {
        if self.playing {
            self.showStopButton()
        } else {
            self.showPlayButton()
        }
    }
    
    private func enablePlayerButtons() {
        self.playButton.enabled = true
        self.stopButton.enabled = true
    }
    
    private func disablePlayerButtons() {
        self.playButton.enabled = false
        self.stopButton.enabled = false
    }
    
    //MARK: Scrubber control
    
    /* Set the scrubber based on the player current time. */
    private func syncScrubber() {
        let playerDuration = self.playerItemDuration()
        if CMTIME_IS_INVALID(playerDuration) {
            movieTimeControl.minimumValue = 0.0
            return
        }
        
        let duration = CMTimeGetSeconds(playerDuration)
        if isfinite(duration) && duration > 0 {
            let minValue = movieTimeControl.minimumValue
            let maxValue = movieTimeControl.maximumValue
            let time = CMTimeGetSeconds(player!.currentTime())
            movieTimeControl.value = (maxValue - minValue) * Float(time) / Float(duration) + minValue
        }
    }
    
    /* Requests invocation of a given block during media playback to update the
    movie scrubber control. */
    private func initScrubberTimer() {
        var interval = 0.1
        
        let playerDuration = self.playerItemDuration()
        if CMTIME_IS_INVALID(playerDuration) {
            return
        }
        let duration = CMTimeGetSeconds(playerDuration)
        if isfinite(duration) {
            let width = CGRectGetWidth(movieTimeControl.bounds)
            interval = 0.5 * duration / Double(width)
        }
        
        /* Update the scrubber during normal playback. */
        timeObserver = player?.addPeriodicTimeObserverForInterval(CMTimeMakeWithSeconds(interval, Int32(NSEC_PER_SEC)),
            queue: nil) {time in
                self.syncScrubber()
        }
    }
    
    /* Cancels the previously registered time observer. */
    private func removePlayerTimeObserver() {
        if timeObserver != nil {
            player?.removeTimeObserver(timeObserver!)
            timeObserver = nil
        }
    }
    
    /* The user is dragging the movie controller thumb to scrub through the movie. */
    @IBAction func beginScrubbing(_: AnyObject) {
        restoreAfterScrubbingRate = player?.rate ?? 0.0
        player?.rate = 0.0
        
        /* Remove previous timer. */
        self.removePlayerTimeObserver()
    }
    
    /* The user has released the movie thumb control to stop scrubbing through the movie. */
    @IBAction func endScrubbing(_: AnyObject) {
        if timeObserver == nil {
            let playerDuration = self.playerItemDuration()
            if CMTIME_IS_INVALID(playerDuration) {
                return
            }
            
            let duration = CMTimeGetSeconds(playerDuration)
            if isfinite(duration) {
                let width = CGRectGetWidth(movieTimeControl.bounds)
                let tolerance = 0.5 * duration / Double(width)
                
                timeObserver = player?.addPeriodicTimeObserverForInterval(CMTimeMakeWithSeconds(tolerance, Int32(NSEC_PER_SEC)), queue: dispatch_get_main_queue()) {time in
                    self.syncScrubber()
                }
            }
        }
        
        if restoreAfterScrubbingRate != 0.0 {
            player?.rate = restoreAfterScrubbingRate
            restoreAfterScrubbingRate = 0.0
        }
    }
    
    /* Set the player current time to match the scrubber position. */
    @IBAction func scrub(sender: AnyObject) {
        if let slider = sender as? UISlider {
            
            let playerDuration = self.playerItemDuration()
            if CMTIME_IS_INVALID(playerDuration) {
                return
            }
            
            let duration = CMTimeGetSeconds(playerDuration)
            if isfinite(duration) {
                let minValue = slider.minimumValue
                let maxValue = slider.maximumValue
                let value = slider.value
                
                let time = duration * Double(value - minValue) / Double(maxValue - minValue)
                
                player?.seekToTime(CMTimeMakeWithSeconds(time, Int32(NSEC_PER_SEC)))
            }
        }
    }
    
    var scrubbing: Bool {
        return restoreAfterScrubbingRate != 0.0
    }
    
    private func enableScrubber() {
        self.movieTimeControl.enabled = true
    }
    
    private func disableScrubber() {
        self.movieTimeControl.enabled = false
    }
    
    /* Prevent the slider from seeking during Ad playback. */
    private func sliderSyncToPlayerSeekableTimeRanges() {
        let seekableTimeRanges = player?.currentItem?.seekableTimeRanges
        if seekableTimeRanges?.count ?? 0 > 0 {
            let range = seekableTimeRanges![0]
            let timeRange = range.CMTimeRangeValue
            let startSeconds = CMTimeGetSeconds(timeRange.start)
            let durationSeconds = CMTimeGetSeconds(timeRange.duration)
            
            /* Set the minimum and maximum values of the time slider to match the seekable time range. */
            movieTimeControl.minimumValue = Float(startSeconds)
            movieTimeControl.maximumValue = Float(startSeconds + durationSeconds)
        }
    }
    
    //MARK: Button Action Methods
    
    @IBAction func play(_: AnyObject) {
        /* If we are at the end of the movie, we must seek to the beginning first
        before starting playback. */
        if seekToZeroBeforePlay {
            seekToZeroBeforePlay = false
            player?.seekToTime(kCMTimeZero)
        }
        
        player?.play()
        
        self.showStopButton()
    }
    
    @IBAction func pause(_: AnyObject) {
        player?.pause()
        
        self.showPlayButton()
    }
    
    @IBAction func loadMovieButtonPressed(_: AnyObject) {
        /* Has the user entered a movie URL? */
        if let movieURLText = self.movieURLTextField.text where !movieURLText.isEmpty {
            if let newMovieURL = NSURL(string: movieURLText) {
                /*
                Create an asset for inspection of a resource referenced by a given URL.
                Load the values for the asset keys "tracks", "playable".
                */
                let asset = AVURLAsset(URL: newMovieURL, options: nil)
                
                let requestedKeys = [kTracksKey, kPlayableKey]
                
                /* Tells the asset to load the values of any of the specified keys that are not already loaded. */
                asset.loadValuesAsynchronouslyForKeys(requestedKeys) {
                    dispatch_async(dispatch_get_main_queue()) {
                        /* IMPORTANT: Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem. */
                        self.prepareToPlayAsset(asset, withKeys: requestedKeys)
                    }
                }
            }
        }
    }
    
    func textFieldShouldReturn(theTextField: UITextField) -> Bool {
        /* When the user presses return, take focus away from the text
        field so that the keyboard is dismissed. */
        if theTextField === self.movieURLTextField {
            self.movieURLTextField.resignFirstResponder()
        }
        
        return true
    }
    
    //MARK: -
    //MARK: View Controller
    //MARK: -
    
    //- (void)viewDidUnload
    //{
    //    self.playerLayerView = nil;
    //    self.toolBar = nil;
    //    self.playButton = nil;
    //    self.stopButton = nil;
    //    self.movieTimeControl = nil;
    //    self.movieURLTextField = nil;
    //    self.isPlayingAdText = nil;
    //    [timeObserver release];
    //    [movieURL release];
    //
    //    [super viewDidUnload];
    //}
    
    override func viewDidLoad() {
        let view = self.view
        let swipeUpRecognizer = UISwipeGestureRecognizer(target: self, action: "handleSwipe:")
        swipeUpRecognizer.direction = .Up
        view.addGestureRecognizer(swipeUpRecognizer)
        
        let swipeDownRecognizer = UISwipeGestureRecognizer(target: self, action: "handleSwipe:")
        swipeDownRecognizer.direction = .Down
        view.addGestureRecognizer(swipeDownRecognizer)
        
        let scrubberItem = UIBarButtonItem(customView: movieTimeControl)
        let flexItem = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
        
        toolBar.items = [playButton, flexItem, scrubberItem]
        
        super.viewDidLoad()
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .All
    }
    override func preferredInterfaceOrientationForPresentation() -> UIInterfaceOrientation {
        return .Portrait
    }
    
    @objc func handleSwipe(gestureRecognizer: UISwipeGestureRecognizer) {
        let view = self.view
        let direction = gestureRecognizer.direction
        let location = gestureRecognizer.locationInView(view)
        
        if location.y < CGRectGetMidY(view.bounds) {
            if direction == .Up {
                UIView.animateWithDuration(0.2, animations: {
                    self.navigationController?.setNavigationBarHidden(true, animated: true)
                    }, completion: {finished in
                        UIApplication.sharedApplication().setStatusBarHidden(true, withAnimation: .Slide)
                })
            }
            if direction == .Down {
                UIView.animateWithDuration(0.2, animations: {
                    UIApplication.sharedApplication().setStatusBarHidden(false, withAnimation: .Slide)
                    }, completion: {finished in
                        self.navigationController?.setNavigationBarHidden(false, animated: true)
                })
            }
        } else {
            if direction == .Down {
                if !toolBar.hidden {
                    UIView.animateWithDuration(0.2, animations: {
                        self.toolBar.transform = CGAffineTransformMakeTranslation(0.0, CGRectGetHeight(self.toolBar.bounds))
                        }, completion: {finished in
                            self.toolBar.hidden = true
                    })
                }
            } else if direction == .Up {
                if toolBar.hidden {
                    toolBar.hidden = false
                    
                    UIView.animateWithDuration(0.2, animations: {
                        self.toolBar.transform = CGAffineTransformIdentity
                        }, completion: {finished in})
                }
            }
        }
    }
    
    deinit {
        timeObserver = nil
        movieURL = nil
        NSNotificationCenter.defaultCenter().removeObserver(self,
            name: AVPlayerItemDidPlayToEndTimeNotification,
            object: nil)
        self.player?.removeObserver(self, forKeyPath: kCurrentItemKey)
        self.player?.removeObserver(self, forKeyPath: kTimedMetadataKey)
        self.player?.removeObserver(self, forKeyPath: kRateKey)
        
    }
    
    //MARK: -
    
    //MARK: Player
    
    /* ---------------------------------------------------------
    **  Get the duration for a AVPlayerItem.
    ** ------------------------------------------------------- */
    
    private func playerItemDuration() -> CMTime {
        let thePlayerItem = player?.currentItem
        if thePlayerItem?.status == AVPlayerItemStatus.ReadyToPlay {
            /*
            NOTE:
            Because of the dynamic nature of HTTP Live Streaming Media, the best practice
            for obtaining the duration of an AVPlayerItem object has changed in iOS 4.3.
            Prior to iOS 4.3, you would obtain the duration of a player item by fetching
            the value of the duration property of its associated AVAsset object. However,
            note that for HTTP Live Streaming Media the duration of a player item during
            any particular playback session may differ from the duration of its asset. For
            this reason a new key-value observable duration property has been defined on
            AVPlayerItem.
            
            See the AV Foundation Release Notes for iOS 4.3 for more information.
            */
            
            return playerItem?.duration ?? CMTime()
        }
        
        return kCMTimeInvalid
    }
    
    private var playing: Bool {
        return restoreAfterScrubbingRate != 0.0 || player?.rate != 0.0
    }
    
    //MARK: Player Notifications
    
    /* Called when the player item has played to its end time. */
    @objc func playerItemDidReachEnd(aNotification: NSNotification) {
        /* Hide the 'Pause' button, show the 'Play' button in the slider control */
        self.showPlayButton()
        
        /* After the movie has played to its end time, seek back to time zero
        to play it again */
        seekToZeroBeforePlay = true
    }
    
    //MARK: -
    //MARK: Timed metadata
    //MARK: -
    
    private func handleTimedMetadata(timedMetadata: AVMetadataItem) {
        /* We expect the content to contain plists encoded as timed metadata. AVPlayer turns these into NSDictionaries. */
        if (timedMetadata.key as! String) == AVMetadataID3MetadataKeyGeneralEncapsulatedObject {
            if let propertyList = timedMetadata.value as? [String: AnyObject] {
                
                /* Metadata payload could be the list of ads. */
                if let newAdList = propertyList["ad-list"] as? [NSObject] {
                    self.updateAdList(newAdList)
                    NSLog("ad-list is %@", newAdList)
                }
                
                /* Or it might be an ad record. */
                if let adURL = propertyList["url"] as? String {
                    if adURL.isEmpty {
                        /* Ad is not playing, so clear text. */
                        self.isPlayingAdText.text = ""
                        
                        self.enablePlayerButtons()
                        self.enableScrubber() /* Enable seeking for main content. */
                        
                        NSLog("enabling seek at %g", CMTimeGetSeconds(player?.currentTime() ?? CMTime()))
                    } else {
                        /* Display text indicating that an Ad is now playing. */
                        self.isPlayingAdText.text = "< Ad now playing, seeking is disabled on the movie controller... >"
                        
                        self.disablePlayerButtons()
                        self.disableScrubber()
                        
                        NSLog("disabling seek at %g", CMTimeGetSeconds(player?.currentTime() ?? CMTime()))
                    }
                }
            }
        }
    }
    
    //MARK: Ad list
    
    /* Update current ad list, set slider to match current player item seekable time ranges */
    private func updateAdList(newAdList: [NSObject]) {
        if adList != newAdList {
            adList = newAdList
            
            self.sliderSyncToPlayerSeekableTimeRanges()
        }
    }
    
    //MARK: -
    //MARK: Loading the Asset Keys Asynchronously
    
    //MARK: -
    //MARK: Error Handling - Preparing Assets for Playback Failed
    
    /* --------------------------------------------------------------
    **  Called when an asset fails to prepare for playback for any of
    **  the following reasons:
    **
    **  1) values of asset keys did not load successfully,
    **  2) the asset keys did load successfully, but the asset is not
    **     playable
    **  3) the item did not become ready to play.
    ** ----------------------------------------------------------- */
    
    private func assetFailedToPrepareForPlayback(error: NSError) {
        self.removePlayerTimeObserver()
        self.syncScrubber()
        self.disableScrubber()
        self.disablePlayerButtons()
        
        /* Display the error. */
        if #available(iOS 8.0, *) {
            let alertController = UIAlertController(title: error.localizedDescription, message: error.localizedFailureReason, preferredStyle: .Alert)
            let okAction = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
            alertController.addAction(okAction)
            self.presentViewController(alertController, animated: true, completion: nil)
        } else {
            let alertView = UIAlertView(title: error.localizedDescription,
                message: error.localizedFailureReason,
                delegate: nil,
                cancelButtonTitle: "OK")
            alertView.show()
        }
    }
    
    //MARK: Prepare to play asset
    
    /*
    Invoked at the completion of the loading of the values for all keys on the asset that we require.
    Checks whether loading was successfull and whether the asset is playable.
    If so, sets up an AVPlayerItem and an AVPlayer to play the asset.
    */
    private func prepareToPlayAsset(asset: AVURLAsset, withKeys requestedKeys: [String]) {
        /* Make sure that the value of each key has loaded successfully. */
        for thisKey in requestedKeys {
            var error: NSError? = nil
            let keyStatus = asset.statusOfValueForKey(thisKey, error: &error)
            if keyStatus == .Failed {
                self.assetFailedToPrepareForPlayback(error!)
                return
            }
            /* If you are also implementing the use of -[AVAsset cancelLoading], add your code here to bail
            out properly in the case of cancellation. */
        }
        
        /* Use the AVAsset playable property to detect whether the asset can be played. */
        if !asset.playable {
            /* Generate an error describing the failure. */
            let localizedDescription = NSLocalizedString("Item cannot be played", comment: "Item cannot be played description")
            let localizedFailureReason = NSLocalizedString("The assets tracks were loaded, but could not be made playable.", comment: "Item cannot be played failure reason")
            let errorDict: [NSObject: AnyObject] = [
                NSLocalizedDescriptionKey: localizedDescription,
                NSLocalizedFailureReasonErrorKey: localizedFailureReason
            ]
            let assetCannotBePlayedError = NSError(domain: "StitchedStreamPlayer", code: 0, userInfo: errorDict)
            
            /* Display the error to the user. */
            self.assetFailedToPrepareForPlayback(assetCannotBePlayedError)
            
            return
        }
        
        /* At this point we're ready to set up for playback of the asset. */
        
        self.initScrubberTimer()
        self.enableScrubber()
        self.enablePlayerButtons()
        
        /* Stop observing our prior AVPlayerItem, if we have one. */
        if let playerItem = self.playerItem {
            /* Remove existing player item key value observers and notifications. */
            
            playerItem.removeObserver(self, forKeyPath: kStatusKey)
            
            NSNotificationCenter.defaultCenter().removeObserver(self,
                name: AVPlayerItemDidPlayToEndTimeNotification,
                object: playerItem)
        }
        
        /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
        self.playerItem = AVPlayerItem(asset: asset)
        
        /* Observe the player item "status" key to determine when it is ready to play. */
        self.playerItem?.addObserver(self,
            forKeyPath: kStatusKey,
            options: [.Initial, .New],
            context: &MyStreamingMovieViewControllerPlayerItemStatusObserverContext_)
        
        /* When the player item has played to its end time we'll toggle
        the movie controller Pause button to be the Play button */
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "playerItemDidReachEnd:",
            name: AVPlayerItemDidPlayToEndTimeNotification,
            object: self.playerItem)
        
        seekToZeroBeforePlay = false
        
        /* Create new player, if we don't already have one. */
        if self.player == nil {
            /* Get a new AVPlayer initialized to play the specified player item. */
            self.player = AVPlayer(playerItem: self.playerItem!)
            
            /* Observe the AVPlayer "currentItem" property to find out when any
            AVPlayer replaceCurrentItemWithPlayerItem: replacement will/did
            occur.*/
            self.player!.addObserver(self, forKeyPath: kCurrentItemKey, options: [.Initial,.New], context: &MyStreamingMovieViewControllerCurrentItemObservationContext_)
            
            /* A 'currentItem.timedMetadata' property observer to parse the media stream timed metadata. */
            self.player!.addObserver(self, forKeyPath: kTimedMetadataKey, options: [], context: &MyStreamingMovieViewControllerTimedMetadataObserverContext_)
            
            /* Observe the AVPlayer "rate" property to update the scrubber control. */
            self.player!.addObserver(self, forKeyPath: kRateKey, options: [.Initial,.New], context: &MyStreamingMovieViewControllerRateObservationContext_)
        }
        
        /* Make our new AVPlayerItem the AVPlayer's current item. */
        if self.player?.currentItem !== self.playerItem {
            /* Replace the player item with a new player item. The item replacement occurs
            asynchronously; observe the currentItem property to find out when the
            replacement will/did occur*/
            self.player?.replaceCurrentItemWithPlayerItem(self.playerItem!)
            
            self.syncPlayPauseButtons()
        }
        
        movieTimeControl.value = 0.0
    }
    
    //MARK: -
    //MARK: Asset Key Value Observing
    //MARK:
    
    //MARK: Key Value Observer for player rate, currentItem, player item status
    
    /* ---------------------------------------------------------
    **  Called when the value at the specified key path relative
    **  to the given object has changed.
    **  Adjust the movie play and pause button controls when the
    **  player item "status" value changes. Update the movie
    **  scrubber control when the player item is ready to play.
    **  Adjust the movie scrubber control when the player item
    **  "rate" value changes. For updates of the player
    **  "currentItem" property, set the AVPlayer for which the
    **  player layer displays visual output.
    **  NOTE: this method is invoked on the main queue.
    ** ------------------------------------------------------- */
    
    override func observeValueForKeyPath(path: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        /* AVPlayerItem "status" property value observer. */
        if context == &MyStreamingMovieViewControllerPlayerItemStatusObserverContext_ {
            self.syncPlayPauseButtons()
            
            let status = change![NSKeyValueChangeNewKey] as! Int
            switch status {
                /* Indicates that the status of the player is not yet known because
                it has not tried to load new media resources for playback */
            case AVPlayerStatus.Unknown.rawValue:
                self.removePlayerTimeObserver()
                self.syncScrubber()
                
                self.disableScrubber()
                self.disablePlayerButtons()
                
            case AVPlayerStatus.ReadyToPlay.rawValue:
                /* Once the AVPlayerItem becomes ready to play, i.e.
                [playerItem status] == AVPlayerItemStatusReadyToPlay,
                its duration can be fetched from the item. */
                
                playerLayerView.playerLayer.hidden = false
                
                toolBar.hidden = false
                
                /* Show the movie slider control since the movie is now ready to play. */
                movieTimeControl.hidden = false
                
                self.enableScrubber()
                self.enablePlayerButtons()
                
                playerLayerView.playerLayer.backgroundColor = UIColor.blackColor().CGColor
                
                /* Set the AVPlayerLayer on the view to allow the AVPlayer object to display
                its content. */
                playerLayerView.playerLayer.player = player
                
                self.initScrubberTimer()
                
            case AVPlayerStatus.Failed.rawValue:
                let thePlayerItem = object as! AVPlayerItem
                self.assetFailedToPrepareForPlayback(thePlayerItem.error!)
            default:
                break
            }
            /* AVPlayer "rate" property value observer. */
        } else if context == &MyStreamingMovieViewControllerRateObservationContext_ {
            self.syncPlayPauseButtons()
            /* AVPlayer "currentItem" property observer.
            Called when the AVPlayer replaceCurrentItemWithPlayerItem:
            replacement will/did occur. */
        } else if context == &MyStreamingMovieViewControllerCurrentItemObservationContext_ {
            let newPlayerItem = change![NSKeyValueChangeNewKey] as! AVPlayerItem
            
            /* New player item null? */
            if newPlayerItem === NSNull() {
                self.disablePlayerButtons()
                self.disableScrubber()
                
                self.isPlayingAdText.text = ""
            } else { /* Replacement of player currentItem has occurred */
                /* Set the AVPlayer for which the player layer displays visual output. */
                playerLayerView.playerLayer.player = self.player
                
                /* Specifies that the player should preserve the video’s aspect ratio and
                fit the video within the layer’s bounds. */
                playerLayerView.setVideoFillMode(AVLayerVideoGravityResizeAspect)
                
                self.syncPlayPauseButtons()
            }
            /* Observe the AVPlayer "currentItem.timedMetadata" property to parse the media stream
            timed metadata. */
        } else if context == &MyStreamingMovieViewControllerTimedMetadataObserverContext_ {
            let array = player?.currentItem?.timedMetadata ?? []
            for metadataItem in array {
                self.handleTimedMetadata(metadataItem)
            }
        } else {
            super.observeValueForKeyPath(path, ofObject: object, change: change, context: context)
        }
        
    }
    
}