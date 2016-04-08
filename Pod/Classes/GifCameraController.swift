//
//  GifCameraController.swift
//  Pods
//
//  Created by Lawrence Tran on 4/7/16.
//
//

import UIKit
import AVFoundation
import ImageIO
import MobileCoreServices
import CoreFoundation

enum GifCameraControllerError : ErrorType {
    case FailedToAddInput
    case FailedToAddOutput
}

public protocol GifCameraControllerDelegate {
    
    //  Returns to the delegate the bitmaps the frames along with the duration of the gif.
    //
    //
    func cameraController(cameraController: GifCameraController, didFinishRecordingWithFrames frames: [CGImage], withTotalDuration duration: Double)
    
    //  Notifies the delegate that a frame was appended.
    //
    //
    func cameraController(cameraController: GifCameraController, didAppendFrameNumber index: Int)
}

public class GifCameraController: NSObject {
    
    // MARK: - PUBLIC VARIABLES
    
    //  Delegate
    //
    //
    public var delegate: GifCameraControllerDelegate?
    
    //  Set the maximum duration of the gif.
    //  Defaults to 4 seconds.
    //
    public var maxDuration: Double!
    
    //  Set the capture rate.
    //  Defaults to 18 fps.
    //
    public var framesPerSecond: Int!
    
    //  Returns the current device position. (read-only)
    //
    //
    public private(set) var currentDevicePosition: AVCaptureDevicePosition!
    
    // MARK: - PUBLIC METHODS
    
    //  Sets the capture session. This must be called in a do block.
    //
    //
    public func setupSession() throws -> Bool {
        self.captureSession = AVCaptureSession()
        self.captureSession.sessionPreset = AVCaptureSessionPresetiFrame1280x720
        self.maxDuration = 4.0
        self.framesPerSecond = 18
        self.recording = false
        self.paused = false
        self.videoDataOutputQueue = dispatch_queue_create("com.cakegifs.VideoDataOutputQueue", nil)
        do {
            try setupSessionInputs()
            try setupSessionOutputs()
            self.currentFrame = 0
            self.timePoints = [CMTime]()
        }
        catch GifCameraControllerError.FailedToAddInput {
            print("Failed to add camera input")
            return false
        }
        catch GifCameraControllerError.FailedToAddOutput {
            print("Failed to add camera output")
            return false
        }
        return true
    }
    
    //  Sets the preview view for the camera output. The aspect ratio of the
    //  preview view is stored to crop the frames.
    //
    public func setPreviewView(view: GifCameraPreviewView) {
        self.previewBounds  = view.drawableBounds
        self.previewTarget = view
    }
    
    //  Starts the capture session.
    //
    //
    public func startSession() {
        if !self.captureSession.running {
            dispatch_async(self.videoDataOutputQueue, { () -> Void in
                self.captureSession.startRunning()
            })
        }
    }
    
    //  Stops the capture session.
    //
    //
    public func stopSession() {
        if self.captureSession.running {
            dispatch_async(self.videoDataOutputQueue, { () -> Void in
                self.captureSession.stopRunning()
            })
        }
    }
    
    //  Returns if session is recording.
    //
    //
    public func isRecording() -> Bool {
        return self.recording
    }
    
    //  Starts recording.
    //
    //
    public func startRecording() {
        if !self.isRecording() {
            if self.bitmaps == nil {
                prepareForRecording()
            }
            self.recording = true
            self.paused = false
        }
    }
    
    //  Pauses recording.
    //  Does not reset variables.
    //
    public func pauseRecording() {
        if self.isRecording() == true {
            self.recording = false
            self.paused = true
        }
    }
    
    //  Stops recording and resets all variables.
    //
    //
    public func cancelRecording() {
        toggleTorch(forceKill: true)
        self.bitmaps = nil
        self.totalRecordedDuration = nil
        self.differenceDuration = nil
        self.pausedDuration = CMTime(seconds: 0, preferredTimescale: 600)
        self.recording = false
        self.paused = false
        self.currentFrame = 0
    }
    
    //  Ends the recording
    //
    //
    public func stopRecording() {
        toggleTorch(forceKill: true)
        self.delegate?.cameraController(self, didFinishRecordingWithFrames: self.bitmaps!, withTotalDuration: self.totalRecordedDuration.seconds)
        self.totalRecordedDuration = nil
        self.differenceDuration = nil
        self.bitmaps = nil
        self.pausedDuration = CMTime(seconds: 0, preferredTimescale: 600)
        self.recording = false
        self.paused = false
        self.currentFrame = 0
    }
    
    //  Toggles between the front camera and the back.
    //
    //
    public func toggleCamera() {
        self.captureSession.removeInput(self.activeVideoInput)
        
        do {
            if self.activeVideoInput.device == self.frontCameraDevice {
                self.activeVideoInput = nil
                self.activeVideoInput = try AVCaptureDeviceInput(device: self.backCameraDevice)
                self.currentDevicePosition = .Front
                
            } else if self.activeVideoInput.device == self.backCameraDevice {
                self.activeVideoInput = nil
                self.activeVideoInput = try AVCaptureDeviceInput(device: self.frontCameraDevice)
                self.currentDevicePosition = .Back
            }
            
            if self.captureSession.canAddInput(self.activeVideoInput) {
                self.captureSession.addInput(self.activeVideoInput)
            } else {
                throw GifCameraControllerError.FailedToAddInput
            }
            
            self.videoDataOutput.connectionWithMediaType(AVMediaTypeVideo).videoOrientation = .Portrait
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        
        if (self.shouldTorch == true) {
            let seconds = 0.4
            let delay = seconds * Double(NSEC_PER_SEC)
            let dispatchTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
            dispatch_after(dispatchTime, dispatch_get_main_queue(), {
                self.toggleTorch(forceKill: false)
            })
        }
    }
    
    //  Toggles the torch and returns if the torch is on.
    //  Set forceKill to true to turn off the torch.
    //
    public func toggleTorch(forceKill forceKill: Bool) -> Bool {
        var isOn = Bool()
        let device = self.activeVideoInput.device
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                if device.torchMode == .On || forceKill {
                    device.torchMode = AVCaptureTorchMode.Off
                    self.shouldTorch = false
                    isOn = false
                } else {
                    try device.setTorchModeOnWithLevel(1.0)
                    self.shouldTorch = true
                    isOn = true
                }
                device.unlockForConfiguration()
                
            } catch {
                print(error)
            }
        }
        return isOn
    }
    
    // MARK: - PRIVATE VARIABLES
    private var bitmaps: [CGImage]!
    
    private var previewAspectRatio: Double!
    private var previewBounds: CGRect!
    private var previewTarget: PreviewTarget?
    private var recording: Bool = false
    private var paused: Bool!
    
    private var videoDataOutput: AVCaptureVideoDataOutput!
    private var videoDataOutputQueue: dispatch_queue_t!
    
    private var differenceDuration: CMTime!
    private var pausedDuration: CMTime!
    private var totalRecordedDuration: CMTime!
    private var timePoints: [CMTime]!
    private var currentFrame: Int!
    
    private var captureSession: AVCaptureSession!
    private var frontCameraDevice: AVCaptureDevice!
    private var backCameraDevice: AVCaptureDevice!
    private var activeVideoInput: AVCaptureDeviceInput!
    private var frontVideoInput: AVCaptureDeviceInput!
    private var backVideoInput: AVCaptureDeviceInput!
    private var shouldTorch: Bool!
    
    private func prepareForRecording() {
        self.bitmaps = [CGImage]()
        self.pausedDuration = CMTime(seconds: 0, preferredTimescale: 600)
        self.paused = false
        let totalFrames = self.getTotalFrames()
        let increment = self.maxDuration / Double(totalFrames)
        for frameNumber in 0 ..< totalFrames {
            let seconds: Float64 = Float64(increment) * Float64(frameNumber)
            let time = CMTimeMakeWithSeconds(seconds, 600)
            timePoints.append(time)
        }
    }
    
    private func getDelayTime() -> Float {
        return Float(self.maxDuration) / Float(getTotalFrames())
    }
    
    private func getTotalFrames() -> Int {
        return Int(self.framesPerSecond * Int(self.maxDuration))
    }
    
    private func setupSessionInputs() throws {
        for device in AVCaptureDevice.devices() {
            if device.position == .Front {
                self.frontCameraDevice = (device as? AVCaptureDevice)!
            } else if device.position == .Back {
                self.backCameraDevice = (device as? AVCaptureDevice)!
            }
        }
        do {
            self.frontVideoInput = try AVCaptureDeviceInput(device: self.frontCameraDevice)
            if self.captureSession.canAddInput(self.frontVideoInput) {
                self.captureSession.addInput(self.frontVideoInput)
            } else {
                throw GifCameraControllerError.FailedToAddInput
            }
            self.activeVideoInput = self.frontVideoInput
            self.currentDevicePosition = .Front
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }
    
    private func setupSessionOutputs() throws {
        self.videoDataOutput = AVCaptureVideoDataOutput()
        self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue)
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        if self.captureSession.canAddOutput(self.videoDataOutput) {
            self.captureSession.addOutput(self.videoDataOutput)
            self.videoDataOutput.connectionWithMediaType(AVMediaTypeVideo).videoOrientation = .Portrait
            if self.videoDataOutput.connectionWithMediaType(AVMediaTypeVideo).supportsVideoStabilization {
                self.videoDataOutput.connectionWithMediaType(AVMediaTypeVideo).preferredVideoStabilizationMode = .Cinematic
            }
        } else {
            throw GifCameraControllerError.FailedToAddOutput
        }
    }
    
    func returnedOrientation() -> AVCaptureVideoOrientation {
        var videoOrientation: AVCaptureVideoOrientation!
        let orientation = UIDevice.currentDevice().orientation

        switch orientation {
        case .Portrait:
            videoOrientation = .Portrait
        case .PortraitUpsideDown:
            videoOrientation = .PortraitUpsideDown
        case .LandscapeLeft:
            videoOrientation = .LandscapeRight
        case .LandscapeRight:
            videoOrientation = .LandscapeLeft
        case .FaceDown, .FaceUp, .Unknown:
            videoOrientation = .Portrait
        }
        return videoOrientation
    }

    private func getCroppedPreviewImageFromBuffer(buffer: CMSampleBuffer) -> CIImage {
        let imageBuffer: CVPixelBufferRef = CMSampleBufferGetImageBuffer(buffer)!
        let sourceImage: CIImage = CIImage(CVPixelBuffer: imageBuffer).copy() as! CIImage
        let cropRect = centerCropImageRect(sourceImage.extent, previewRect: self.previewBounds)
        let croppedSourceImage = sourceImage.imageByCroppingToRect(cropRect)
        let transform: CGAffineTransform!
        if self.currentDevicePosition == .Front {
            transform = CGAffineTransformMakeScale(-1.0, 1.0)
        } else {
            transform = CGAffineTransformMakeScale(1.0, 1.0)
        }
        let correctedImage = croppedSourceImage.imageByApplyingTransform(transform)
        return correctedImage
    }
    
    private func centerCropImageRect(sourceRect: CGRect, previewRect: CGRect) -> CGRect {
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
    
    private func convertCIImageToCGImage(inputImage: CIImage) -> CGImage! {
        let context = CIContext(options: nil)
        return context.createCGImage(inputImage, fromRect: inputImage.extent)
    }
}

extension GifCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        if (captureOutput == self.videoDataOutput) {
            
            let previewImage = getCroppedPreviewImageFromBuffer(sampleBuffer)
            self.previewTarget?.setImage(previewImage)
            
            if self.recording == true {
                if self.differenceDuration == nil {
                    self.differenceDuration = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                } else if self.pausedDuration > CMTime(seconds: 0, preferredTimescale: 600) {
                    self.differenceDuration = self.differenceDuration + self.pausedDuration
                    self.pausedDuration = CMTime(seconds: 0, preferredTimescale: 600)
                }
                
                self.totalRecordedDuration = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) - self.differenceDuration
                if self.totalRecordedDuration >= self.timePoints[self.currentFrame] {
                    
                    self.bitmaps.append(convertCIImageToCGImage(previewImage))
                    delegate?.cameraController(self, didAppendFrameNumber: self.bitmaps.count)
                    
                    if (self.timePoints.count - 1) == self.currentFrame {
                        self.stopRecording()
                    } else {
                        self.currentFrame = self.currentFrame + 1
                    }
                }
            } else if self.paused == true {
                if self.totalRecordedDuration != nil && self.differenceDuration != nil {
                    self.pausedDuration = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) - self.totalRecordedDuration - self.differenceDuration
                }
            }
        }

    }
}