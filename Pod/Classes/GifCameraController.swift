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
    captureSession = AVCaptureSession()
    captureSession.sessionPreset = AVCaptureSessionPresetiFrame1280x720
    maxDuration = 4.0
    framesPerSecond = 18
    recording = false
    paused = false
    shouldTorch = false
    videoDataOutputQueue = DispatchQueue(label: "GifCameraControllerVideoDataOutputQueue", attributes: [])
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
    previewBounds  = view.drawableBounds
    previewTarget = view
  }
  
  //  Starts the capture session.
  //
  //
  open func startSession() {
    if !captureSession.isRunning {
      videoDataOutputQueue.async(execute: { () -> Void in
        self.captureSession.startRunning()
      })
    }
  }
  
  //  Stops the capture session.
  //
  //
  open func stopSession() {
    if captureSession.isRunning {
      videoDataOutputQueue.async(execute: { () -> Void in
        self.captureSession.stopRunning()
      })
    }
  }
  
  //  Returns if session is recording.
  //
  //
  open func isRecording() -> Bool {
    return recording
  }
  
  //  Starts recording.
  //
  //
  open func startRecording() {
    if !isRecording() {
      if bitmaps == nil {
        prepareForRecording()
      }
      recording = true
      paused = false
    }
  }
  
  //  Pauses recording.
  //  Does not reset variables.
  //
  open func pauseRecording() {
    if isRecording() == true {
      recording = false
      paused = true
    }
  }
  
  //  Stops recording and resets all variables.
  //
  //
  open func cancelRecording() {
    toggleTorch(forceKill: true)
    bitmaps = nil
    totalRecordedDuration = nil
    differenceDuration = nil
    pausedDuration = CMTime(seconds: 0, preferredTimescale: 600)
    recording = false
    paused = false
    currentFrame = 0
    timePoints = nil
  }
  
  //  Ends the recording
  //
  //
  open func stopRecording() {
    toggleTorch(forceKill: true)
    delegate?.cameraController(self, didFinishRecordingWithFrames: bitmaps!, withTotalDuration: totalRecordedDuration.seconds)
    totalRecordedDuration = nil
    differenceDuration = nil
    timePoints = nil
    bitmaps = nil
    pausedDuration = CMTime(seconds: 0, preferredTimescale: 600)
    recording = false
    paused = false
    currentFrame = 0
  }
  
  //  Toggles between the front camera and the back.
  //
  //
  open func toggleCamera() {
    captureSession.removeInput(activeVideoInput)
    
    do {
      if activeVideoInput.device == frontCameraDevice {
        activeVideoInput = nil
        activeVideoInput = try AVCaptureDeviceInput(device: backCameraDevice)
        currentDevicePosition = .back
        
      } else if activeVideoInput.device == backCameraDevice {
        activeVideoInput = nil
        activeVideoInput = try AVCaptureDeviceInput(device: frontCameraDevice)
        currentDevicePosition = .front
      }
      
      if captureSession.canAddInput(activeVideoInput) {
        captureSession.addInput(activeVideoInput)
      } else {
        throw GifCameraControllerError.failedToAddInput
      }
      
      videoDataOutput.connection(withMediaType: AVMediaTypeVideo).videoOrientation = .portrait
    } catch let error as NSError {
      print(error.localizedDescription)
    }
    
    if (shouldTorch == true) {
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
    let device = activeVideoInput.device
    if (device?.hasTorch)! {
      do {
        try device?.lockForConfiguration()
        if device?.torchMode == .on || forceKill {
          device?.torchMode = AVCaptureTorchMode.off
          shouldTorch = false
          isOn = false
        } else {
          try device?.setTorchModeOnWithLevel(1.0)
          shouldTorch = true
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
    bitmaps = [CGImage]()
    pausedDuration = CMTime(seconds: 0, preferredTimescale: 600)
    paused = false
    currentFrame = 0
    timePoints = [CMTime]()
    let totalFrames = getTotalFrames()
    let increment = maxDuration / Double(totalFrames)
    for frameNumber in 0 ..< totalFrames {
      let seconds: Float64 = Float64(increment) * Float64(frameNumber)
      let time = CMTimeMakeWithSeconds(seconds, 600)
      timePoints.append(time)
    }
  }
  
  fileprivate func getDelayTime() -> Float {
    return Float(maxDuration) / Float(getTotalFrames())
  }
  
  fileprivate func getTotalFrames() -> Int {
    return Int(framesPerSecond * Int(maxDuration))
  }
  
  fileprivate func setupSessionInputs() throws {
    for device in AVCaptureDevice.devices() {
      if (device as AnyObject).position == .front {
        frontCameraDevice = (device as? AVCaptureDevice)!
      } else if (device as AnyObject).position == .back {
        backCameraDevice = (device as? AVCaptureDevice)!
      }
    }
    do {
      frontVideoInput = try AVCaptureDeviceInput(device: frontCameraDevice)
      if captureSession.canAddInput(frontVideoInput) {
        captureSession.addInput(frontVideoInput)
      } else {
        throw GifCameraControllerError.failedToAddInput
      }
      activeVideoInput = frontVideoInput
      currentDevicePosition = .front
    } catch let error as NSError {
      print(error.localizedDescription)
    }
  }
  
  fileprivate func setupSessionOutputs() throws {
    videoDataOutput = AVCaptureVideoDataOutput()
    videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
    videoDataOutput.alwaysDiscardsLateVideoFrames = true
    if captureSession.canAddOutput(videoDataOutput) {
      captureSession.addOutput(videoDataOutput)
      videoDataOutput.connection(withMediaType: AVMediaTypeVideo).videoOrientation = .portrait
      if videoDataOutput.connection(withMediaType: AVMediaTypeVideo).isVideoStabilizationSupported {
        videoDataOutput.connection(withMediaType: AVMediaTypeVideo).preferredVideoStabilizationMode = .cinematic
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
    let cropRect = centerCropImageRect(sourceImage.extent, previewRect: previewBounds)
    let croppedSourceImage = sourceImage.cropping(to: cropRect)
    let transform: CGAffineTransform!
    if currentDevicePosition == .front {
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
    if captureOutput == videoDataOutput {
      let previewImage = getCroppedPreviewImageFromBuffer(sampleBuffer)
      previewTarget?.setImage(previewImage)
      let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).convertScale(600,
                                                                                         method: .roundAwayFromZero)
      if recording == true {
        if differenceDuration == nil {
          differenceDuration = sampleTime
        } else if pausedDuration > CMTime(seconds: 0, preferredTimescale: 600) {
          differenceDuration = CMTimeAdd(differenceDuration, pausedDuration)
          pausedDuration = CMTime(seconds: 0, preferredTimescale: 600)
        }
        totalRecordedDuration = CMTimeSubtract(sampleTime, differenceDuration)
        
        if totalRecordedDuration >= timePoints[currentFrame] {
          bitmaps.append(convertCIImageToCGImage(previewImage))
          delegate?.cameraController(self, didAppendFrameNumber: bitmaps.count)
          
          if (timePoints.count - 1) == currentFrame {
            stopRecording()
          } else {
            currentFrame = currentFrame + 1
          }
        }
      } else if paused == true {
        if totalRecordedDuration != nil && differenceDuration != nil {
          pausedDuration = CMTimeSubtract(CMTimeSubtract(sampleTime, totalRecordedDuration), differenceDuration)
        }
      }
    }
    
  }
}
