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
        view.backgroundColor = UIColor.white
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        activityIndicator.hidesWhenStopped = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    fileprivate func setupGif(){
        var frames = [UIImage]()
        for bitmap in bitmaps {
            let image = UIImage(cgImage: bitmap)
            frames.append(image)
        }
        let gif = UIImage.animatedImage(with: frames, duration: duration)
        gifView = UIImageView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width / 2.0, height: UIScreen.main.bounds.height / 2.0))
        gifView.center = view.center
        gifView.image = gif
        view.insertSubview(self.gifView, belowSubview: activityIndicator)
    }
    
    @IBAction func saveButtonPressed(_ sender: AnyObject) {
        activityIndicator.startAnimating()
        UIApplication.shared.beginIgnoringInteractionEvents()
        let temporaryFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("temp")
        let fileOutputURL = URL(fileURLWithPath: temporaryFile)
        let destination = CGImageDestinationCreateWithURL(fileOutputURL as CFURL, kUTTypeGIF, bitmaps.count, nil)
        let fileProperties = [kCGImagePropertyGIFDictionary as String:[kCGImagePropertyGIFLoopCount as String: 0]]
        let frameProperties = [kCGImagePropertyGIFDictionary as String:[kCGImagePropertyGIFDelayTime as String: duration / Double(bitmaps.count)]]
        CGImageDestinationSetProperties(destination!, fileProperties as CFDictionary)
        
        for bitmap in bitmaps! {
            CGImageDestinationAddImage(destination!, bitmap, frameProperties as CFDictionary)
        }
        
        CGImageDestinationSetProperties(destination!, fileProperties as CFDictionary)
        
        if CGImageDestinationFinalize(destination!) {
          
            let library = ALAssetsLibrary()
            let gifData = try! Data(contentsOf: fileOutputURL)
            library.writeImageData(toSavedPhotosAlbum: gifData, metadata: nil) { ( url, error) -> Void in
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    UIApplication.shared.endIgnoringInteractionEvents()
                    self.dismiss(animated: true) { () -> Void in
                        
                    }
                }
            }
        }
    }
    
    @IBAction func closeButtonPressed(_ sender: AnyObject) {
        dismiss(animated: true) { () -> Void in
            
        }
    }
}
