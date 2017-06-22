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
    func setImage(_ image: CIImage)
}

open class GifCameraPreviewView: GLKView, PreviewTarget {
    
    var coreImageContext: CIContext!
    var drawableBounds: CGRect!
    
    override public init(frame: CGRect) {
        super.init(frame: frame, context: GifContextManager.sharedInstance.eaglContext)
        enableSetNeedsDisplay = false
        isOpaque = true
        self.frame = frame
        backgroundColor = UIColor.cyan
        
        bindDrawable()
        drawableBounds = bounds
        drawableBounds.size.width = CGFloat(drawableWidth)
        drawableBounds.size.height = CGFloat(drawableHeight)
        coreImageContext = GifContextManager.sharedInstance.ciContext
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setImage(_ sourceImage: CIImage) {
        bindDrawable()
        coreImageContext.draw(sourceImage, in: drawableBounds, from: sourceImage.extent)
        display()
    }
}

class GifContextManager: NSObject {
    static let sharedInstance = GifContextManager()
    var eaglContext: EAGLContext!
    var ciContext: CIContext!
    override init() {
        super.init()
        eaglContext = EAGLContext(api: .openGLES2)
        let options: [String : AnyObject] = [kCIContextWorkingColorSpace: NSNull()]
        ciContext = CIContext(eaglContext: eaglContext, options: options)
    }
}
