//
//  ViewController.swift
//  GifCameraController
//
//  Created by Lawrence Tran on 04/07/2016.
//  Copyright (c) 2016 Lawrence Tran. All rights reserved.
//

import UIKit
import GifCameraController

class ViewController: UIViewController {

    var gifCamera: GifCameraController!
    var previewView: GifCameraPreviewView!
    var recordButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCameraController()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.gifCamera.startSession()
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    private func setupPreviewView() {
        self.previewView = GifCameraPreviewView(frame: CGRect(x: 0, y: 0,
            width: UIScreen.mainScreen().bounds.width, height: UIScreen.mainScreen().bounds.height))
        self.view.addSubview(self.previewView)
    }
    
    private func setupRecordButton() {
        self.recordButton = UIButton(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        self.recordButton.addTarget(self, action: Selector("recordButtonPressed:"), forControlEvents: .TouchUpInside)
        self.recordButton.backgroundColor = UIColor.redColor()
        self.recordButton.layer.cornerRadius = 40.0
        self.recordButton.clipsToBounds = true
        self.recordButton.center = CGPoint(x: UIScreen.mainScreen().bounds.width / 2.0,
            y: UIScreen.mainScreen().bounds.height * 0.9)
        self.view.addSubview(self.recordButton)
    }
    
    private func setupCameraController() {
        self.gifCamera = GifCameraController()
        do {
            if try self.gifCamera.setupSession() {
                self.gifCamera.delegate = self
                self.gifCamera.maxDuration = 2.0
                self.gifCamera.framesPerSecond = 16
                setupPreviewView()
                setupRecordButton()
                self.gifCamera.setPreviewView(self.previewView)
                self.gifCamera.toggleCamera()
            }
        }
        catch let error as NSError {
            self.gifCamera = nil
            print(error.localizedDescription)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Actions
    func recordButtonPressed(sender: UIButton) {
        self.gifCamera.startRecording()
    }
}

extension ViewController: GifCameraControllerDelegate {
    
    //  Flash the screen when a new frame is taken
    //
    //
    func cameraController(cameraController: GifCameraController, didAppendFrameNumber index: Int) {
        
        print(index, NSDate().timeIntervalSince1970)
        
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            UIView.animateWithDuration(0.08, animations: { () -> Void in
                self.previewView.alpha = 0.7
                }) { (done) -> Void in
                    UIView.animateWithDuration(0.08, animations: { () -> Void in
                        self.previewView.alpha = 1.0
                        }, completion: { (done) -> Void in
                            
                    })
            }
        }
    }
    
    //  Open gif in new view
    //
    //
    func cameraController(cameraController: GifCameraController, didFinishRecordingWithFrames frames: [CGImage], withTotalDuration duration: Double) {
        let previewVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("previewVC") as! PreviewViewController
        previewVC.bitmaps = frames
        previewVC.duration = duration
        presentViewController(previewVC, animated: true) { () -> Void in            
        }
    }
}





