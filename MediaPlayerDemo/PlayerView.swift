//
//  PlayerView.swift
//  MediaPlayerDemo
//
//  Created by Chen, Rena on 6/20/17.
//  Copyright © 2017 Chen, Rena. All rights reserved.
//

import UIKit
import AVFoundation

class PlayerView: UIView {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        
        set {
            playerLayer.player = newValue
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

}
