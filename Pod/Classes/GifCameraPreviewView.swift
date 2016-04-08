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
    
    var filter: CIFilter!
    var coreImageContext: CIContext!
    var drawableBounds: CGRect!
    
    override public init(frame: CGRect) {
        super.init(frame: frame, context: GifContextManager.sharedInstance.eaglContext)
        
        self.enableSetNeedsDisplay = false
        self.backgroundColor = UIColor.blackColor()
        self.opaque = true
        self.frame = frame
        
        self.bindDrawable()
        self.drawableBounds = self.bounds
        self.drawableBounds.size.width = CGFloat(self.drawableWidth)
        self.drawableBounds.size.height = CGFloat(self.drawableHeight)
        self.coreImageContext = GifContextManager.sharedInstance.ciContext
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func filterChanged(notification: NSNotification) {
        self.filter = notification.object as! CIFilter
    }
    
    func setImage(sourceImage: CIImage) {
        self.bindDrawable()
        let filteredImage = sourceImage
        let cropRect = CenterCropImageRect(sourceImage.extent, previewRect: self.drawableBounds)
        self.coreImageContext.drawImage(filteredImage, inRect: self.drawableBounds, fromRect: cropRect)
        self.display()
    }
}

func CenterCropImageRect(sourceRect: CGRect, previewRect: CGRect) -> CGRect {
    let sourceAspectRatio: CGFloat = sourceRect.size.width / sourceRect.size.height
    let previewAspectRatio: CGFloat = previewRect.size.width  / previewRect.size.height
    
    var drawRect = sourceRect
    
    if (sourceAspectRatio > previewAspectRatio) {
        let scaledHeight = drawRect.size.height * previewAspectRatio
        drawRect.origin.x += (drawRect.size.width - scaledHeight) / 2.0
        drawRect.size.width = scaledHeight
    } else {
        drawRect.origin.y += (drawRect.size.height - drawRect.size.width / previewAspectRatio) / 2.0
        drawRect.size.height = drawRect.size.width / previewAspectRatio
    }
    
    return drawRect
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