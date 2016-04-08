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

    @IBOutlet weak var previewView: GifCameraPreviewView!
    var gifCamera: GifCameraController!
//    var previewView: GifCameraPreviewView!
    
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
        self.previewView = GifCameraPreviewView(frame: CGRect(x: 50, y: 50,
            width: UIScreen.mainScreen().bounds.width-100, height: UIScreen.mainScreen().bounds.height-400))
        self.view.addSubview(self.previewView)
    }
    
    private func setupCameraController() {
        // Setup Camera Controller
        if self.gifCamera != nil {
            return
        }
        
        self.gifCamera = GifCameraController()
        
        do {
            if try self.gifCamera.setupSession() {
//                self.gifCamera.delegate = self
//                setupPreviewView()
                self.gifCamera.setPreviewView(self.previewView)
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

}

//extension ViewController: GifCameraControllerDelegate {
//    func controller(cameraController: GifCameraController, didFinishRecordingWithFrames frames: [CGImage], withTotalDuration duration: Double) {
//        
//    }
//}
