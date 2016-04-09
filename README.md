# Gif Camera Controller

<p align="center">
<img src="/Assets/preview.gif" />
</p>

Gif Camera Controller is a camera output that takes successive photos to create GIFs.

<!---
[![CI Status](http://img.shields.io/travis/Lawrence Tran/GifCameraController.svg?style=flat)](https://travis-ci.org/Lawrence Tran/GifCameraController)
-->
[![Version](https://img.shields.io/cocoapods/v/GifCameraController.svg?style=flat)](http://cocoapods.org/pods/GifCameraController)
[![License](https://img.shields.io/cocoapods/l/GifCameraController.svg?style=flat)](http://cocoapods.org/pods/GifCameraController)
[![Platform](https://img.shields.io/cocoapods/p/GifCameraController.svg?style=flat)](http://cocoapods.org/pods/GifCameraController)

## Features
* Full camera functionality
* Control frames per second

## Usage 

Instantiate a `GifCameraController` and run `setupSession()` in a do-catch statement. To see the camera's preview use a `GifCameraPreview` view. 
Note that `GifCameraPreview` is currently not supported in interface builder. You must instantiate in code.

```swift
var gifCamera: GifCameraController!
var previewView: GifCameraPreviewView!
self.gifCamera = GifCameraController()
do {
    if try self.gifCamera.setupSession() {
    self.gifCamera.setPreviewView(self.previewView)
    }
} catch let error as NSError {
    self.gifCamera = nil
    print(error.localizedDescription)
}

```

Then set the duration and frames per second.
```swift
self.gifCamera.maxDuration = 2.0
self.gifCamera.framesPerSecond = 3
```

Begin the capture session and start recording.
```swift
self.gifCamera.startSession()
self.gifCaemra.startRecording()
```

When recording finishes, the delegate will output the frames. 

## Documentation

#### Variables

```swift
var delegate: GifCameraControllerDelegate
```
The delegate for the camera controller. This must be set.

```swift
var maxDuration: Double
```
The maximum duration of the gif. Defaults to 4 seconds.

```swift
var framesPerSecond: Int
```
The capture rate of the camera. Defaults to 18 fps.

```swift
var currentDevicePosition: AVCaptureDevicePosition
```
The current device position. (read-only)

#### Methods

```swift
func setupSession() throws -> Bool
```
Setup the camera controller. This must be called before the sessiong begins.

```swift
func setPreviewView(view: GifCameraPreviewView)
```
Adds a preview view to the camera controller. You must instantiate `GifCameraPreviewView` in code.

```swift
func startSession()
```
Starts the capture session.

```swift
func stopSession()
```
Stops the capture session.

```swift
func isRecording() -> Bool
```
Returns if session is recording.

```swift
func startRecording()
```
Starts recording.

```swift
func pauseRecording() 
```
Pauses recording. Does not reset current parameters.

```swift
func cancelRecording()
```
Stops recording and resets all variables.


```swift
func stopRecording()
```
Ends the recording.

```swift
func toggleCamera()
```
Toggles between the front camera and the back. Note `GifCameraController` defaults to the front camera.

```swift
func toggleTorch(forceKill forceKill: Bool) -> Bool
```
Toggles the torch and returns if the torch is on. Set forceKill to true to turn off the torch.

#### Delegate

```swift
func cameraController(cameraController: GifCameraController, didFinishRecordingWithFrames frames: [CGImage], withTotalDuration duration: Double)
```
Returns to the delegate the bitmaps the frames along with the duration of the gif. This is called with `stopRecording()` or when `maxDuration` is reached.

```swift
func cameraController(cameraController: GifCameraController, didAppendFrameNumber index: Int)
```
Notifies the delegate that a frame was appended.

## Demo

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements
* Swift 2.0+
* iOS 8.0+

## Installation

GifCameraController is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
use_frameworks!
pod "GifCameraController"
```

## Author

Lawrence Tran

## License

See the LICENSE file for more info.
