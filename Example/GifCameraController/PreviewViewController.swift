//
//  PreviewViewController.swift
//  GifCameraController
//
//  Created by lola on 4/8/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import ImageIO
import MobileCoreServices
import AssetsLibrary

class PreviewViewController: UIViewController {

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var bitmaps: [CGImage]!
    var duration: Double!
    var closeButton: UIButton!
    var saveButton: UIButton!
    var gifView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupGif()
        self.view.backgroundColor = UIColor.whiteColor()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.activityIndicator.hidesWhenStopped = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    private func setupGif(){
        var frames = [UIImage]()
        for bitmap in bitmaps {
            let image = UIImage(CGImage: bitmap)
            frames.append(image)
        }
        let gif = UIImage.animatedImageWithImages(frames, duration: self.duration)
        self.gifView = UIImageView(frame: CGRect(x: 0, y: 0, width: UIScreen.mainScreen().bounds.width / 2.0, height: UIScreen.mainScreen().bounds.height / 2.0))
        self.gifView.center = self.view.center
        self.gifView.image = gif
        self.view.insertSubview(self.gifView, belowSubview: self.activityIndicator)
    }
    
    @IBAction func saveButtonPressed(sender: AnyObject) {
        self.activityIndicator.startAnimating()
        UIApplication.sharedApplication().beginIgnoringInteractionEvents()
        let temporaryFile = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("temp")
        let fileOutputURL = NSURL(fileURLWithPath: temporaryFile)
        let destination = CGImageDestinationCreateWithURL(fileOutputURL, kUTTypeGIF, self.bitmaps.count, nil)
        let fileProperties = [kCGImagePropertyGIFDictionary as String:
            [
                kCGImagePropertyGIFLoopCount as String: 0
            ],
            kCGImageDestinationLossyCompressionQuality as String: 1.0]
        let frameProperties = [kCGImagePropertyGIFDictionary as String:
            [
                kCGImagePropertyGIFDelayTime as String: self.duration / Double(self.bitmaps.count)
            ]]
        CGImageDestinationSetProperties(destination!, fileProperties as CFDictionaryRef)
        
        for bitmap in self.bitmaps! {
            CGImageDestinationAddImage(destination!, bitmap, frameProperties as CFDictionaryRef)
        }
        
        CGImageDestinationSetProperties(destination!, fileProperties as CFDictionaryRef)
        
        if CGImageDestinationFinalize(destination!) {
            
            let library = ALAssetsLibrary()
            let gifData = NSData(contentsOfURL: fileOutputURL)!
            library.writeImageDataToSavedPhotosAlbum(gifData, metadata: nil) { ( url, error) -> Void in
                dispatch_async(dispatch_get_main_queue()) {
                    self.activityIndicator.stopAnimating()
                    UIApplication.sharedApplication().endIgnoringInteractionEvents()
                    self.dismissViewControllerAnimated(true) { () -> Void in
                        
                    }
                }
            }
        }
    }
    
    @IBAction func closeButtonPressed(sender: AnyObject) {
        dismissViewControllerAnimated(true) { () -> Void in
            
        }
    }
}
