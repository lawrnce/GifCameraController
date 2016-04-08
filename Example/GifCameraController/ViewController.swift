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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCameraController()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.gifCamera.startSession()
    }
    
    private func setupPreviewView() {
        self.previewView = GifCameraPreviewView(frame: CGRect(x: 0, y: 64.0,
            width: UIScreen.mainScreen().bounds.width, height: UIScreen.mainScreen().bounds.width))
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
                setupPreviewView()
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

