Media Player Demo
===============================================
Player View Controller that can stream or play video files.

Requirements (Tested)
-----------------------------------------------
* Swift 3
* XCode 8.3.3

Usage
-----------------------------------------------
1. Open the XCode project.
2. Launch simulator to see demo.

Explanation
-----------------------------------------------
1. *PlayerView:* the UIView which contains the AV player layer. This layer will contain the AVPlayer. (Basically it's the screen.)

2. *PlayerViewController:* the ViewController which connects the AVPlayer to storyboard elements. It uses KVO to asynchronously update the UI.  

The PlayerViewController contains a movieURL, which it loads asynchronously into an AVURLAsset, which is then made into an AVPlayerItem. The AVPlayer will play the AVPlayerItem.  

To integrate with another project, pass a movieURL into the PlayerViewController.

Image Assets
-----------------------------------------------
* yellow-dot.png: in use, makes the slider dot yellow.
* red-dot.png: for if you want to make the slider red.

