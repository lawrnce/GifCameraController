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

enum GifCameraControllerError : Error {
  case failedToAddInput
  case failedToAddOutput
}

public protocol GifCameraControllerDelegate {
  
  //  Returns to the delegate the bitmaps the frames along with the duration of the gif.
  //
  //
  func cameraController(_ cameraController: GifCameraController, didFinishRecordingWithFrames frames: [CGImage], withTotalDuration duration: Double)
  
  //  Notifies the delegate that a frame was appended.
  //
  //
  func cameraController(_ cameraController: GifCameraController, didAppendFrameNumber index: Int)
}

open class GifCameraController: NSObject {
  
  // MARK: - PUBLIC VARIABLES
  
  //  Delegate
  //
  //
  open var delegate: GifCameraControllerDelegate?
  
  //  Set the maximum duration of the gif.
  //  Defaults to 4 seconds.
  //
  open var maxDuration: Double!
  
  //  Set the capture rate.
  //  Defaults to 18 fps.
  //
  open var framesPerSecond: Int!
  
  //  Returns the current device position. (read-only)
  //
  //
  open fileprivate(set) var currentDevicePosition: AVCaptureDevicePosition!
  
  // MARK: - PUBLIC METHODS
  
  //  Sets the capture session. This must be called in a do block.
  //
  //
  open func setupSession() throws -> Bool {
    self.captureSession = AVCaptureSession()
    self.captureSession.sessionPreset = AVCaptureSessionPresetiFrame1280x720
    self.maxDuration = 4.0
    self.framesPerSecond = 18
    self.recording = false
    self.paused = false
    self.shouldTorch = false
    self.videoDataOutputQueue = DispatchQueue(label: "com.cakegifs.VideoDataOutputQueue", attributes: [])
    do {
      try setupSessionInputs()
      try setupSessionOutputs()
    }
    catch GifCameraControllerError.failedToAddInput {
      print("Failed to add camera input")
      return false
    }
    catch GifCameraControllerError.failedToAddOutput {
      print("Failed to add camera output")
      return false
    }
    return true
  }
  
  //  Sets the preview view for the camera output. The aspect ratio of the
  //  preview view is stored to crop the frames.
  //
  open func setPreviewView(_ view: GifCameraPreviewView) {
    self.previewBounds  = view.drawableBounds
    self.previewTarget = view
  }
  
  //  Starts the capture session.
  //
  //
  open func startSession() {
    if !self.captureSession.isRunning {
      self.videoDataOutputQueue.async(execute: { () -> Void in
        self.captureSession.startRunning()
      })
    }
  }
  
  //  Stops the capture session.
  //
  //
  open func stopSession() {
    if self.captureSession.isRunning {
      self.videoDataOutputQueue.async(execute: { () -> Void in
        self.captureSession.stopRunning()
      })
    }
  }
  
  //  Returns if session is recording.
  //
  //
  open func isRecording() -> Bool {
    return self.recording
  }
  
  //  Starts recording.
  //
  //
  open func startRecording() {
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
  open func pauseRecording() {
    if self.isRecording() == true {
      self.recording = false
      self.paused = true
    }
  }
  
  //  Stops recording and resets all variables.
  //
  //
  open func cancelRecording() {
    toggleTorch(forceKill: true)
    self.bitmaps = nil
    self.totalRecordedDuration = nil
    self.differenceDuration = nil
    self.pausedDuration = CMTime(seconds: 0, preferredTimescale: 600)
    self.recording = false
    self.paused = false
    self.currentFrame = 0
    self.timePoints = nil
  }
  
  //  Ends the recording
  //
  //
  open func stopRecording() {
    toggleTorch(forceKill: true)
    self.delegate?.cameraController(self, didFinishRecordingWithFrames: self.bitmaps!, withTotalDuration: self.totalRecordedDuration.seconds)
    self.totalRecordedDuration = nil
    self.differenceDuration = nil
    self.timePoints = nil
    self.bitmaps = nil
    self.pausedDuration = CMTime(seconds: 0, preferredTimescale: 600)
    self.recording = false
    self.paused = false
    self.currentFrame = 0
  }
  
  //  Toggles between the front camera and the back.
  //
  //
  open func toggleCamera() {
    self.captureSession.removeInput(self.activeVideoInput)
    
    do {
      if self.activeVideoInput.device == self.frontCameraDevice {
        self.activeVideoInput = nil
        self.activeVideoInput = try AVCaptureDeviceInput(device: self.backCameraDevice)
        self.currentDevicePosition = .back
        
      } else if self.activeVideoInput.device == self.backCameraDevice {
        self.activeVideoInput = nil
        self.activeVideoInput = try AVCaptureDeviceInput(device: self.frontCameraDevice)
        self.currentDevicePosition = .front
      }
      
      if self.captureSession.canAddInput(self.activeVideoInput) {
        self.captureSession.addInput(self.activeVideoInput)
      } else {
        throw GifCameraControllerError.failedToAddInput
      }
      
      self.videoDataOutput.connection(withMediaType: AVMediaTypeVideo).videoOrientation = .portrait
    } catch let error as NSError {
      print(error.localizedDescription)
    }
    
    if (self.shouldTorch == true) {
      let seconds = 0.4
      let delay = seconds * Double(NSEC_PER_SEC)
      let dispatchTime = DispatchTime.now() + Double(Int64(delay)) / Double(NSEC_PER_SEC)
      DispatchQueue.main.asyncAfter(deadline: dispatchTime, execute: {
        self.toggleTorch(forceKill: false)
      })
    }
  }
  
  //  Toggles the torch and returns if the torch is on.
  //  Set forceKill to true to turn off the torch.
  //
  open func toggleTorch(forceKill: Bool) -> Bool {
    var isOn = Bool()
    let device = self.activeVideoInput.device
    if (device?.hasTorch)! {
      do {
        try device?.lockForConfiguration()
        if device?.torchMode == .on || forceKill {
          device?.torchMode = AVCaptureTorchMode.off
          self.shouldTorch = false
          isOn = false
        } else {
          try device?.setTorchModeOnWithLevel(1.0)
          self.shouldTorch = true
          isOn = true
        }
        device?.unlockForConfiguration()
        
      } catch {
        print(error)
      }
    }
    return isOn
  }
  
  // MARK: - PRIVATE VARIABLES
  fileprivate var bitmaps: [CGImage]!
  
  fileprivate var previewAspectRatio: Double!
  fileprivate var previewBounds: CGRect!
  fileprivate var previewTarget: PreviewTarget?
  fileprivate var recording: Bool = false
  fileprivate var paused: Bool!
  
  fileprivate var videoDataOutput: AVCaptureVideoDataOutput!
  fileprivate var videoDataOutputQueue: DispatchQueue!
  
  fileprivate var differenceDuration: CMTime!
  fileprivate var pausedDuration: CMTime!
  fileprivate var totalRecordedDuration: CMTime!
  fileprivate var timePoints: [CMTime]!
  fileprivate var currentFrame: Int!
  
  fileprivate var captureSession: AVCaptureSession!
  fileprivate var frontCameraDevice: AVCaptureDevice!
  fileprivate var backCameraDevice: AVCaptureDevice!
  fileprivate var activeVideoInput: AVCaptureDeviceInput!
  fileprivate var frontVideoInput: AVCaptureDeviceInput!
  fileprivate var backVideoInput: AVCaptureDeviceInput!
  fileprivate var shouldTorch: Bool!
  
  fileprivate func prepareForRecording() {
    self.bitmaps = [CGImage]()
    self.pausedDuration = CMTime(seconds: 0, preferredTimescale: 600)
    self.paused = false
    self.currentFrame = 0
    self.timePoints = [CMTime]()
    let totalFrames = self.getTotalFrames()
    let increment = self.maxDuration / Double(totalFrames)
    for frameNumber in 0 ..< totalFrames {
      let seconds: Float64 = Float64(increment) * Float64(frameNumber)
      let time = CMTimeMakeWithSeconds(seconds, 600)
      timePoints.append(time)
    }
  }
  
  fileprivate func getDelayTime() -> Float {
    return Float(self.maxDuration) / Float(getTotalFrames())
  }
  
  fileprivate func getTotalFrames() -> Int {
    return Int(self.framesPerSecond * Int(self.maxDuration))
  }
  
  fileprivate func setupSessionInputs() throws {
    for device in AVCaptureDevice.devices() {
      if (device as AnyObject).position == .front {
        self.frontCameraDevice = (device as? AVCaptureDevice)!
      } else if (device as AnyObject).position == .back {
        self.backCameraDevice = (device as? AVCaptureDevice)!
      }
    }
    do {
      self.frontVideoInput = try AVCaptureDeviceInput(device: self.frontCameraDevice)
      if self.captureSession.canAddInput(self.frontVideoInput) {
        self.captureSession.addInput(self.frontVideoInput)
      } else {
        throw GifCameraControllerError.failedToAddInput
      }
      self.activeVideoInput = self.frontVideoInput
      self.currentDevicePosition = .front
    } catch let error as NSError {
      print(error.localizedDescription)
    }
  }
  
  fileprivate func setupSessionOutputs() throws {
    self.videoDataOutput = AVCaptureVideoDataOutput()
    self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue)
    self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
    if self.captureSession.canAddOutput(self.videoDataOutput) {
      self.captureSession.addOutput(self.videoDataOutput)
      self.videoDataOutput.connection(withMediaType: AVMediaTypeVideo).videoOrientation = .portrait
      if self.videoDataOutput.connection(withMediaType: AVMediaTypeVideo).isVideoStabilizationSupported {
        self.videoDataOutput.connection(withMediaType: AVMediaTypeVideo).preferredVideoStabilizationMode = .cinematic
      }
    } else {
      throw GifCameraControllerError.failedToAddOutput
    }
  }
  
  func returnedOrientation() -> AVCaptureVideoOrientation {
    var videoOrientation: AVCaptureVideoOrientation!
    let orientation = UIDevice.current.orientation
    
    switch orientation {
    case .portrait:
      videoOrientation = .portrait
    case .portraitUpsideDown:
      videoOrientation = .portraitUpsideDown
    case .landscapeLeft:
      videoOrientation = .landscapeRight
    case .landscapeRight:
      videoOrientation = .landscapeLeft
    case .faceDown, .faceUp, .unknown:
      videoOrientation = .portrait
    }
    return videoOrientation
  }
  
  fileprivate func getCroppedPreviewImageFromBuffer(_ buffer: CMSampleBuffer) -> CIImage {
    let imageBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(buffer)!
    let sourceImage: CIImage = CIImage(cvPixelBuffer: imageBuffer).copy() as! CIImage
    let cropRect = centerCropImageRect(sourceImage.extent, previewRect: self.previewBounds)
    let croppedSourceImage = sourceImage.cropping(to: cropRect)
    let transform: CGAffineTransform!
    if self.currentDevicePosition == .front {
      transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
    } else {
      transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
    }
    let correctedImage = croppedSourceImage.applying(transform)
    return correctedImage
  }
  
  fileprivate func centerCropImageRect(_ sourceRect: CGRect, previewRect: CGRect) -> CGRect {
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
  
  fileprivate func convertCIImageToCGImage(_ inputImage: CIImage) -> CGImage! {
    let context = CIContext(options: nil)
    return context.createCGImage(inputImage, from: inputImage.extent)
  }
}

extension GifCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
  
  public func captureOutput(_ captureOutput: AVCaptureOutput!,
                            didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
                            from connection: AVCaptureConnection!) {
    if captureOutput == self.videoDataOutput {
      let previewImage = getCroppedPreviewImageFromBuffer(sampleBuffer)
      self.previewTarget?.setImage(previewImage)
      let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).convertScale(600,
                                                                                         method: .roundAwayFromZero)
      if self.recording == true {
        if self.differenceDuration == nil {
          self.differenceDuration = sampleTime
        } else if self.pausedDuration > CMTime(seconds: 0, preferredTimescale: 600) {
          self.differenceDuration = CMTimeAdd(self.differenceDuration, self.pausedDuration)
          self.pausedDuration = CMTime(seconds: 0, preferredTimescale: 600)
        }
        self.totalRecordedDuration = CMTimeSubtract(sampleTime, self.differenceDuration)
        
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
          self.pausedDuration = CMTimeSubtract(CMTimeSubtract(sampleTime, self.totalRecordedDuration),
                                               self.differenceDuration)
        }
      }
    }
    
  }
}
