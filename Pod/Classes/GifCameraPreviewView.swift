//
//  GifCameraPreviewView.swift
//  Pods
//
//  Created by Lawrence Tran on 4/7/16.
//
//

import Foundation
import Darwin
import UIKit
import GLKit
import AVFoundation

protocol PreviewTarget {
    func setImage(image: CIImage)
}

public class GifCameraPreviewView: GLKView, PreviewTarget {
    
    var coreImageContext: CIContext!
    var drawableBounds: CGRect!
    
    override public init(frame: CGRect) {
        super.init(frame: frame, context: GifContextManager.sharedInstance.eaglContext)
        self.enableSetNeedsDisplay = false
        self.opaque = true
        self.frame = frame
        self.backgroundColor = UIColor.cyanColor()
        
        self.bindDrawable()
        self.drawableBounds = self.bounds
        self.drawableBounds.size.width = CGFloat(self.drawableWidth)
        self.drawableBounds.size.height = CGFloat(self.drawableHeight)
        self.coreImageContext = GifContextManager.sharedInstance.ciContext
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setImage(sourceImage: CIImage) {
        self.bindDrawable()
        self.coreImageContext.drawImage(sourceImage, inRect: self.drawableBounds, fromRect: sourceImage.extent)
        self.display()
    }
}

class GifContextManager: NSObject {
    static let sharedInstance = GifContextManager()
    var eaglContext: EAGLContext!
    var ciContext: CIContext!
    override init() {
        super.init()
        self.eaglContext = EAGLContext(API: .OpenGLES2)
        let options: [String : AnyObject] = [kCIContextWorkingColorSpace: NSNull()]
        self.ciContext = CIContext(EAGLContext: self.eaglContext, options: options)
    }
}