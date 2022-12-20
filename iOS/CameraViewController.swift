//
//  CameraViewController.swift
//  CKBasicCamera
//
//  Created by Kai Chen on 12/17/22.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    private enum SessionSetupResult {
        case unknown
        case authorized
        case notAuthorized
        case configurationFailed
        case success
    }
    
    private enum SessionSetupError: Error {
        case videoInputNotAvailable
        case videoInputNotAdded
        case photoOutputNotAdded
    }
    
    @IBOutlet weak var previewView: CameraPreview!
    
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "avcapture-session.queue")
    
    var videoDeviceInput: AVCaptureDeviceInput!
    let photoOutput = AVCapturePhotoOutput()
    
    private var setupResult: SessionSetupResult = .unknown
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the video preview view
        previewView.session = session
        
        /**
         Check the video authorization status.
         Video access is required but Audio is optional.
         If Audio access is denied, audio won't be recorded while recording movie.
         */
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // User has previously granted access to camera
            setupResult = .authorized
        case .notDetermined:
            // Request video access
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                self.setupResult = granted ? .authorized : .notAuthorized
                self.sessionQueue.resume()
            }
        default:
            setupResult = .notAuthorized
        }
        
        /**
         Setup the capture session.
         */
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                self.session.startRunning()
                
            case .notAuthorized:
                DispatchQueue.main.async {
                    let changePrivacySetting = "CKBasicCamera doesn't have permission to use the camera, please change privacy settings"
                    let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                  options: [:],
                                                  completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            default:
                DispatchQueue.main.async {
                    let alertMsg = "Alert message when something goes wrong during capture session configuration"
                    let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                    let alertController = UIAlertController(title: "CKBasicCamera", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
            }
        }
        
        super.viewWillDisappear(animated)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        guard let previewConnnect = previewView.previewLayer.connection else {
            return
        }
        
        let deviceOrientation = UIDevice.current.orientation
        guard let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation),
              deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
            return
        }
        
        previewConnnect.videoOrientation = videoOrientation
        
    }
    
    
    // MARK: - Capture Session Configuration -
    
    private func configureSession() {
        if setupResult != .authorized {
            return
        }
        
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        
        session.sessionPreset = .photo
        
        do {
            try configureSessionInput()
            try configureSessionOutput()
            setupResult = .success
        } catch {
            setupResult = .configurationFailed
            print("Failed to configure session: \(error)")
        }
        
    }
    
    private func configureSessionInput() throws {
        try configureVideoInput()
        try configureAudioInput()
    }
    
    private func configureSessionOutput() throws {
        guard session.canAddOutput(photoOutput) else {
            throw SessionSetupError.photoOutputNotAdded
        }
        
        session.addOutput(photoOutput)
    }
    
    private func configureVideoInput() throws {
        let cameraDevice = videoDevice(at: .back) ?? videoDevice(at: .front)
        guard let videoDevice = cameraDevice else {
            throw SessionSetupError.videoInputNotAvailable
        }
        let deviceInput = try AVCaptureDeviceInput(device: videoDevice)
        guard session.canAddInput(deviceInput) else {
            throw SessionSetupError.videoInputNotAdded
        }
        
        session.addInput(deviceInput)
        videoDeviceInput = deviceInput
        DispatchQueue.main.async {
            self.previewView.previewLayer.connection?.videoOrientation = .portrait
        }
    }
    
    private func configureAudioInput() throws {
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            print("Audio device is not available.")
            return
        }
        
        let deviceInput = try AVCaptureDeviceInput(device: audioDevice)
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        } else {
            print("Could not add audio device input the session.")
        }
    }
    
    private func videoDevice(at position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let disoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: cameraTypes(at: position),
            mediaType: .video,
            position: position)
        
        if let device = disoverySession.devices.first {
            return device
        } else {
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
        }
        
    }
    
    private func cameraTypes(at position: AVCaptureDevice.Position) -> [AVCaptureDevice.DeviceType] {
        let types: [AVCaptureDevice.DeviceType]
        switch position {
            
        case .back:
            types = [.builtInTripleCamera, .builtInDualCamera, .builtInDualWideCamera, .builtInWideAngleCamera]
            
        default:
            types = [.builtInTrueDepthCamera, .builtInWideAngleCamera]
        }
        
        return types
    }
    
    // MARK: - Capture Photo -
   
    @IBOutlet weak var thumbnailView: UIImageView!
    
    private var photoData: Data?
    
    @IBAction func takePhoto(_ sender: Any) {
        let previewLayerOrientation = self.previewView.previewLayer.connection?.videoOrientation
        sessionQueue.async {
            if let videoOrientation = previewLayerOrientation, let outputConnnection = self.photoOutput.connection(with: .video) {
                outputConnnection.videoOrientation = videoOrientation
            }
            
            let settings = AVCapturePhotoSettings()
            
            if let previewFormatType = settings.availablePreviewPhotoPixelFormatTypes.first {
                settings.previewPhotoFormat = [
                    kCVPixelBufferPixelFormatTypeKey as String : previewFormatType,
                    kCVPixelBufferWidthKey as String: 256,
                    kCVPixelBufferHeightKey as String: 256
                ]
            }
            
            self.photoOutput.capturePhoto(with: settings, delegate: self)
            
        }
    }
    
}

import Photos

// MARK: - AVCapturePhotoCaptureDelegate -

extension CameraViewController {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        photoData = photo.fileDataRepresentation()
        
        DispatchQueue.main.async {
            self.showPreview(photo: photo)
        }
        
    }
    
    func showPreview(photo: AVCapturePhoto) {
        guard let pixelBuffer = photo.previewPixelBuffer else { return }
        
        var orientation: CGImagePropertyOrientation?
        if let orientationNum = photo.metadata[kCGImagePropertyOrientation as String] as? NSNumber {
            orientation = CGImagePropertyOrientation(rawValue: orientationNum.uint32Value)
        }
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        if let previewOrientation = orientation {
            ciImage = ciImage.oriented(previewOrientation)
        }
        let uiImage = UIImage(ciImage: ciImage)
        thumbnailView.image = uiImage
        
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let photoData = photoData else {
            print("No photo data captured")
            return
        }
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                let options = PHAssetResourceCreationOptions()
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: photoData, options: options)
            } completionHandler: { _, error in
                if let error = error {
                    print("Failed to save photo to Photo Library: \(error)")
                }
            }
        }
    }
}




