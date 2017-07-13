//
//  ViewController.swift
//  MediaPlayerDemo
//
//  Created by Chen, Rena on 6/20/17.
//  Copyright © 2017 Chen, Rena. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

private var playerViewControllerKVOContext = 0

class PlayerViewController: UIViewController {
    
    // MARK: Properties
    
    // Check the status of the asset...
    static let assetKeysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]
    
    let player = AVPlayer() // player object to handle the playback
    
    // For getting/setting the time on time slider.
    var currentTime: Double {
        get {
            return CMTimeGetSeconds(player.currentTime())
        }
        set {
            let newTime = CMTimeMakeWithSeconds(newValue, 1)
            player.seek(to: newTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
            print("set current time")
        }
    }
    
    // How long the video lasts.
    var duration: Double {
        guard let currentItem = player.currentItem else { return 0.0 }
        return CMTimeGetSeconds(currentItem.duration)
    }
    
    // How fast the video is going (normal, fastforward, or rewind)
    var rate: Float {
        get {
            return player.rate
        }
        set {
            player.rate = newValue
        }
    }
    
    // This asset will take a url, and then be turned into a PlayerItem to be loaded into the AVPlayer.
    // This is an abstraction so that different players can play the same asset.
    // Best practice is to load the asset asynchronously.
    var asset: AVURLAsset? {
        didSet {
            guard let newAsset = asset else { return }
            
            // load URL asset async
            loadAsset(newAsset)
        }
    }
    
    // Token from addPeriodicTimeObserverForInterval(_:queue:usingBlock:)
    private var timeObserverToken: Any?
    
    // Player item to be put into player.
    private var playerItem: AVPlayerItem? = nil {
        didSet {
            player.replaceCurrentItem(with: self.playerItem)
        }
    }
    
    // The media will play on the player layer inside of PlayerView: UIView
    private var playerLayer: AVPlayerLayer? {
        return playerView.playerLayer
    }
    
    /*
     A formatter for individual date components used to provide an appropriate
     value for the `startTimeLabel` and `durationLabel`.
     */
    let timeRemainingFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        
        return formatter
    }()
    
    // MARK: IBOutlets
    
    @IBOutlet weak var playerView: PlayerView!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var tapButton: UIButton!
    
    // MARK: View Controller Life Cycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Add observers for updating UI (duration, rate, status), using this PlayerViewController context.
        addObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.duration), options: [.new, .initial], context: &playerViewControllerKVOContext)
        addObserver(self, forKeyPath: #keyPath(PlayerViewController.player.rate), options: [.new, .initial], context: &playerViewControllerKVOContext)
        addObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.status), options: [.new, .initial], context: &playerViewControllerKVOContext)
        
        // Set the player of the playerView.
        playerView.playerLayer.player = player
        
        // Create the movie URL and initialize asset (which will be loaded)
        //let movieURL = Bundle.main.url(forResource: "ElephantSeals", withExtension: "mov")!
        //let movieURL = URL(string: "http://content.uplynk.com/468ba4d137a44f7dab3ad028915d6276.m3u8")!
        //let movieURL = URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8")!
        //let movieURL = URL(string: "http://techslides.com/demos/sample-videos/small.mp4")!
        let movieURL = URL(string: "https://p.scdn.co/mp3-preview/f01fe202818be844e30f10b4abeeb757fa66b228?cid=484e3d627b7d4af9b8d3be79638b678f")!
        asset = AVURLAsset(url: movieURL, options: nil)
        
        // Update time slider with current time, using the player's time observer.
        let interval = CMTimeMake(1, 1)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [unowned self] time in
            let timeElapsed = Float(CMTimeGetSeconds(time))
            
            self.timeSlider.value = Float(timeElapsed)
            self.currentTimeLabel.text = self.createTimeString(time: timeElapsed)
        }
        
        // Customize slider
        timeSlider.minimumTrackTintColor = UIColor.init(colorLiteralRed: 0.99, green: 0.81, blue: 0, alpha: 1)
        //timeSlider.thumbTintColor = UIColor.red
        let image = UIImage(named: "yellow-dot.png")
        timeSlider.setThumbImage(image, for: UIControlState.normal)
        
        // show play button
        showPlayButton()
        
        // gray the screen
        screenTapButton()
        
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Remove observers.
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        
        player.pause()
        
        removeObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.duration), context: &playerViewControllerKVOContext)
        removeObserver(self, forKeyPath: #keyPath(PlayerViewController.player.rate), context: &playerViewControllerKVOContext)
        removeObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.status), context: &playerViewControllerKVOContext)
    }

    
    // MARK: Load asset
    func loadAsset(_ newAsset: AVURLAsset) {
        newAsset.loadValuesAsynchronously(forKeys: PlayerViewController.assetKeysRequiredToPlay) {
            // Completion handler
            
            // Use the main thread
            DispatchQueue.main.async {
                
                // Make sure this asset is the same
                guard newAsset == self.asset else { return }
                
                // Test if the asset keys have been loaded.
                for key in PlayerViewController.assetKeysRequiredToPlay {
                    var error: NSError?
                    
                    // Handle error if a key failed to load, deliver error message.
                    if newAsset.statusOfValue(forKey: key, error: &error) == .failed {
                        let stringFormat = NSLocalizedString("error.asset_key_%@_failed.description", comment: "Can't use this AVAsset because one of it's keys failed to load")
                        
                        let message = String.localizedStringWithFormat(stringFormat, key)
                        
                        self.handleErrorWithMessage(message, error: error)
                        
                        return
                    }
                    
                    // If can't play the asset (according to keys).
                    if !newAsset.isPlayable || newAsset.hasProtectedContent {
                        let message = NSLocalizedString("error.asset_not_playable.description", comment: "Can't use this AVAsset because it isn't playable or has protected content")
                        
                        self.handleErrorWithMessage(message)
                        
                        return
                    }
                    
                    // Can play asset! Create AVPlayerItem and put into player.
                    self.playerItem = AVPlayerItem(asset: newAsset)
                }
            } // end DispatchQueue.main.async
        } // end loadValuesAsynchronouslyForKeys
    } // end loadAsset
    
    
    // MARK: IBActions
    
    @IBAction func playPauseButtonPressed(_ sender: UIButton) {
        if player.rate != 1.0 {
            // Not playing forward, so play.
            let roundedTime = Int(currentTime)
            let roundedDuration = Int(duration)
            if roundedTime >= roundedDuration {
                // At end, so got back to begining.
                currentTime = 0.0
            }
            
            hidePlayButton()
            unscreenTapButton()
            player.play()
        }
        else {
            // Playing, so pause.
            player.pause()
        }
    }
    
    @IBAction func timeSliderChanged(_ sender: UISlider) {
        currentTime = Double(timeSlider.value)
    }
    
    @IBAction func tapButtonPressed(_ sender: UIButton) {
        showHidePlayButton()
    }
    // MARK: KVO Observation
    
    // Update UI when player or player.currentItem changes.
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        // Make sure the this KVO callback was intended for this view controller.
        guard context == &playerViewControllerKVOContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        // Handle different key paths.
        if keyPath == #keyPath(PlayerViewController.player.currentItem.duration) {
            // Handle time slider updates:
            
            // Handle the null case for NSKeyValueChange...when playerItem is nil.
            let newDuration: CMTime
            if let newDurationAsValue = change?[NSKeyValueChangeKey.newKey] as? NSValue {
                newDuration = newDurationAsValue.timeValue
            } else {
                newDuration = kCMTimeZero
            }
            
            // Valid duration if it's a number and nonzero.
            let hasValidDuration = newDuration.isNumeric && newDuration.value != 0
            let newDurationSeconds = hasValidDuration ? CMTimeGetSeconds(newDuration) : 0.0
            let currentTime = hasValidDuration ? Float(CMTimeGetSeconds(player.currentTime())) : 0.0
            
            // Update components.
            timeSlider.maximumValue = Float(newDurationSeconds)
            timeSlider.value = currentTime
            
            playPauseButton.isEnabled = hasValidDuration
            
            durationLabel.isEnabled = hasValidDuration
            durationLabel.text = createTimeString(time: Float(newDurationSeconds))
            
            currentTimeLabel.isEnabled = hasValidDuration
            currentTimeLabel.text = createTimeString(time: currentTime)
            
        } else if keyPath == #keyPath(PlayerViewController.player.rate) {
            // Handle rate updates:
            
            let newRate = (change?[NSKeyValueChangeKey.newKey] as! NSNumber).doubleValue
            
            let buttonImageName = newRate == 1.0 ? "pause-icon.png" : "play-icon.png"
            
            let buttonImage = UIImage(named: buttonImageName)
            
            playPauseButton.setImage(buttonImage, for: UIControlState())
            
            
        } else if keyPath == #keyPath(PlayerViewController.player.currentItem.status) {
            // Handle status updates:
            
            // Handle null case for playerItem.
            let newStatus: AVPlayerItemStatus
            
            if let newStatusAsNumber = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                newStatus = AVPlayerItemStatus(rawValue: newStatusAsNumber.intValue)!
            }
            else {
                newStatus = .unknown
            }
            
            // Check if status is failed and handle error message.
            if newStatus == .failed {
                handleErrorWithMessage(player.currentItem?.error?.localizedDescription, error:player.currentItem?.error)
            }

        }

    }
    
    // Trigger KVO for anyone observing our properties affected by player and player.currentItem
    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        let affectedKeyPathsMappingByKey: [String: Set<String>] = [
            "duration":     [#keyPath(PlayerViewController.player.currentItem.duration)],
            "rate":         [#keyPath(PlayerViewController.player.rate)]
        ]
        
        return affectedKeyPathsMappingByKey[key] ?? super.keyPathsForValuesAffectingValue(forKey: key)
    }

    
    // MARK: Error handling
    
    // Takes a string message and a pointer to NSError.
    func handleErrorWithMessage(_ message: String?, error: Error? = nil) {
        NSLog("Error occured with message: \(message), error: \(error).")
        
        let alertTitle = NSLocalizedString("alert.error.title", comment: "Alert title for errors")
        let defaultAlertMessage = NSLocalizedString("error.default.description", comment: "Default error message when no NSError provided")
        
        let alert = UIAlertController(title: alertTitle, message: message == nil ? defaultAlertMessage : message, preferredStyle: UIAlertControllerStyle.alert)
        
        let alertActionTitle = NSLocalizedString("alert.error.actions.OK", comment: "OK on error alert")
        
        let alertAction = UIAlertAction(title: alertActionTitle, style: .default, handler: nil)
        
        alert.addAction(alertAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: Convenience
    
    func createTimeString(time: Float) -> String {
        let components = NSDateComponents()
        components.second = Int(max(0.0, time))
        
        return timeRemainingFormatter.string(from: components as DateComponents)!
    }
    
    // MARK: Animations
    func fadeOutButtonSlow() {
        UIView.animate(withDuration: 0.5, animations: {() -> Void in
            self.playPauseButton.alpha = 1
        }, completion: {(finished) -> Void in
            UIView.animate(withDuration: 0.2, animations: {() -> Void in
                self.playPauseButton.alpha = 0
            })
        })
        
    }
    
    func showPlayButton() {
        UIView.animate(withDuration: 0.2, animations: {() -> Void in
            self.playPauseButton.alpha = 1
        })
    }
    
    func hidePlayButton() {
        UIView.animate(withDuration: 0.2, animations: {() -> Void in
            self.playPauseButton.alpha = 0
        })
    }
    
    func screenTapButton() {
        UIView.animate(withDuration: 0.2, animations: {() -> Void in
            self.tapButton.backgroundColor = UIColor.black
            self.tapButton.alpha = 0.5
        })
    }
    
    func unscreenTapButton() {
        UIView.animate(withDuration: 0.2, animations: {() -> Void in
            self.tapButton.backgroundColor = UIColor.clear
            self.tapButton.alpha = 0.1
        })
    }
    
    func showHidePlayButton() {
        if(playPauseButton.alpha < 1) {
            showPlayButton()
            screenTapButton()
        } else {
            hidePlayButton()
            unscreenTapButton()
        }
    }
    


}

