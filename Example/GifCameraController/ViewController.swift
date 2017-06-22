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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.gifCamera.startSession()
    }
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    fileprivate func setupPreviewView() {
        self.previewView = GifCameraPreviewView(frame: CGRect(x: 0, y: 0,
            width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        self.view.addSubview(self.previewView)
    }
    
    fileprivate func setupRecordButton() {
        self.recordButton = UIButton(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        self.recordButton.addTarget(self, action: #selector(ViewController.recordButtonPressed(_:)), for: .touchUpInside)
        self.recordButton.backgroundColor = UIColor.red
        self.recordButton.layer.cornerRadius = 40.0
        self.recordButton.clipsToBounds = true
        self.recordButton.center = CGPoint(x: UIScreen.main.bounds.width / 2.0,
            y: UIScreen.main.bounds.height * 0.9)
        self.view.addSubview(self.recordButton)
    }
    
    fileprivate func setupCameraController() {
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
    func recordButtonPressed(_ sender: UIButton) {
        self.gifCamera.startRecording()
    }
}

extension ViewController: GifCameraControllerDelegate {
    
    //  Flash the screen when a new frame is taken
    //
    //
    func cameraController(_ cameraController: GifCameraController, didAppendFrameNumber index: Int) {
        
        print(index, Date().timeIntervalSince1970)
        
        DispatchQueue.main.async { () -> Void in
            UIView.animate(withDuration: 0.08, animations: { () -> Void in
                self.previewView.alpha = 0.7
                }, completion: { (done) -> Void in
                    UIView.animate(withDuration: 0.08, animations: { () -> Void in
                        self.previewView.alpha = 1.0
                        }, completion: { (done) -> Void in
                            
                    })
            }) 
        }
    }
    
    //  Open gif in new view
    //
    //
    func cameraController(_ cameraController: GifCameraController, didFinishRecordingWithFrames frames: [CGImage], withTotalDuration duration: Double) {
        let previewVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "previewVC") as! PreviewViewController
        previewVC.bitmaps = frames
        previewVC.duration = duration
        present(previewVC, animated: true) { () -> Void in            
        }
    }
}





